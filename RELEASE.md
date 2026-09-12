# Release

Folium builds to a `.app` bundle using Xcode and `xcodegen`.

To create a release build:
```bash
xcodebuild -scheme Folium -configuration Release archive
```
