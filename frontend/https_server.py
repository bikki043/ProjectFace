import http.server
import os
import ssl
from functools import partial


class ReusableHTTPServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True


project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
handler = partial(http.server.SimpleHTTPRequestHandler, directory=os.path.dirname(os.path.abspath(__file__)))
server = ReusableHTTPServer(("0.0.0.0", 5500), handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(
    os.path.join(project_root, ".cert", "facegate.pem"),
    os.path.join(project_root, ".cert", "facegate-key.pem"),
)
server.socket = context.wrap_socket(server.socket, server_side=True)
print("Serving HTTPS on https://0.0.0.0:5500/")
server.serve_forever()