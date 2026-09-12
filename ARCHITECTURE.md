# Arquitectura Técnica de ScribeMac 🏛️

ScribeMac está diseñada siguiendo los principios de arquitectura limpia, separación estricta de responsabilidades, aislamiento por actores para concurrencia segura en Swift 6 y modelos de datos declarativos.

---

## 📐 Diagrama del Pipeline Integral

```mermaid
flowchart TD
    A[URL del Usuario / Portapapeles] --> B[URLNormalizer]
    B --> C{URLClassifier}
    C -->|scribd.com| D[ScribdMetadataProvider]
    C -->|arxiv.org| E[OpenRepositoryProvider]
    C -->|*.pdf| F[DirectPDFProvider]
    C -->|scribemac://fixture| G[MockRestrictedProvider]
    
    D -->|Inspección Pública| H[ResourceStatus: Restricted]
    H -->|Sugerencia Fixture| G
    
    E -->|Resolución Canónica| I[DownloadResult]
    F -->|HEAD / Fallback GET| I
    G -->|Fixture Local| I
    
    I --> J[DownloadManager: Actor]
    J --> K[Streaming URLSessionDownloadTask]
    K --> L[Carpeta Incoming/]
    
    L --> M[DownloadValidator: HTTP & MIME]
    M --> N[PDFValidator: Magic Bytes %PDF- & PDFKit]
    
    N -->|Inválido / HTML Falso| O[Carpeta Failed/]
    N -->|Válido| P[FileHasher: SHA-256 CryptoKit]
    
    P --> Q[PDFMetadataReader: Título & Autor]
    Q --> R[DuplicateDetector: Hash + Tamaño]
    
    R -->|Duplicado Exacto| S[Reutilizar en Library/]
    R -->|Nombre Existente / Distinto Hash| T[Generar Nombre Incremental (2).pdf]
    R -->|Único| U[Mover a Library/]
    
    S & T & U --> V[SwiftDataStore]
    V --> W[(DocumentRecord / DownloadRecord)]
    W --> X[SwiftUI: Biblioteca & Visor PDFKit]
```

---

## 🧩 Capas del Sistema

### 1. Capa de Entrada y Normalización (`Core/URL/`)
- **`URLNormalizer`**:
  - Trata las URLs entrantes eliminando espacios, caracteres de control no imprimibles y normalizando esquemas a minúsculas.
  - Detecta y rechaza intentos de *Directory Traversal* (`..`, `%2e%2e`).
  - Depura de forma transparente parámetros publicitarios y de analítica (`utm_source`, `utm_medium`, `fbclid`, `ref`, etc.) para producir una clave canónica limpia.
- **`ScribdURLParser`**:
  - Analiza expresiones regulares estrictas para URLs públicas: `/document/{id}/{slug}`, `/doc/{id}/{slug}`, `/presentation/{id}/{slug}`.
  - Admite variantes regionales (`www.scribd.com`, `scribd.com`, `es.scribd.com`, etc.).
  - Extrae de forma segura el identificador público y el slug descriptivo.
- **`URLClassifier`**:
  - Discrimina el tipo de origen para encaminar la URL al proveedor óptimo.

---

### 2. Capa de Proveedores Extensibles (`Core/Providers/`)
Todos los proveedores implementan el protocolo desacoplado:
```swift
public protocol DocumentProvider: Sendable {
    var identifier: String { get }
    var displayName: String { get }
    func canHandle(_ url: URL) -> Bool
    func inspect(_ url: URL) async throws -> ProviderResult
    func resolveDownload(_ url: URL) async throws -> DownloadResult
}
```

- **`ScribdMetadataProvider`**: Analizador estrictamente educativo. Realiza una inspección pública de la página mediante una petición GET superficial para extraer metadatos abiertos (`<title>`, OpenGraph). Ante la ausencia de un canal de descarga directo no autenticado, clasifica el recurso como `ResourceStatus.restricted`, protegiendo los términos de servicio.
- **`MockRestrictedProvider`**: Resuelve esquemas educativos `scribemac://fixture/document/...` contra documentos de prueba integrados (`Tests/Fixtures/sample-document.pdf`), permitiendo validar el resto del pipeline en entornos aislados.
- **`OpenRepositoryProvider`**: Especializado en repositorios abiertos como arXiv.org. Traduce páginas `/abs/{id}` a sus correspondientes endpoints públicos `/pdf/{id}.pdf`.
- **`DirectPDFProvider`**: Proveedor general para enlaces directos. Emplea peticiones `HEAD` para verificar `Content-Type` y `Content-Length`, con degradación a peticiones `GET` parciales (`Range: bytes=0-2048`) en servidores que no admiten `HEAD`.
- **`ProviderRegistry`**: Registro central con sincronización `Sendable` que evalúa proveedores en orden de prioridad.

---

### 3. Capa de Descarga y Concurrencia (`Core/Download/`)
- **`DownloadManager` (Actor)**:
  - Actor aislado en Swift 6 para evitar condiciones de carrera (*data races*).
  - Emplea `URLSessionDownloadTask` mediante una continuación asíncrona (`withCheckedThrowingContinuation`) y `withTaskCancellationHandler`.
  - Gestiona descargas directas a disco sin retener buffers en memoria RAM.
  - Implementa cancelación inmediata de sockets y reintentos con retraso exponencial para fallos de red transitorios.
- **`DownloadValidator`**:
  - Comprueba que el código de estado HTTP se encuentre en el rango `200...299`.
  - Verifica que el tipo MIME corresponda a formatos de documento aceptables (`application/pdf`, `binary/octet-stream`).
  - Valida que el tamaño del archivo no sea 0 y respete el límite máximo configurado.
- **`DownloadQueue`**:
  - Clase `@Observable` aislada al `@MainActor` que conecta el estado reactivo de las transferencias con las vistas de SwiftUI.

---

### 4. Capa de Archivos y Criptografía (`Core/Files/`)
- **`FileOrganizer`**:
  - Administra la jerarquía en `~/Downloads/ScribeMac/`:
    - `Incoming/`: Archivos temporales durante la transferencia.
    - `Library/`: Archivos descargados, validados y catalogados.
    - `Failed/`: Archivos corruptos, HTMLs falsos o descargas truncadas para auditoría.
    - `Logs/`: Registro de eventos.
  - Sanitiza nombres eliminando caracteres no permitidos (`/`, `:`, `\`, `*`, `?`, `<`, `>`, `|`, `"`) y limitando la longitud máxima a 120 caracteres.
- **`FileHasher`**:
  - Utiliza el framework nativo **CryptoKit** de Apple.
  - Procesa archivos mediante streaming en bloques de 64 KB, garantizando que el cálculo de SHA-256 no consuma memoria excesiva en archivos de gran tamaño.
- **`DuplicateDetector`**:
  - Previene sobrescrituras accidentales. Si existe un archivo con idéntico nombre y hash, notifica la duplicidad. Si el hash es diferente, genera sufijos secuenciales: `Nombre (2).pdf`, `Nombre (3).pdf`.

---

### 5. Capa de Validación PDF y Metadatos (`Core/PDF/`)
- **`PDFValidator`**:
  - Valida que los primeros 5 bytes contengan la firma mágica obligatoria `%PDF-`.
  - Detecta páginas de error HTML camufladas con extensión `.pdf`.
  - Abre el archivo con **PDFKit** (`PDFDocument`), verificando que `pageCount > 0` y que el documento sea legible y no esté bloqueado.
- **`PDFMetadataReader`**:
  - Extrae atributos del documento (Título, Autor, Asunto, Creador, Fechas de Creación y Modificación).
- **`PDFThumbnailGenerator`**:
  - Genera miniaturas vectorizadas de alta calidad de la primera página mediante `PDFPage.thumbnail(of:for:)` de PDFKit en el hilo principal.

---

### 6. Capa de Persistencia (`Persistence/`)
- **`SwiftDataStore`**:
  - Utiliza **SwiftData** de Apple con modelos nativos:
    - `DocumentRecord`: Datos del documento en la biblioteca local, hash SHA-256, ruta en disco y número de páginas.
    - `DownloadRecord`: Registro histórico de cada trabajo (URL original, URL canónica, estado, tamaño, errores).
    - `ProviderRecord`: Catálogo de proveedores reconocidos.
  - Ofrece soporte para almacenamiento persistente en disco o en memoria (`inMemory: true`) para pruebas unitarias.

---

### 7. Capa de Presentación (`Features/`)
- **`HomeView`**: Entrada de URL, validación, pegado, drag & drop, tarjeta interactiva de diagnóstico y acciones de descarga.
- **`DownloadsView`**: Supervisión de trabajos con barras de progreso en tiempo real, cancelación interactiva y reintento.
- **`LibraryView`**: Búsqueda por texto en tiempo real, visor embebido con `PDFPreviewView` (PDFKit) y botones de acción rápida (*Mostrar en Finder*, *Abrir*, *Copiar Hash*).
- **`SettingsView`**: Selección visual de carpeta mediante `NSOpenPanel`, límites de descarga y panel de cumplimiento ético.
