using Gtk;
using Gee;
using Singularity.Widgets;

namespace Singularity.Greeter {

    // A selectable user (real name, system username, avatar path, accent).
    public class GreeterUser {
        public string username;
        public string realname;
        public string? avatar;
        public string accent; // "" means use the system default
    }

    // A per-user card: avatar and name are always visible, the login fields sit
    // in a revealer that opens only while the card is selected.
    public class UserCard : Box {
        public GreeterUser user;
        public Revealer revealer;
        public PasswordRow password_row;
        public Label status_label;
        public string session = "";

        public signal void chosen();          // header clicked or activated
        public signal void login_requested(); // sign-in button or Enter

        public UserCard(GreeterUser u, Gee.ArrayList<Singularity.Core.AppSettingOption> sessions) {
            Object(orientation: Orientation.VERTICAL, spacing: 12);
            user = u;
            add_css_class("greeter-user-card");
            halign = Align.CENTER;
            width_request = 360;

            var header = new Box(Orientation.HORIZONTAL, 12);
            header.halign = Align.CENTER;
            var img = new Gtk.Image();
            img.pixel_size = 56;
            img.add_css_class("greeter-avatar");
            if (u.avatar != null) img.set_from_file(u.avatar);
            else img.set_from_icon_name("avatar-default-symbolic");
            header.append(img);
            var name = new Label(u.realname != "" ? u.realname : u.username);
            name.add_css_class("greeter-username");
            name.valign = Align.CENTER;
            header.append(name);

            var header_btn = new Button();
            header_btn.add_css_class("flat");
            header_btn.set_child(header);
            header_btn.clicked.connect(() => chosen());
            append(header_btn);

            revealer = new Revealer();
            revealer.transition_type = RevealerTransitionType.SLIDE_DOWN;
            revealer.transition_duration = 220;

            var fields = new Box(Orientation.VERTICAL, 12);
            var group = new PreferencesGroup();
            password_row = new PasswordRow(_("Password"));
            password_row.entry_activated.connect(() => login_requested());
            group.add_row(password_row);
            if (sessions.size > 0) {
                var session_row = new Singularity.Widgets.SelectionRow.with_options(
                    _("Session"), sessions, "");
                session_row.selected.connect((id) => { session = id; });
                group.add_row(session_row);
            }
            fields.append(group);

            status_label = new Label("");
            status_label.add_css_class("greeter-status");
            status_label.visible = false;
            status_label.wrap = true;
            fields.append(status_label);

            var signin = new Button.with_label(_("Sign In"));
            signin.add_css_class("pill");
            signin.add_css_class("suggested-action");
            signin.halign = Align.CENTER;
            signin.clicked.connect(() => login_requested());
            fields.append(signin);

            revealer.set_child(fields);
            append(revealer);
        }

        public void set_selected(bool selected) {
            revealer.reveal_child = selected;
            if (selected) add_css_class("selected");
            else remove_css_class("selected");
        }
    }
}
