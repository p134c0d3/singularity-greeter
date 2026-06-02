using Gtk;
using Gee;
using Singularity.Widgets;

namespace Singularity.Greeter {

    public class GreeterWindow : Gtk.ApplicationWindow {
        private GreetdClient _client;
        private GLib.Settings? _greeter_settings = null;

        private Box _cards_box;
        private Label _big_time;
        private Label _date_label;
        private uint _clock_timer_id = 0;

        private GreeterUser[] _users = {};
        private UserCard[] _cards = {};
        private UserCard? _active = null;

        public GreeterWindow(Gtk.Application app, GreetdClient client, bool test_mode = false) {
            Object(application: app);
            _client = client;
            try { _greeter_settings = new GLib.Settings("dev.sinty.greeter"); } catch { }

            if (test_mode) {
                set_default_size(1280, 720);
                set_title(_("Singularity Greeter (Test Mode)"));
            } else {
                fullscreen();
            }
            add_css_class("singularity");
            add_css_class("greeter-window");

            var overlay = new Overlay();
            set_child(overlay);

            var bg_picture = new Gtk.Picture();
            bg_picture.add_css_class("greeter-bg");
            bg_picture.hexpand = true;
            bg_picture.vexpand = true;
            bg_picture.content_fit = ContentFit.COVER;
            load_wallpaper(bg_picture);
            overlay.set_child(bg_picture);

            var scrim = new Box(Orientation.HORIZONTAL, 0);
            scrim.add_css_class("greeter-scrim");
            scrim.hexpand = true;
            scrim.vexpand = true;
            overlay.add_overlay(scrim);

            var main_box = new Box(Orientation.VERTICAL, 40);
            main_box.valign = Align.CENTER;
            main_box.halign = Align.CENTER;
            overlay.add_overlay(main_box);

            var clock_box = new Box(Orientation.VERTICAL, 4);
            clock_box.halign = Align.CENTER;
            _big_time = new Label("");
            _big_time.add_css_class("greeter-clock");
            clock_box.append(_big_time);
            _date_label = new Label("");
            _date_label.add_css_class("greeter-date");
            clock_box.append(_date_label);
            main_box.append(clock_box);

            _cards_box = new Box(Orientation.VERTICAL, 12);
            _cards_box.halign = Align.CENTER;
            main_box.append(_cards_box);

            update_clock();
            _clock_timer_id = GLib.Timeout.add_seconds(1, update_clock);

            _client.auth_message.connect(on_auth_message);
            _client.auth_error.connect(on_auth_error);
            _client.auth_success.connect(on_auth_success);

            build_cards();
            select_card(preselected_card());
        }

        // -- Cards ---------------------------------------------------------

        private void build_cards() {
            load_users();
            var sessions = scan_sessions();
            foreach (var u in _users) {
                var card = new UserCard(u, sessions);
                card.chosen.connect(() => select_card(card));
                card.login_requested.connect(() => start_login(card));
                _cards += card;
                _cards_box.append(card);
            }
        }

        private void select_card(UserCard? card) {
            if (card == null) return;
            _active = card;
            foreach (var c in _cards) {
                c.set_selected(c == card);
            }
            apply_user_accent(card.user);
            card.password_row.grab_focus();
        }

        private UserCard? preselected_card() {
            string last = "";
            if (_greeter_settings != null) {
                try { last = _greeter_settings.get_string("last-user"); } catch { }
            }
            foreach (var c in _cards) {
                if (c.user.username == last) return c;
            }
            return _cards.length > 0 ? _cards[0] : null;
        }

        // -- User loading --------------------------------------------------

        private void load_users() {
            GreeterUser[] found = {};
            Posix.setpwent();
            unowned Posix.Passwd? pw;
            while ((pw = Posix.getpwent()) != null) {
                if (pw.pw_uid < 1000 || pw.pw_uid >= 65000) continue;
                string shell = pw.pw_shell ?? "";
                if (shell.has_suffix("nologin") || shell.has_suffix("false") || shell == "") continue;
                var u = new GreeterUser();
                u.username = pw.pw_name;
                string gecos = pw.pw_gecos ?? "";
                u.realname = gecos.contains(",") ? gecos.split(",")[0] : gecos;
                if (u.realname == "") u.realname = u.username;
                u.avatar = find_avatar(u.username);
                u.accent = read_user_accent(u.username);
                found += u;
            }
            Posix.endpwent();

            // Fall back to the current user if enumeration found nobody (e.g. test mode).
            if (found.length == 0) {
                var u = new GreeterUser();
                u.username = GLib.Environment.get_user_name();
                u.realname = u.username;
                u.avatar = find_avatar(u.username);
                u.accent = read_user_accent(u.username);
                found += u;
            }
            _users = found;
        }

        // -- Accent --------------------------------------------------------

        // Per-user accent lives in the AccountsService user keyfile (written by
        // the session shell), readable by the greeter. Falls back to the
        // greeter's system-wide accent when absent.
        private string read_user_accent(string username) {
            string path = "/var/lib/AccountsService/users/" + username;
            if (GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
                var kf = new GLib.KeyFile();
                try {
                    kf.load_from_file(path, GLib.KeyFileFlags.NONE);
                    if (kf.has_group("com.singularity.Desktop")
                        && kf.has_key("com.singularity.Desktop", "Accent")) {
                        return kf.get_string("com.singularity.Desktop", "Accent");
                    }
                } catch { }
            }
            return "";
        }

        private void apply_user_accent(GreeterUser u) {
            string accent = u.accent;
            if (accent == "" && _greeter_settings != null) {
                try { accent = _greeter_settings.get_string("accent-color"); } catch { }
            }
            // Fall back to the desktop accent (the running user's; useful in test
            // mode and when the greeter can reach it) for a faithful preview.
            if (accent == "" || accent == "blue") {
                string d = desktop_accent();
                if (d != "") accent = d;
            }
            if (accent == "") accent = "blue";
            Singularity.Style.StyleManager.get_default().apply_accent_color(accent);
        }

        private string desktop_accent() {
            try {
                var s = new GLib.Settings("dev.sinty.desktop");
                string a = s.get_string("accent-color");
                if (a == "custom") return s.get_string("custom-accent-color");
                if (a == "wallpaper") return "";
                return a;
            } catch { return ""; }
        }

        // -- Avatars / sessions / wallpaper / clock ------------------------

        private string? find_avatar(string username) {
            string[] paths = {
                "/var/lib/AccountsService/icons/" + username,
                "/home/" + username + "/.face"
            };
            foreach (var p in paths) {
                if (GLib.FileUtils.test(p, GLib.FileTest.EXISTS)) return p;
            }
            return null;
        }

        private Gee.ArrayList<Singularity.Core.AppSettingOption> scan_sessions() {
            var options = new Gee.ArrayList<Singularity.Core.AppSettingOption>();
            string[] dirs = { "/usr/share/wayland-sessions", "/usr/share/xsessions" };
            foreach (var d in dirs) {
                if (!GLib.FileUtils.test(d, GLib.FileTest.IS_DIR)) continue;
                try {
                    var dir = GLib.Dir.open(d);
                    string? fname;
                    while ((fname = dir.read_name()) != null) {
                        if (!fname.has_suffix(".desktop")) continue;
                        var kf = new GLib.KeyFile();
                        try {
                            kf.load_from_file(GLib.Path.build_filename(d, fname), GLib.KeyFileFlags.NONE);
                            options.add(new Singularity.Core.AppSettingOption() {
                                id = kf.get_string("Desktop Entry", "Exec"),
                                label = kf.get_string("Desktop Entry", "Name")
                            });
                        } catch { }
                    }
                } catch { }
            }
            return options;
        }

        private void load_wallpaper(Gtk.Picture picture) {
            string uri = "";
            try {
                var s = new GLib.Settings("dev.sinty.desktop");
                uri = s.get_string("background-picture-uri");
            } catch { }
            if (uri == "" && _greeter_settings != null) {
                try { uri = _greeter_settings.get_string("background-uri"); } catch { }
            }
            if (uri != "") {
                string path = uri.has_prefix("file://") ? uri.substring(7) : uri;
                if (GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
                    picture.set_file(GLib.File.new_for_path(path));
                }
            }
        }

        private bool update_clock() {
            var now = new DateTime.now_local();
            _big_time.label = now.format(_("%H:%M"));
            _date_label.label = now.format(_("%A, %B %e"));
            return GLib.Source.CONTINUE;
        }

        // -- Authentication ------------------------------------------------

        private void start_login(UserCard card) {
            select_card(card);
            card.status_label.visible = false;
            card.password_row.sensitive = false;
            _client.create_session.begin(card.user.username, (obj, res) => {
                try {
                    _client.create_session.end(res);
                } catch (GLib.Error e) {
                    show_error(e.message);
                }
            });
        }

        private void on_auth_message(string msg_type, string? msg) {
            if (msg_type == "secret" && _active != null) {
                _client.send_response.begin(_active.password_row.text, (obj, res) => {
                    try {
                        _client.send_response.end(res);
                    } catch (GLib.Error e) {
                        show_error(e.message);
                    }
                });
            }
        }

        private void on_auth_error(string error) {
            show_error(_("Incorrect password"));
            if (_active != null) _active.password_row.text = "";
        }

        private void on_auth_success() {
            if (_active != null && _greeter_settings != null) {
                try { _greeter_settings.set_string("last-user", _active.user.username); } catch { }
            }
            string sess = _active != null ? _active.session : "";
            string[] cmd = sess != "" ? sess.split(" ")
                                      : new string[] { "singularity-desktop" };
            _client.start_session.begin(cmd, (obj, res) => {
                try {
                    _client.start_session.end(res);
                } catch (GLib.Error e) {
                    show_error(e.message);
                }
            });
        }

        private void show_error(string message) {
            if (_active == null) return;
            _active.status_label.label = message;
            _active.status_label.visible = true;
            _active.password_row.sensitive = true;
        }

        protected override void dispose() {
            if (_clock_timer_id != 0) {
                GLib.Source.remove(_clock_timer_id);
                _clock_timer_id = 0;
            }
            base.dispose();
        }
    }
}
