using Gtk;
using GtkLayerShell;

namespace Singularity.Greeter {

    public class GreeterTopBar : Gtk.Window {
        private Label clock_label;
        private uint _clock_timer_id = 0;

        public GreeterTopBar(Gtk.Application app, bool test_mode = false) {
            Object(application: app);
            
            if (!test_mode) {
                init_for_window(this);
                set_layer(this, GtkLayerShell.Layer.OVERLAY);
                auto_exclusive_zone_enable(this);
                set_anchor(this, GtkLayerShell.Edge.TOP, true);
                set_anchor(this, GtkLayerShell.Edge.LEFT, true);
                set_anchor(this, GtkLayerShell.Edge.RIGHT, true);
            } else {
                set_default_size(1280, 48);
                set_title(_("Greeter TopBar (Test Mode)"));
            }

            add_css_class("singularity");
            add_css_class("singularity-shell");
            add_css_class("panel-window");
            add_css_class("greeter-panel");

            var overlay = new Overlay();
            set_child(overlay);

            var main_box = new Box(Orientation.HORIZONTAL, 10);
            main_box.add_css_class("panel");
            overlay.set_child(main_box);

            // Left spacer
            var left = new Box(Orientation.HORIZONTAL, 0);
            left.hexpand = true;
            main_box.append(left);

            // Center: clock
            var clock_btn = new Button();
            clock_btn.has_frame = false;
            clock_btn.add_css_class("clock-button");
            clock_label = new Label("");
            clock_label.add_css_class("clock");
            clock_btn.set_child(clock_label);
            main_box.append(clock_btn);

            // Right: power button
            var right = new Box(Orientation.HORIZONTAL, 5);
            right.hexpand = true;
            right.halign = Align.END;
            right.margin_end = 8;

            var power_btn = new Button();
            power_btn.has_frame = false;
            power_btn.add_css_class("notification-button"); // Reuse same style as panel buttons
            var power_icon = new Image.from_icon_name("system-shutdown-symbolic");
            power_icon.pixel_size = 16;
            power_btn.set_child(power_icon);
            power_btn.clicked.connect(on_power_clicked);
            right.append(power_btn);
            main_box.append(right);

            update_clock();
            _clock_timer_id = GLib.Timeout.add_seconds(1, update_clock);
            present();
        }

        private bool update_clock() {
            var now = new DateTime.now_local();
            clock_label.label = now.format(_("%a, %b %e  %H:%M"));
            return Source.CONTINUE;
        }

        private void on_power_clicked() {
            var dialog = new PowerMenuDialog(this);
            dialog.open_dialog();
        }

        ~GreeterTopBar() {
            if (_clock_timer_id != 0) GLib.Source.remove(_clock_timer_id);
        }
    }
}
