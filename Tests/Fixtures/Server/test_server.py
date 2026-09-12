#!/usr/bin/env python3
"""
ScribeMac Test Fixture Server.
Provides mock HTTP endpoints to test all download and verification scenarios:
- /public/document.pdf: Valid downloadable PDF with correct headers
- /redirect/document: 302 redirect to /public/document.pdf
- /html-as-pdf: Disguised HTML page with .pdf extension to test validator
- /not-found: 404 Not Found
- /server-error: 500 Internal Server Error
- /slow: Slow-responding stream to test timeout and cancellation
- /restricted: 403 Forbidden
- /auth-required: 401 Unauthorized
- /health: Health check endpoint
- /shutdown: Graceful termination
"""

import http.server
import socketserver
import sys
import time
import threading

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8089

VALID_PDF = b"""%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 55 >>
stream
BT
/F1 24 Tf
100 700 Td
(ScribeMac Test Server Valid PDF) Tj
ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000244 00000 n 
0000000350 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
429
%%EOF
"""

class FixtureHandler(http.server.BaseHTTPRequestHandler):
    def do_HEAD(self):
        path = self.path.split('?')[0]
        if path == "/public/document.pdf":
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.send_header("Content-Disposition", 'attachment; filename="documento-publico.pdf"')
            self.end_headers()
        elif path == "/redirect/document":
            self.send_response(302)
            self.send_header("Location", "/public/document.pdf")
            self.end_headers()
        elif path == "/html-as-pdf":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
        elif path == "/not-found":
            self.send_response(404)
            self.end_headers()
        elif path == "/restricted":
            self.send_response(403)
            self.end_headers()
        elif path == "/auth-required":
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Test"')
            self.end_headers()
        elif path == "/server-error":
            self.send_response(500)
            self.end_headers()
        else:
            self.send_response(200)
            self.end_headers()

    def do_GET(self):
        path = self.path.split('?')[0]
        if path == "/public/document.pdf":
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.send_header("Content-Disposition", 'attachment; filename="documento-publico.pdf"')
            self.end_headers()
            self.wfile.write(VALID_PDF)

        elif path == "/redirect/document":
            self.send_response(302)
            self.send_header("Location", "/public/document.pdf")
            self.end_headers()

        elif path == "/html-as-pdf":
            html_content = b"<!DOCTYPE html><html><body><h1>Error: Access Denied</h1><p>This is HTML not a PDF.</p></body></html>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html_content)))
            self.end_headers()
            self.wfile.write(html_content)

        elif path == "/not-found":
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"404 Not Found")

        elif path == "/server-error":
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"500 Internal Server Error")

        elif path == "/slow":
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.end_headers()
            # Send initial chunk then pause
            half = len(VALID_PDF) // 2
            self.wfile.write(VALID_PDF[:half])
            self.wfile.flush()
            time.sleep(3.0)
            self.wfile.write(VALID_PDF[half:])

        elif path == "/restricted":
            self.send_response(403)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"403 Forbidden: Restricted resource")

        elif path == "/auth-required":
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Test"')
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"401 Unauthorized")

        elif path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        elif path == "/shutdown":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Server shutting down...")
            threading.Thread(target=self.server.shutdown).start()

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silence console log spam during automated tests
        pass

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), FixtureHandler) as httpd:
        print(f"ScribeMac Test Server listening on http://127.0.0.1:{PORT}")
        sys.stdout.flush()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
