using Gtk;
using Singularity.Widgets;

namespace Singularity.Greeter {

    public class PowerMenuDialog : Singularity.Shell.ShellDialog {

        public PowerMenuDialog(Gtk.Window parent) {
            Object(transient_for: parent, modal: true);
            var box = new Box(Orientation.HORIZONTAL, 24);
            box.halign = Align.CENTER;
            box.margin_top = 24;
            box.margin_bottom = 24;
            box.margin_start = 24;
            box.margin_end = 24;
            box.append(create_action_button("system-suspend-symbolic", "Sleep", () => {
                close();
            }));
            box.append(create_action_button("system-reboot-symbolic", "Restart", () => {
                try {
                    string[] argv = {"systemctl", "reboot"};
                    Pid pid;
                    Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
                } catch (Error e) { warning(e.message); }
                close();
            }));
            box.append(create_action_button("system-shutdown-symbolic", "Power Off", () => {
                try {
                    string[] argv = {"systemctl", "poweroff"};
                    Pid pid;
                    Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
                } catch (Error e) { warning(e.message); }
                close();
            }));
            content_box.append(box);
        }

        private Button create_action_button(string icon_name, string label_text, clicked_cb callback) {
            var btn = new Button();
            btn.add_css_class("circular-action-button");
            var box = new Box(Orientation.VERTICAL, 8);
            var icon = new Image.from_icon_name(icon_name);
            icon.pixel_size = 32;
            box.append(icon);
            var label = new Label(label_text);
            label.add_css_class("caption");
            box.append(label);
            btn.set_child(box);
            btn.clicked.connect(callback);
            return btn;
        }
        public delegate void clicked_cb();
    }
}
