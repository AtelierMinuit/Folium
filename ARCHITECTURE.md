# Architecture

Folium is structured around the principles of separation of concerns and progressive disclosure, both in its UI and internal components.

## Modules
1. **FoliumCore**: Handles the domain logic, networking (via `AppEnvironment`, `DownloadManager`, `DownloadQueue`), state machine (`DocumentJob`), and persistence (`SwiftData`).
2. **Folium**: The presentation layer using `SwiftUI`. Defines the UI structure (`NavigationSplitView`), components (`JobCardView`, `LibraryView`), and application settings.

## Data Flow
- **User Input**: Users paste a URL.
- **AppModel**: The `AppModel` receives the URL, transitions the state to `.resolvable`, and awaits user confirmation.
- **DownloadQueue**: Once confirmed, `DownloadQueue` spawns an asynchronous `Task` to start the download.
- **Provider Architecture**: Currently extending `DirectPDFProvider` and `GenericWebProvider` to handle content safely without DRM subversion.
