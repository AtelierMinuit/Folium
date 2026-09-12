#!/bin/bash
set -e

echo "🔨 Compilando Folium en modo Release con xcodebuild..."
xcodebuild -scheme Folium -configuration Release build CONFIGURATION_BUILD_DIR="$(pwd)/build" -quiet

echo "🔏 Sellando icono e instalando en bundle..."
mkdir -p build/Folium.app/Contents/Resources
cp Sources/Folium/Resources/AppIcon.icns build/Folium.app/Contents/Resources/AppIcon.icns

echo "🔏 Firmando la aplicación (Hardened Runtime + App Sandbox)..."
codesign --force --sign - -o runtime --entitlements "Sources/Folium/Resources/Folium.entitlements" "build/Folium.app"

echo "✅ Verificando firma y entitlements..."
codesign --verify --verbose "build/Folium.app"
codesign -dv --verbose=4 "build/Folium.app"

echo "🎉 Folium.app empaquetada con éxito en $(pwd)/build/Folium.app"
ls -ld "build/Folium.app"

