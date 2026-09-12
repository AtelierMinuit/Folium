# Estrategia de Pruebas y Verificación 🧪

ScribeMac cuenta con una suite completa de **31 pruebas unitarias y de integración** que cubren todas las fases del ciclo de vida documental sin depender de servicios externos de red.

---

## 🚀 Ejecución de la Suite Completa

Para ejecutar todas las pruebas automatizadas desde la terminal:
```bash
swift test
```

### Resultados de la Verificación
```
Executed 31 tests, with 0 failures (0 unexpected) in 3.768 seconds
```

---

## 📋 Detalle de las Suites de Prueba

### 1. `URLParserTests` (9 pruebas)
Valida la seguridad, normalización y análisis sintáctico de las URLs entrantes.
- `testNormalizerStripsTrackingParameters`: Verifica la eliminación de parámetros espía (`utm_*`, `ref`, `fbclid`, etc.) preservando parámetros válidos de consulta.
- `testNormalizerRejectsUnsupportedSchemes`: Asegura el bloqueo de esquemas peligrosos como `javascript:`, `data:` o `ftp:`.
- `testNormalizerRejectsPathTraversal`: Comprueba el rechazo inmediato de secuencias `..` o `%2e%2e` en la ruta.
- `testScribdValidDocumentWithSlug`: Valida la extracción de ID (`123456789`), slug (`trabajo-social`) y generación de URL canónica.
- `testScribdDocAlias`: Valida la compatibilidad con el alias `/doc/{id}/{slug}`.
- `testScribdPresentationType`: Valida la extracción de presentaciones y subdominios (`es.scribd.com`).
- `testScribdWithoutSlug`: Valida URLs sin slug (`/document/424242`).
- `testScribdInvalidDomain`: Rechaza dominios que no pertenecen a Scribd.
- `testClassifier`: Comprueba la correcta clasificación de URLs en categorías (`.scribd`, `.directPDF`, `.openRepository`, `.fixture`).

---

### 2. `ProviderTests` (5 pruebas)
Valida los contratos y el comportamiento ético de los diferentes proveedores.
- `testScribdMetadataProviderCanHandleAndClassifiesRestricted`: Confirma que el proveedor de Scribd extrae metadatos públicos y clasifica el recurso como `.restricted`, denegando descargas no autorizadas.
- `testMockRestrictedProviderResolvesFixture`: Valida que el proveedor de pruebas resuelva fixtures locales para el estudio del pipeline sin conexión externa.
- `testOpenRepositoryProviderResolvesArXiv`: Comprueba la traducción de preprints de arXiv (`/abs/` a `/pdf/`).
- `testDirectPDFProviderCanHandle`: Verifica el filtrado de URLs directas a archivos PDF.
- `testProviderRegistryResolution`: Confirma que el registro evalúa y despacha las URLs al proveedor prioritario adecuado.

---

### 3. `PDFValidatorTests` (4 pruebas)
Valida la integridad estructural de los documentos descargados.
- `testValidPDFPassesValidation`: Confirma la aceptación de un PDF auténtico con cabecera `%PDF-` y lectura de páginas con PDFKit.
- `testHTMLDisguisedAsPDFIsRejected`: Verifica que páginas HTML con extensión `.pdf` sean detectadas y rechazadas.
- `testCorruptedPDFIsRejected`: Detecta documentos incompletos o con sintaxis PDF rota.
- `testEmptyFileIsRejected`: Rechaza descargas con 0 bytes.

---

### 4. `DuplicateDetectorTests` (4 pruebas)
Valida las reglas de deduplicación y preservación de archivos locales.
- `testUniqueFileGoesToDesiredDestination`: Permite la copia directa cuando no existe colisión.
- `testExactDuplicateDetectionSameNameAndSameHash`: Detecta documentos idénticos basándose en tamaño y SHA-256 sin crear archivos redundantes.
- `testSameNameDifferentHashProducesNumberedVariant`: Ante un nombre coincidente pero diferente contenido, genera variantes secuenciales (`Reporte (2).pdf`).
- `testMultipleVersionsIncrementSequentially`: Valida el incremento sucesivo (`Tesis (3).pdf`).

---

### 5. `DownloadTests` (5 pruebas de red local)
Ejecuta descargas reales contra el servidor local de fixtures en Python.
- `testDownloadPublicPDFSucceedsAndValidates`: Descarga un PDF real, comprueba código HTTP 200, tipo MIME, validación PDFKit y cálculo de hash SHA-256.
- `testDownloadRedirectFollowsToTarget`: Comprueba que `DownloadManager` siga redirecciones HTTP 302 hacia el archivo final.
- `testDownloadDisguisedHTMLIsRejectedAndMovedToFailed`: Confirma que un archivo HTML falso es rechazado y trasladado a la carpeta `Failed/` para diagnóstico.
- `testDownloadNotFoundReturnsError`: Gestiona adecuadamente errores HTTP 404.
- `testDownloadFixtureProtocolSucceedsLocally`: Ejecuta el flujo completo usando el esquema de prueba `scribemac://fixture/`.

---

### 6. `SwiftDataStoreTests` (2 pruebas)
Valida la persistencia de datos en memoria y disco.
- `testSaveAndFetchDocument`: Inserta y recupera documentos de la biblioteca local verificando la persistencia del hash SHA-256 y metadatos.
- `testRecordDownloadHistory`: Verifica el registro de auditoría de descargas en `DownloadRecord`.

---

### 7. `EndToEndPipelineTests` (2 pruebas integrales)
- `testFullEndToEndPipeline`: Ejecuta el pipeline completo de 13 pasos:
  1. Pegado de URL con parámetros de rastreo
  2. Normalización de URL
  3. Detección de proveedor
  4. Inspección de metadatos
  5. Creación de `DocumentJob`
  6. Resolución de descarga
  7. Descarga en streaming con callbacks de progreso
  8. Comprobación de finalización al 100%
  9. Verificación de existencia del archivo en `~/Downloads/ScribeMac/Library/`
  10. Apertura y lectura de páginas con **PDFKit**
  11. Verificación del cálculo criptográfico SHA-256 con **CryptoKit**
  12. Persistencia en la biblioteca con **SwiftData**
  13. Detección de duplicado exacto al re-descargar el mismo recurso
- `testCancellationPipeline`: Inicia una descarga sobre un endpoint lento (`/slow`), cancela la tarea de forma concurrente, verifica el estado `.cancelled` y comprueba la limpieza inmediata de los archivos temporales en `Incoming/`.

---

## 🖥️ Servidor Local de Fixtures (`test_server.py`)

Para realizar pruebas manuales o explorar los diferentes estados con la aplicación en ejecución:
```bash
./Scripts/run_test_server.sh 8089
```

| Endpoint | Código HTTP | Tipo de Contenido | Propósito |
| :--- | :--- | :--- | :--- |
| `/public/document.pdf` | 200 OK | `application/pdf` | Simula una descarga autorizada exitosa. |
| `/redirect/document` | 302 Found | `Location: /public/...` | Prueba el seguimiento de redirecciones. |
| `/html-as-pdf` | 200 OK | `text/html` | Prueba la detección y rechazo de HTML falso. |
| `/not-found` | 404 Not Found | `text/plain` | Prueba el manejo de enlaces rotos. |
| `/server-error` | 500 Server Error | `text/plain` | Prueba el reporte de fallos en servidores remotos. |
| `/slow` | 200 OK (con pausas) | `application/pdf` | Permite probar la cancelación interactiva y timeouts. |
| `/restricted` | 403 Forbidden | `text/plain` | Simula recursos con acceso prohibido. |
| `/auth-required` | 401 Unauthorized | `text/plain` | Simula recursos que exigen credenciales. |
| `/health` | 200 OK | `application/json` | Verificación de disponibilidad del servidor. |
