# Estrategia de Pruebas de Folium

Folium cuenta con una cobertura integral de pruebas automatizadas sin depender de conexiones a servidores externos.

---

## 1. Ejecutar la Suite de Pruebas

Para correr toda la suite de pruebas unitarias y de integración:

```bash
swift test
```

---

## 2. Áreas Cubiertas

1. **`URLParserTests`:**
   - Normalización de URLs (limpieza de tracking params, validación de esquemas HTTP/HTTPS).
   - Detección de path traversal (`../../`).
   - Clasificación por dominios y slugs.
2. **`PDFValidatorTests`:**
   - Detección y rechazo de páginas HTML renombradas a `.pdf`.
   - Detección de archivos truncados o corruptos.
   - Validación de firmas mágicas `%PDF-` y recuento de páginas legibles con PDFKit.
3. **`DuplicateDetectorTests`:**
   - Verificación de duplicación estricta por hash SHA-256 criptográfico.
   - Resolución de colisiones de nombres (`Archivo (2).pdf`).
4. **`SwiftDataStoreTests`:**
   - Almacenamiento y consulta de metadatos (`DocumentRecord`).
   - Registro de histórico de descargas (`DownloadRecord`).
5. **`ProviderTests`:**
   - Enrutamiento correcto en `ProviderRegistry`.
   - Clasificación honesta de recursos restringidos vs públicos.
6. **`EducationalLabTests`:**
   - Validación contra servidor mock con escenarios reales:
     - Respuestas 200 OK con ETag y Server.
     - 401 Unauthorized (`WWW-Authenticate`).
     - URLs firmadas con HMAC-SHA256 y expiración.
     - Rate limiting (429 Too Many Requests con `Retry-After`).
     - Desafíos JavaScript simulados (Cloudflare/Turnstile).
     - Cadenas de redirección HTTP 301/302/307.

---

## 3. Servidor de Pruebas Local

Ubicado en `Tests/Fixtures/Server/test_server.py`, permite simular todas las respuestas HTTP de forma aislada e independiente en `localhost`.
