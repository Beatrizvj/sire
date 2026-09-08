# SIRE — Checklist Versión Beta (12 de septiembre de 2026)

> "Versión completa del sistema con todas las funcionalidades implementadas y
> pruebas preliminares." Estado al 8 de septiembre de 2026.

## Entregable de software

- [x] Código completo por *features* (arquitectura limpia + Riverpod)
- [x] `flutter analyze` sin problemas
- [x] `flutter test` — **47 pruebas** en verde (unit + widget)
- [x] `flutter build apk --release` genera el APK (~56 MB)
- [x] Consola web en vivo y respondiendo (`https://sire-app-179d3.web.app`)
- [x] Trabajo en rama `beta/pruebas-preliminares` con commits claros

## Funcionalidades (dos apps desde un mismo código)

App móvil (ciudadano):
- [x] Registro con foto de DPI (anverso/reverso) obligatoria
- [x] Login y recuperación de contraseña
- [x] SOS desde botón en pantalla (con categoría + cuenta regresiva RF-13)
- [x] SOS por botón de encendido (servicio nativo Kotlin)
- [x] Historial y clasificación/cancelación de la propia alerta
- [x] Mapa (marcadores + mapa de calor) y ajustes

Consola web / app (COCODE y Municipalidad):
- [x] Bandeja de emergencias en tiempo real + atención (con "atendida por")
- [x] Enrutamiento de alertas por aldea
- [x] Aprobación de cuentas + auditoría
- [x] Gestión de usuarios, roles, comunidades y contactos de confianza
- [x] Verificación de identidad ("Ver DPI") con permiso `puedeVerIdentidad`
- [x] Categorías de incidente configurables
- [x] Dashboard, mapa de calor en vivo y reportes con exportación CSV/Excel/PDF
- [x] Alarma sonora + visual al entrar una alerta (RF-14)

## Evidencia de entrega

- [x] Reporte de pruebas: [docs/PRUEBAS_BETA.md](PRUEBAS_BETA.md)
- [x] Plan de pruebas manual de flujos críticos (en el mismo reporte)
- [x] APK release (`build/app/outputs/flutter-apk/app-release.apk`)
- [ ] Capturas de los flujos ejecutados en dispositivo/emulador *(pendiente de ejecutar el plan manual)*

## Pendientes / limitaciones documentadas

- [ ] **Notificaciones push (FCM)**: cliente preparado; falta registrar el token
      y una Cloud Function de envío → requiere plan **Blaze**.
- [ ] **Bot de WhatsApp (RF-12)**: requiere plan **Blaze** + Cloud Function +
      proveedor de WhatsApp Business API. Documentado como hito posterior.

## Antes de entregar

- [ ] Ejecutar el plan de pruebas manual y adjuntar capturas
- [ ] Borrar los datos/cuentas de prueba de producción
- [ ] `git push` de la rama y (opcional) abrir Pull Request hacia `main`
