# ScribeMac 📄🍎

**ScribeMac** es una aplicación macOS nativa de propósito educativo desarrollada en **Swift 6**, **SwiftUI**, **PDFKit**, **URLSession**, **SwiftData** y optimizada para **Apple Silicon (ARM64)**.

El objetivo del proyecto es estudiar la arquitectura profesional necesaria para recibir enlaces documentales, normalizarlos, clasificar recursos, resolver accesos autorizados, descargar en streaming, verificar integridad criptográfica y estructurar una biblioteca local persistente con previsualización en macOS.

---

## 🌟 Principios Fundamentales y Cumplimiento Ético

> **Aviso Educativo y Legal**: ScribeMac **no** elude mecanismos de protección digital (DRM), no evade paywalls, no resuelve ni elude CAPTCHAs, no falsifica tokens y no reproduce APIs privadas no autorizadas.
>
> Cuando un enlace pertenezca a un recurso sin descarga pública permitida (ejemplo: documentos protegidos en plataformas propietarias), el recurso se clasifica técnicamente como **`restricted`** y el proyecto ofrece proveedores de prueba (**fixtures** y **mocks**) para estudiar el ciclo de vida completo de descarga, hashing y validación.

---

## 🚀 Características Principales

1. **Pipeline de URL Robusto**:
   - Sanitización contra manipulación y *path traversal*.
   - Eliminación automática de parámetros de rastreo (`utm_*`, `fbclid`, `ref`, etc.).
   - Parser especializado para Scribd (`/document/`, `/doc/`, `/presentation/`) con generación de URLs canónicas.
   - Clasificación por tipo de proveedor y recurso.

2. **Arquitectura Extensible de Proveedores (`DocumentProvider`)**:
   - `DirectPDFProvider`: Descarga directa de PDFs públicos con inspección HEAD/GET y seguimiento de redirecciones.
   - `OpenRepositoryProvider`: Resolución de repositorios académicos y de acceso abierto (ej. arXiv.org).
   - `ScribdMetadataProvider`: Análisis educativo de metadatos públicos y clasificación segura en `.restricted`.
   - `MockRestrictedProvider`: Resolución de enlaces `scribemac://fixture/...` contra documentos de prueba locales.

3. **Motor de Descargas en Streaming**:
   - Implementado sobre `URLSessionDownloadTask` y actores de concurrencia Swift 6.
   - Sin carga de archivos grandes en memoria RAM (0 MB buffer overhead).
   - Soporte para progreso en tiempo real, cancelación interactiva y reintentos con backoff exponencial.

4. **Validación Exhaustiva de Archivos PDF**:
   - Comprobación de cabecera mágica `%PDF-` en los primeros 5 bytes.
   - Detección y rechazo de páginas HTML camufladas con extensión `.pdf`.
   - Verificación de apertura e integridad de páginas mediante **PDFKit** (`PDFDocument`).
   - Lectura de metadatos (Título, Autor, Fecha de Creación) y extracción de miniaturas (`NSImage`).

5. **Integridad y Deduplicación Criptográfica**:
   - Cálculo de hash **SHA-256** mediante **CryptoKit** en bloques de 64 KB.
   - Detección de duplicados basada en hash + tamaño exacto.
   - Asignación incremental de nombres (`Autor - Título (2).pdf`) para evitar sobrescrituras accidentales.

6. **Persistencia con SwiftData**:
   - Modelos `@Model`: `DocumentRecord`, `DownloadRecord`, `ProviderRecord`.
   - Historial de auditoría completo y biblioteca persistente.

7. **Interfaz Nativa SwiftUI**:
   - Navegación moderna con `NavigationSplitView`.
   - Entrada de URL con soporte para arrastrar y soltar (*drag & drop*) y pegado seguro.
   - Visor integrado con **PDFView** de PDFKit.
   - Acciones nativas: *Mostrar en Finder*, *Abrir con visor del sistema*, *Copiar SHA-256*.

---

## 📂 Estructura del Proyecto

```
ScribeMac/
├── Package.swift                  # Definición SPM con modo estricto Swift 6
├── ScribeMac.app                  # Bundle ejecutable para macOS Apple Silicon
├── Sources/
│   ├── ScribeMacCore/             # Biblioteca modular de lógica de negocio
│   │   ├── Core/
│   │   │   ├── Models/            # ResourceStatus, DocumentJob, DocumentMetadata
│   │   │   ├── Logging/           # AppLogger (OSLog categorizado)
│   │   │   ├── URL/               # URLNormalizer, ScribdURLParser, URLClassifier
│   │   │   ├── Providers/         # DocumentProvider, DirectPDF, Scribd, OpenRepo, Mock
│   │   │   ├── Download/          # DownloadManager, DownloadValidator, DownloadQueue
│   │   │   ├── Files/             # FileOrganizer, FileHasher, DuplicateDetector
│   │   │   └── PDF/               # PDFValidator, PDFMetadataReader, PDFThumbnailGenerator
│   │   └── Persistence/           # Modelos SwiftData y SwiftDataStore
│   └── ScribeMac/                 # Aplicación SwiftUI macOS
│       ├── App/                   # ScribeMacApp y AppEnvironment
│       ├── Features/              # Vistas: Home, Downloads, Library, Settings
│       └── Resources/             # Info.plist y Entitlements
├── Tests/
│   ├── ScribeMacTests/            # 31 pruebas unitarias y de integración
│   └── Fixtures/                  # PDFs válidos, dañados, HTML falso y servidor Python
├── Scripts/
│   ├── build_app.sh               # Script de compilación y empaquetado .app
│   └── run_test_server.sh         # Utilidad para iniciar el servidor de prueba
├── README.md                      # Este documento
├── ARCHITECTURE.md                # Arquitectura técnica detallada
├── SECURITY.md                    # Políticas de seguridad y threat modeling
└── TESTING.md                     # Guía y reporte de pruebas
```

---

## 🛠️ Compilación e Instalación

### Requisitos del Sistema
- macOS 14.0 o superior (Verificado en macOS 26 / Sonoma / Sequoia).
- Apple Silicon ARM64.
- Xcode 15+ o Swift 6 toolchain.

### Compilar y Empaquetar la Aplicación
Para generar el bundle nativo firmado:
```bash
./Scripts/build_app.sh
```
El archivo `ScribeMac.app` se generará en la raíz del repositorio. Puedes abrirlo directamente con:
```bash
open ScribeMac.app
```

### Ejecutar las Pruebas Unitarias
```bash
swift test
```
Las 31 pruebas automatizadas validarán todos los componentes sin depender de servicios externos.

---

## 🧪 Pruebas Educativas Rápidas

Puedes probar el pipeline completo directamente en la interfaz usando los accesos rápidos:

1. **Recurso Restringido (Scribd)**:
   Pega: `https://www.scribd.com/document/123456789/trabajo-social`
   - El analizador normaliza la URL, identifica el ID `123456789`, el slug `trabajo-social` y clasifica el recurso éticamente como **`restricted`**.
2. **Fixture Local de Prueba**:
   Pega: `scribemac://fixture/document/sample-1`
   - Resuelve el documento contra un PDF de muestra local, lo descarga, valida sus magic bytes `%PDF-`, calcula su SHA-256 y lo guarda en la biblioteca.
3. **Repositorio de Acceso Abierto (arXiv)**:
   Pega: `https://arxiv.org/abs/2301.00001`
   - Resuelve automáticamente la URL canónica del PDF público (`https://arxiv.org/pdf/2301.00001.pdf`).
