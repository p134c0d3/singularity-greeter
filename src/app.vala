using Gtk;

namespace Singularity.Greeter {

    public class GreeterApp : Gtk.Application {
        private GreeterWindow? window;
        private GreetdClient client;
        private GLib.Settings settings;
        public bool is_test_mode = false;

        public GreeterApp() {
            Object(
                application_id: "dev.sinty.greeter",
                flags: ApplicationFlags.FLAGS_NONE
            );

            add_main_option("test", 't', GLib.OptionFlags.NONE, GLib.OptionArg.NONE,
                "Run in test mode (windowed)", null);
        }

        protected override int handle_local_options(GLib.VariantDict options) {
            if (options.contains("test")) {
                is_test_mode = true;
            }
            return -1;
        }

        protected override void activate() {
            Singularity.Style.StyleManager.get_default().load_theme();

            // Greeter-specific local styles, layered above the shared theme.
            var provider = new CssProvider();
            try {
                provider.load_from_resource("/dev/sinty/greeter/style.css");
                StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
                );
            } catch (Error e) {
                warning("Greeter: failed to load local CSS: %s", e.message);
            }

            settings = new GLib.Settings("dev.sinty.greeter");
            update_accent_color();
            client = new GreetdClient();
            try {
                if (Environment.get_variable("GREETD_SOCK") != null) {
                    client.start_connection.begin();
                } else {
                    is_test_mode = true;
                    warning("GREETD_SOCK not set. Running in test mode.");
                }
            } catch (Error e) {
                warning("Failed to connect to greetd: %s", e.message);
                is_test_mode = true;
            }
            window = new GreeterWindow(this, client, is_test_mode);
            window.present();
            var _topbar = new GreeterTopBar(this, is_test_mode);
        }

        private void update_accent_color() {
            string color_name = settings.get_string("accent-color");
            Singularity.Style.StyleManager.get_default().apply_accent_color(color_name);
        }
    }
}
