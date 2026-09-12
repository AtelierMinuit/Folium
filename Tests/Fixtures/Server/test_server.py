#!/usr/bin/env python3
"""
ScribeMac Test Fixture Server — Versión Extendida con Laboratorio de Seguridad Educativa.

Endpoints originales:
- /public/document.pdf: PDF descargable válido con cabeceras correctas
- /redirect/document: Redirección 302 a /public/document.pdf
- /html-as-pdf: Página HTML disfrazada con extensión .pdf para probar el validador
- /not-found: 404 Not Found
- /server-error: 500 Internal Server Error
- /slow: Respuesta lenta para probar timeout y cancelación
- /restricted: 403 Forbidden
- /auth-required: 401 Unauthorized
- /health: Verificación de salud
- /shutdown: Terminación elegante

Endpoints de Laboratorio de Seguridad (/lab/*):
1. /lab/public.pdf — 200 OK con PDF estándar y cabeceras completas
2. /lab/auth-required — 401 con WWW-Authenticate: Basic
3. /lab/signed-url — Validación de firma HMAC-SHA256 y timestamp exp
4. /lab/expired-token — 403 Forbidden con X-Token-Status: expired
5. /lab/rate-limited — 429 Too Many Requests con Retry-After
6. /lab/javascript-challenge — Simulación de desafío PoW Turnstile
7. /lab/session-cookie — Verificación de cookie de sesión
8. /lab/tiled-document — Manifiesto JSON + teselas PNG
9. /lab/redirect-chain — Cadena 301→302→307→200
"""

import http.server
import socketserver
import sys
import time
import threading
import hmac
import hashlib
import json
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8089

# Clave secreta para firmas HMAC-SHA256 del laboratorio
LAB_HMAC_KEY = b'lab-secret'

# Contador de solicitudes por IP para rate limiting (ventana de 60 segundos)
rate_limit_tracker = {}  # IP -> [(timestamp, count)]
RATE_LIMIT_MAX = 3
RATE_LIMIT_WINDOW = 60  # segundos

# PDF válido minimal para pruebas
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

# PNG mínimo válido de 1x1 píxel rojo para teselas del laboratorio
# Generado manualmente: cabecera PNG + chunk IHDR + chunk IDAT + chunk IEND
TILE_PNG_RED = (
    b'\x89PNG\r\n\x1a\n'  # Firma PNG
    b'\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02'
    b'\x00\x00\x00\x90wS\xde'  # 1x1, 8-bit RGB
    b'\x00\x00\x00\x0cIDATx'
    b'\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05'
    b'\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82'
)

# Página HTML de desafío JavaScript que simula Cloudflare/Turnstile
JAVASCRIPT_CHALLENGE_HTML = b"""<!DOCTYPE html>
<html lang="es">
<head>
    <title>Verificacion de Seguridad</title>
    <meta charset="UTF-8">
</head>
<body>
    <div id="challenge-container">
        <h1>Verificacion de seguridad necesaria</h1>
        <p>Estamos verificando que eres humano. Este proceso es automatico y deberia completarse en unos segundos.</p>
        <noscript>
            <p><strong>Error: JavaScript es necesario para completar esta verificacion.</strong></p>
        </noscript>
    </div>
    <script>
        // Simulacion de desafio PoW (Proof of Work) tipo Turnstile
        (function() {
            var challenge = document.createElement('div');
            challenge.id = 'turnstile-widget';
            challenge.setAttribute('data-sitekey', '0x4AAAAAAA_SIMULATED_KEY');
            challenge.setAttribute('data-callback', 'onVerified');
            document.getElementById('challenge-container').appendChild(challenge);
            
            function computePoW(difficulty) {
                var nonce = 0;
                while (true) {
                    // Simulacion: nunca se resuelve realmente
                    nonce++;
                    if (nonce > 1000000) break;
                }
            }
            computePoW(20);
        })();
    </script>
</body>
</html>"""

# Página HTML de formulario de login para cookie de sesión
SESSION_LOGIN_HTML = b"""<!DOCTYPE html>
<html lang="es">
<head><title>Inicio de Sesion</title></head>
<body>
    <h1>Se requiere inicio de sesion</h1>
    <form method="POST" action="/lab/session-cookie/login">
        <label for="token">Token de sesion:</label>
        <input type="text" id="token" name="token">
        <button type="submit">Iniciar sesion</button>
    </form>
</body>
</html>"""


def compute_hmac_sig(path: str) -> str:
    """Calcula la firma HMAC-SHA256 de un path usando la clave del laboratorio."""
    return hmac.new(LAB_HMAC_KEY, path.encode('utf-8'), hashlib.sha256).hexdigest()


def check_rate_limit(client_ip: str) -> bool:
    """Verifica si el cliente ha excedido el límite de solicitudes.
    Retorna True si la solicitud está permitida, False si excede el límite."""
    now = time.time()
    
    # Limpiar entradas antiguas
    if client_ip in rate_limit_tracker:
        rate_limit_tracker[client_ip] = [
            ts for ts in rate_limit_tracker[client_ip]
            if now - ts < RATE_LIMIT_WINDOW
        ]
    else:
        rate_limit_tracker[client_ip] = []
    
    if len(rate_limit_tracker[client_ip]) >= RATE_LIMIT_MAX:
        return False
    
    rate_limit_tracker[client_ip].append(now)
    return True


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
        # Cabeceras HEAD para endpoints de laboratorio que retornan PDF
        elif path == "/lab/public.pdf":
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.send_header("ETag", '"lab-pdf-v1"')
            self.send_header("Server", "Folium-Lab/1.0")
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
        else:
            self.send_response(200)
            self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query_params = parse_qs(parsed.query)

        # ──────────────────────────────────────────────
        # Endpoints Originales
        # ──────────────────────────────────────────────

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
            # Enviar mitad, pausar, enviar resto
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

        # ──────────────────────────────────────────────
        # Endpoints del Laboratorio de Seguridad (/lab/*)
        # ──────────────────────────────────────────────

        # 1. PDF público con cabeceras completas de diagnóstico
        elif path == "/lab/public.pdf":
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.send_header("Content-Disposition", 'attachment; filename="lab-publico.pdf"')
            self.send_header("ETag", '"lab-pdf-v1"')
            self.send_header("Server", "Folium-Lab/1.0")
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            self.wfile.write(VALID_PDF)

        # 2. Autenticación requerida (401)
        elif path == "/lab/auth-required":
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Lab"')
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            body = json.dumps({
                "error": "authentication_required",
                "message": "Se requiere autenticación Basic para acceder a este recurso.",
                "realm": "Lab"
            }).encode('utf-8')
            self.wfile.write(body)

        # 3. URL firmada con HMAC-SHA256
        elif path == "/lab/signed-url":
            sig = query_params.get('sig', [None])[0]
            exp = query_params.get('exp', [None])[0]

            if not sig or not exp:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": "missing_parameters",
                    "message": "Se requieren los parámetros 'sig' y 'exp'."
                }).encode('utf-8'))
                return

            # Verificar expiración
            try:
                exp_timestamp = int(exp)
            except ValueError:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": "invalid_exp",
                    "message": "El parámetro 'exp' debe ser un timestamp Unix válido."
                }).encode('utf-8'))
                return

            if time.time() > exp_timestamp:
                self.send_response(410)
                self.send_header("Content-Type", "application/json")
                self.send_header("X-Token-Status", "expired")
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": "url_expired",
                    "message": "La URL firmada ha expirado.",
                    "expired_at": exp_timestamp
                }).encode('utf-8'))
                return

            # Verificar firma HMAC
            expected_sig = compute_hmac_sig(path)
            if not hmac.compare_digest(sig, expected_sig):
                self.send_response(403)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({
                    "error": "invalid_signature",
                    "message": "La firma HMAC-SHA256 no es válida."
                }).encode('utf-8'))
                return

            # Firma válida y no expirada: entregar PDF
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(VALID_PDF)))
            self.send_header("X-Signature-Verified", "true")
            self.end_headers()
            self.wfile.write(VALID_PDF)

        # 4. Token expirado (siempre 403)
        elif path == "/lab/expired-token":
            self.send_response(403)
            self.send_header("Content-Type", "application/json")
            self.send_header("X-Token-Status", "expired")
            self.end_headers()
            body = json.dumps({
                "error": "token_expired",
                "message": "El token de acceso ha expirado. Solicite uno nuevo al emisor.",
                "token_status": "expired",
                "action_required": "refresh_token"
            }).encode('utf-8')
            self.wfile.write(body)

        # 5. Rate limiting (429)
        elif path == "/lab/rate-limited":
            client_ip = self.client_address[0]
            if check_rate_limit(client_ip):
                # Dentro del límite: entregar PDF
                self.send_response(200)
                self.send_header("Content-Type", "application/pdf")
                self.send_header("Content-Length", str(len(VALID_PDF)))
                self.send_header("X-RateLimit-Limit", str(RATE_LIMIT_MAX))
                remaining = RATE_LIMIT_MAX - len(rate_limit_tracker.get(client_ip, []))
                self.send_header("X-RateLimit-Remaining", str(max(0, remaining)))
                self.end_headers()
                self.wfile.write(VALID_PDF)
            else:
                # Excede límite: 429
                self.send_response(429)
                self.send_header("Content-Type", "application/json")
                self.send_header("Retry-After", "5")
                self.send_header("X-RateLimit-Limit", str(RATE_LIMIT_MAX))
                self.send_header("X-RateLimit-Remaining", "0")
                self.end_headers()
                body = json.dumps({
                    "error": "rate_limited",
                    "message": "Has excedido el límite de solicitudes. Intenta de nuevo después.",
                    "retry_after_seconds": 5
                }).encode('utf-8')
                self.wfile.write(body)

        # 6. Desafío JavaScript (simulación Turnstile/Cloudflare)
        elif path == "/lab/javascript-challenge":
            self.send_response(403)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(JAVASCRIPT_CHALLENGE_HTML)))
            self.send_header("X-Challenge-Type", "javascript-pow")
            self.end_headers()
            self.wfile.write(JAVASCRIPT_CHALLENGE_HTML)

        # 7. Cookie de sesión
        elif path == "/lab/session-cookie":
            cookie_header = self.headers.get('Cookie', '')
            if 'lab_session=valid-token-2024' in cookie_header:
                # Cookie válida: entregar PDF
                self.send_response(200)
                self.send_header("Content-Type", "application/pdf")
                self.send_header("Content-Length", str(len(VALID_PDF)))
                self.end_headers()
                self.wfile.write(VALID_PDF)
            else:
                # Sin cookie válida: retornar página de login
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(SESSION_LOGIN_HTML)))
                self.send_header("Set-Cookie", "lab_session=; Path=/lab; HttpOnly")
                self.end_headers()
                self.wfile.write(SESSION_LOGIN_HTML)

        # 8. Documento en teselas (manifiesto JSON)
        elif path == "/lab/tiled-document":
            manifest = {
                "document_id": "lab-tiled-001",
                "title": "Documento en Teselas de Laboratorio",
                "total_pages": 1,
                "tiles": [
                    {"index": 0, "url": "/lab/tile/0", "width": 100, "height": 100},
                    {"index": 1, "url": "/lab/tile/1", "width": 100, "height": 100},
                    {"index": 2, "url": "/lab/tile/2", "width": 100, "height": 100},
                    {"index": 3, "url": "/lab/tile/3", "width": 100, "height": 100},
                ]
            }
            body = json.dumps(manifest, indent=2).encode('utf-8')
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        # 8b. Teselas individuales (PNG 1x1 rojo)
        elif path.startswith("/lab/tile/"):
            try:
                tile_index = int(path.split("/")[-1])
                if 0 <= tile_index <= 3:
                    self.send_response(200)
                    self.send_header("Content-Type", "image/png")
                    self.send_header("Content-Length", str(len(TILE_PNG_RED)))
                    self.end_headers()
                    self.wfile.write(TILE_PNG_RED)
                else:
                    self.send_response(404)
                    self.end_headers()
                    self.wfile.write(b"Tile not found")
            except (ValueError, IndexError):
                self.send_response(400)
                self.end_headers()

        # 9. Cadena de redirecciones
        elif path == "/lab/redirect-chain":
            self.send_response(301)
            self.send_header("Location", "/lab/redirect-chain/step2")
            self.end_headers()

        elif path == "/lab/redirect-chain/step2":
            self.send_response(302)
            self.send_header("Location", "/lab/redirect-chain/step3")
            self.end_headers()

        elif path == "/lab/redirect-chain/step3":
            self.send_response(307)
            self.send_header("Location", "/lab/public.pdf")
            self.end_headers()

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silenciar logs en consola durante pruebas automatizadas
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
