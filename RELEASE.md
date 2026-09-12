# Proceso de Release y Distribución de Folium

Guía para compilar, firmar y empaquetar Folium para macOS.

---

## 1. Compilación Release Optimizada

Ejecuta el script oficial de empaquetado:

```bash
./Scripts/build_app.sh
```

El script se encarga de:
1. Compilar el proyecto en modo `Release` usando `xcodebuild`.
2. Generar e incrustar el `AppIcon.icns` multi-resolución en `Contents/Resources`.
3. Firmar el bundle con *Hardened Runtime* y los *Entitlements* de App Sandbox.
4. Validar el sello criptográfico con `codesign`.

---

## 2. Artefacto Resultante

El bundle de aplicación final se genera en:
```text
build/Folium.app
```

Para verificar su firma de código:
```bash
codesign -dv --verbose=4 build/Folium.app
```

Para inspeccionar la arquitectura del binario:
```bash
file build/Folium.app/Contents/MacOS/Folium
```
*Salida esperada:* `Mach-O 64-bit executable arm64`
