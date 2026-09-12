# Políticas de Seguridad y Cumplimiento Ético 🛡️

ScribeMac se ha diseñado bajo los principios de **privilegios mínimos**, **defensa en profundidad**, **integridad de datos** y **cumplimiento estricto de la legalidad y términos de servicio**.

---

## 🔒 1. Principio de No Elusión y Finalidad Educativa

ScribeMac es un proyecto estrictamente académico y educativo creado para estudiar la construcción de clientes documentales nativos en macOS.

1. **Sin elusión de DRM ni Paywalls**: La aplicación no contiene algoritmos, claves ni mecanismos destinados a descifrar contenido protegido digitalmente, omitir muros de pago o alterar restricciones técnicas de acceso.
2. **Sin omisión de CAPTCHA**: No se integran librerías ni servicios automáticos de resolución o evasión de CAPTCHAs.
3. **Sin robo ni falsificación de tokens**: No se capturan credenciales de navegación de terceros, no se generan tokens fraudulentos ni se explotan endpoints privados no autorizados.
4. **Clasificación Explícita de Restricciones**: Si un recurso enlazado requiere autenticación o no ofrece una vía de descarga pública autorizada, el sistema lo clasifica inequívocamente como:
   - `ResourceStatus.restricted`
   - `ResourceStatus.authenticationRequired`
5. **Fixtures Locales**: Para estudiar el pipeline de descarga, validación y almacenamiento en recursos protegidos, la aplicación utiliza enlaces locales seguros (`scribemac://fixture/...`) vinculados a archivos de prueba propios.

---

## 🛡️ 2. Principio de Mínimos Privilegios en macOS

- **Sin elevación de privilegios (`sudo`)**: ScribeMac nunca solicita permisos de superusuario ni ejecuta comandos `sudo`.
- **Integridad de macOS intacta**:
  - No altera ni desactiva **System Integrity Protection (SIP)**.
  - No evade **Gatekeeper**.
  - No modifica bases de datos de **Transparency, Consent, and Control (TCC)**.
  - No altera cuarentenas globales del sistema (`com.apple.quarantine`).
  - No instala demonios de sistema (`LaunchDaemons`), extensiones de kernel (KEXTs) ni extensiones del sistema (DEXTs).
  - No instala certificados raíz de confianza en el llavero de macOS.
- **Entitlements Seguros**:
  - Acceso de cliente de red (`com.apple.security.network.client`).
  - Acceso a archivos seleccionados explícitamente por el usuario (`com.apple.security.files.user-selected.read-write`).
  - Acceso seguro a la carpeta de descargas del usuario (`com.apple.security.files.downloads.read-write`).

---

## 🔍 3. Modelo de Amenazas y Mitigaciones Implementadas

| Amenaza | Vector de Ataque | Mitigación en ScribeMac |
| :--- | :--- | :--- |
| **Path Traversal** | Parámetros maliciosos en la URL o nombres de archivo (`../../etc/passwd`). | `URLNormalizer` detecta y rechaza secuencias `..` y `%2e%2e`. `FileOrganizer.sanitizeFilename` elimina caracteres de separación de ruta (`/`, `\`, `:`), bytes nulos y caracteres de control. |
| **Camuflaje de Archivos (Spoofing)** | Servidores que devuelven HTML malicioso o páginas de error con extensión `.pdf`. | `PDFValidator` verifica los primeros 5 bytes mágicos (`%PDF-`). Si detecta etiquetas como `<!DOCTYPE` o `<html`, rechaza el archivo de inmediato y lo envía a la carpeta `Failed/`. |
| **Archivos Corruptos / Exploits de Parser** | PDFs malformados diseñados para provocar desbordamientos de buffer en librerías PDF. | Validación estructural previa con **PDFKit** en entorno de ejecución seguro; comprobación estricta de `pageCount > 0` y legibilidad de páginas. |
| **Agotamiento de Recursos (DoS / OOM)** | Archivos gigantescos que saturan la memoria RAM. | Las descargas se realizan directamente a disco mediante `URLSessionDownloadTask`. El cálculo de hash SHA-256 se realiza por streaming en bloques de 64 KB, consumiendo memoria constante independientemente del tamaño del archivo. |
| **Sobrescritura Silenciosa de Datos** | Reemplazo no intencionado de documentos locales con el mismo nombre. | `DuplicateDetector` compara hash SHA-256 y tamaño exacto. Si el contenido es idéntico, reutiliza la referencia; si el hash es distinto, genera variantes numeradas secuenciales (`(2).pdf`). |
| **Fuga de Credenciales / Privacidad** | Registro involuntario de tokens o cookies en los logs del sistema. | `AppLogger` utiliza `os.Logger` estructurado por categorías (`network`, `provider`, `download`, `filesystem`, `pdf`, `database`). Está expresamente prohibido registrar cabeceras `Authorization`, cookies de sesión o tokens. |
| **Acceso Indiscreto al Portapapeles** | Lectura continua de datos privados o contraseñas en el portapapeles. | No se monitoriza el portapapeles de forma permanente en segundo plano. La lectura solo ocurre mediante acción explícita del usuario (*botón Pegar*) o tras activación consciente de la opción en Ajustes. |
