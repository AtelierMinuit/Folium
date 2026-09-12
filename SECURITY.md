# Políticas de Seguridad y Privacidad de Folium

Folium implementa las mejores prácticas recomendadas por Apple para aplicaciones de macOS.

---

## 1. App Sandbox

La aplicación se ejecuta estrictamente dentro del **App Sandbox**:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

- **Mínimo Privilegio:** Únicamente se solicita salida de red hacia enlaces proporcionados por el usuario y acceso a su carpeta de Descargas o la ruta explícita elegida en `NSOpenPanel`.
- **Sin elevación de permisos:** Nunca se requiere `sudo`, helpers con privilegios root, instalación de LaunchDaemons ni desactivación de SIP.

---

## 2. Hardened Runtime

El binario de Folium está compilado con **Hardened Runtime** activo (`flags=0x10002(adhoc,runtime)`):
- Previene la inyección de código dinámico.
- Bloquea la manipulación de memoria no autorizada.
- Requiere firma de código válida para bibliotecas dinámicas.

---

## 3. Privacidad Absoluta de Datos

- **Cero Telemetría:** No se recopila información del usuario, URLs introducidas, títulos ni documentos descargados.
- **Sin Dependencias Inseguras:** Cero bibliotecas de terceros que puedan introducir vectores de ataque o cadenas de suministro comprometidas.
- **Sin Registro de Secretos:** `AppLogger` utiliza categorías de `OSLog` (`privacy: .public` / `.private`) asegurando que jamás se registren cookies, encabezados de autorización ni tokens en la consola del sistema.

---

## 4. Cumplimiento Legal y Ético

- Folium rechaza explícitamente cualquier mecanismo destinado a:
  - Romper o eludir cifrado o DRM.
  - Saltar paywalls o mecanismos de autenticación protegidos.
  - Resolver automáticamente retos CAPTCHA.
  - Fabricar o falsificar credenciales de acceso.
