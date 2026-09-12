#!/bin/bash
PORT=${1:-8089}
echo "🚀 Iniciando Servidor de Fixtures de ScribeMac en el puerto ${PORT}..."
echo "Endpoints disponibles:"
echo "  - http://127.0.0.1:${PORT}/public/document.pdf (PDF válido)"
echo "  - http://127.0.0.1:${PORT}/redirect/document    (Redirección 302)"
echo "  - http://127.0.0.1:${PORT}/html-as-pdf          (HTML falso camuflado)"
echo "  - http://127.0.0.1:${PORT}/not-found            (Error 404)"
echo "  - http://127.0.0.1:${PORT}/server-error         (Error 500)"
echo "  - http://127.0.0.1:${PORT}/slow                 (Respuesta lenta / Cancelación)"
echo "  - http://127.0.0.1:${PORT}/restricted           (Error 403 Restringido)"
echo "  - http://127.0.0.1:${PORT}/auth-required        (Error 401 Autenticación)"
echo "Presiona Ctrl+C para detener."

exec python3 Tests/Fixtures/Server/test_server.py "${PORT}"
