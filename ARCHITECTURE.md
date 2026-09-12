# Arquitectura de Folium

Este documento detalla la arquitectura de software, patrones de diseño y flujo de datos de **Folium** para macOS.

---

## 1. Principios de Diseño

1. **Separación Estricta de Responsabilidades:** Lógica de negocio y modelos puros residen en `FoliumCore`; la capa visual y escenas de macOS residen en `Folium`.
2. **Progressive Disclosure:** La interfaz expone exclusivamente lo indispensable para la tarea en curso (pegar enlace, confirmar portada, abrir PDF). Toda la telemetría técnica (ETag, Server, MIME, SHA-256, transiciones de estado) está segregada en un panel lateral de Inspector técnico (`⌥⌘I`).
3. **Flujo de 2 Pasos (Zero Waste):** El análisis de URL no desencadena transferencias de datos masivas. Inspecciona encabezados y metadatos (`.resolvable`), solicitando confirmación visual del usuario antes de descargar.
4. **Almacenamiento por Streaming:** Transferencias delegadas a disco en staging (`Incoming/`) sin cargar archivos completos en memoria RAM.
5. **Aislamiento de Concurrencia:** Actores Swift (`DownloadManager`, `SecurityScopedFolderManager`) para sincronización de estado mutable compartido y `@MainActor` para la UI.

---

## 2. Mapa de Módulos

```
Folium/
├── Sources/
│   ├── Folium/                     # Capa de Presentación (SwiftUI)
│   │   ├── App/                    # Entrada de ciclo de vida y comandos
│   │   │   ├── FoliumApp.swift
│   │   │   ├── FoliumCommands.swift
│   │   │   └── AppEnvironment.swift
│   │   ├── AppModel/               # Estado reactivo (@Observable @MainActor)
│   │   │   ├── AppModel.swift
│   │   │   └── SidebarCategory.swift
│   │   ├── Features/               # Vistas modulares de dominio
│   │   │   ├── Main/               # NavigationSplitView, barra de estado, captura vacía
│   │   │   ├── Content/            # Tarjetas de trabajo y cuadrículas
│   │   │   ├── Library/            # Portadas (QuickLook) y lista con filtros
│   │   │   ├── Inspector/          # Inspector técnico y timeline de eventos
│   │   │   ├── MenuBar/            # MenuBarExtra popover
│   │   │   └── Settings/           # Ajustes TabView con HIG de macOS
│   │   └── Resources/              # Info.plist, Entitlements, AppIcon
│   │
│   └── FoliumCore/                 # Núcleo de Dominio y Servicios
│       ├── Core/
│       │   ├── Download/           # DownloadManager (actor), DownloadQueue
│       │   ├── Files/              # FileOrganizer, DuplicateDetector, FileHasher, SecurityScoped
│       │   ├── PDF/                # PDFValidator (magic bytes), PDFMetadataReader
│       │   ├── Providers/          # ProviderRegistry, DirectPDFProvider, ScribdMetadataProvider
│       │   ├── StateMachine/       # DocumentJob, DocumentState, StateTransitionEvent
│       │   ├── URL/                # URLNormalizer, ScribdURLParser, URLClassifier
│       │   └── Logging/            # AppLogger con subsistemas OSLog
│       └── Persistence/            # SwiftDataStore y modelos (@Model)
│
├── Tests/                          # Suite de pruebas unitarias y de integración
│   ├── FoliumTests/
│   └── Fixtures/Server/            # Servidor mock local en Python
│
├── Scripts/                        # Automatización de build y sellado
│   ├── build_app.sh
│   └── run_test_server.sh
│
└── docs/                           # Documentación y GitHub Pages
```

---

## 3. Máquina de Estados (`DocumentState`)

Las transiciones de cada trabajo están estrictamente controladas:

```
[ received ]
     │
     ▼
[ inspecting ] ───▶ [ unsupported / restricted ]
     │
     ▼
[ resolvable ]  <── (Pausa / Espera de confirmación del usuario)
     │
     ▼ (Confirmar descarga)
  [ queued ]
     │
     ▼
[ downloading ] ───▶ [ paused / cancelled ]
     │
     ▼
[ validating ] (Magic bytes %PDF-, PDFKit)
     │
     ▼
[ finalizing ] (SHA-256 en bloques de 64 KB)
     │
     ▼
[ completed ]  ───▶ (Auto-ocultamiento de cola activa a los 5s)
```

---

## 4. Persistencia y Almacenamiento

- **Metadatos e Índices:** Almacenados en `SwiftData` (`DocumentRecord`, `DownloadRecord`, `ProviderRecord`). En caso de daño en el archivo SQLite persistente, `SwiftDataStore` degrada automáticamente a almacenamiento en memoria (`inMemory: true`).
- **Archivos Físicos:**
  - `Incoming/`: Archivos temporales de streaming en progreso.
  - `Library/`: Documentos validados atómicamente.
  - `Failed/`: Archivos corruptos o truncados aislados para diagnóstico.
  - `SecurityScopedFolderManager`: Preserva marcadores de ámbito de seguridad para carpetas externas configuradas por el usuario.
