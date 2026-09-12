# Security

Folium adheres strictly to macOS App Sandbox policies.

## Key Principles
1. **Sandbox Enforcement**: Full App Sandbox is enabled with least privilege entitlements.
2. **Security-Scoped Bookmarks**: The app uses `NSOpenPanel` for users to select a Library directory and stores security-scoped bookmarks to retain access across sessions.
3. **No DRM Circumvention**: Folium does not bypass DRM, break paywalls, or solve CAPTCHAs automatically.
