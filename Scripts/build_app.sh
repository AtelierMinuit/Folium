#!/bin/bash
set -e

echo "🔨 Compilando ScribeMac en modo Release..."
swift build -c release

BIN_DIR=$(swift build -c release --show-bin-path)
APP_DIR="ScribeMac.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creando estructura de bundle ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "📋 Copiando binario y recursos..."
cp "${BIN_DIR}/ScribeMac" "${MACOS_DIR}/ScribeMac"
cp "Sources/ScribeMac/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy any resources if available
if [ -d "${BIN_DIR}/ScribeMacPackageTests.bundle" ]; then
    cp -R "${BIN_DIR}/"*.bundle "${RESOURCES_DIR}/" 2>/dev/null || true
fi

echo "🔏 Firmando la aplicación (Ad-hoc con Entitlements de mínimos privilegios)..."
codesign --force --options runtime --entitlements "Sources/ScribeMac/Resources/ScribeMac.entitlements" --sign - "${APP_DIR}"

echo "✅ Verificando firma..."
codesign --verify --verbose "${APP_DIR}"

echo "🎉 ScribeMac.app empaquetada con éxito en $(pwd)/${APP_DIR}"
ls -ld "${APP_DIR}"
