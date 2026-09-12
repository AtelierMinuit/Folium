# Changelog

## 1.0 (MVP) - Folium Release
- **Name Change**: Renamed project from ScribeMac to Folium.
- **Folium Architecture**: Extracted Xcode project generation (`Folium.xcodeproj`) via `xcodegen`.
- **UI Redesign**: Complete Folium UX workflow with `EmptyCaptureView`, `SidebarCategory`, `JobCardView` and `LibraryView`.
- **Engine**: Robust HTTP client parsing headers, file streaming to staging, then atomic movement to library.
- **Validations**: PDF strict validation, duplicate detection by SHA-256 using CryptoKit.
- **Persistence**: SwiftData implemented via `DocumentRecord` for local library.
- **Apple Standards**: App Sandbox configured, security-scoped bookmarks for external library folders.
- **Documentation**: Extensive project architecture documentation added.
