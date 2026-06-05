using GLib;
using Json;

namespace Singularity.Greeter {

    public class GreetdClient : GLib.Object {
        private SocketConnection? connection;
        private InputStream? input_stream;
        private OutputStream? output_stream;

        public signal void auth_message(string msg_type, string? auth_message);
        public signal void auth_error(string error_message);
        public signal void auth_success();

        public async void start_connection() throws Error {
            string? socket_path = Environment.get_variable("GREETD_SOCK");
            if (socket_path == null) {
                throw new IOError.NOT_FOUND("GREETD_SOCK environment variable not set");
            }

            var address = new UnixSocketAddress(socket_path);
            var client = new SocketClient();
            connection = yield client.connect_async(address);

            input_stream = connection.input_stream;
            output_stream = connection.output_stream;

            read_loop.begin();
        }

        private async uint8[]? read_exact(size_t n) throws Error {
            var buf = new uint8[n];
            size_t got = 0;
            while (got < n) {
                ssize_t r = yield input_stream.read_async(buf[got:n]);
                if (r <= 0) {
                    return null;
                }
                got += r;
            }
            return buf;
        }

        private async void read_loop() {
            try {
                while (true) {
                    uint8[]? header = yield read_exact(4);
                    if (header == null) break;

                    uint32 len = 0;
                    Memory.copy(&len, header, 4);
                    if (len == 0) continue;

                    uint8[]? payload = yield read_exact(len);
                    if (payload == null) break;

                    var parser = new Parser();
                    try {
                        parser.load_from_data((string) payload, (ssize_t) len);
                        var node = parser.get_root();
                        if (node == null || node.get_node_type() != Json.NodeType.OBJECT) {
                            continue;
                        }
                        var root = node.get_object();

                        string type = root.get_string_member("type");

                        if (type == "auth_message") {
                            string msg_type = root.get_string_member("auth_message_type");
                            string? msg = root.has_member("auth_message") ? root.get_string_member("auth_message") : null;
                            auth_message(msg_type, msg);
                        } else if (type == "error") {
                            string err = root.get_string_member("error_type");
                            string desc = root.get_string_member("description");
                            auth_error("%s: %s".printf(err, desc));
                        } else if (type == "success") {
                            auth_success();
                        }
                    } catch (Error e) {
                        warning("Failed to parse greetd message: %s", e.message);
                    }
                }
            } catch (Error e) {
                warning("Error reading from greetd: %s", e.message);
            }
        }

        private async void send_request(string json) throws Error {
            uint32 len = (uint32) json.length;
            var header = new uint8[4];
            Memory.copy(header, &len, 4);
            yield output_stream.write_all_async(header, Priority.DEFAULT, null, null);
            yield output_stream.write_all_async(json.data, Priority.DEFAULT, null, null);
        }

        public async void send_response(string? response) throws Error {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value("post_auth_message_response");
            builder.set_member_name("response");
            if (response != null) {
                builder.add_string_value(response);
            } else {
                builder.add_null_value();
            }
            builder.end_object();

            var generator = new Generator();
            generator.set_root(builder.get_root());
            yield send_request(generator.to_data(null));
        }

        public async void create_session(string username) throws Error {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value("create_session");
            builder.set_member_name("username");
            builder.add_string_value(username);
            builder.end_object();

            var generator = new Generator();
            generator.set_root(builder.get_root());
            yield send_request(generator.to_data(null));
        }

        public async void start_session(string[] cmd) throws Error {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value("start_session");
            builder.set_member_name("cmd");
            builder.begin_array();
            foreach (string arg in cmd) {
                builder.add_string_value(arg);
            }
            builder.end_array();
            builder.end_object();

            var generator = new Generator();
            generator.set_root(builder.get_root());
            yield send_request(generator.to_data(null));
        }
    }
}
