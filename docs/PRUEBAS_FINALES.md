# Pruebas finales — Puesta en producción (24-oct-2026)

Entrega oficial: **Municipalidad de San Miguel Sigüilá** y **Alcaldía Auxiliar de
La Emboscada**. Cada prueba se registra con fecha, hora, teléfono y captura.

> ⚠️ Cada SOS llega a autoridades reales (push + WhatsApp). Avisar antes a la
> Municipalidad y a la Alcaldía Auxiliar, y marcar cada alerta de prueba como
> **Falsa alarma** o **Resuelta** al terminar.

## 0. Preparación (30–60 min antes)

- [ ] Cada teléfono de autoridad envió `join write-lake` (siresanmiguel.com/whatsapp.html)
- [ ] `node functions/scripts/estado-whatsapp.js` sin errores
- [ ] Teléfono del ciudadano con la versión publicada (v1.0.0+14) desde siresanmiguel.com
- [ ] Panel abierto en siresanmiguel.com con la cuenta de la Municipalidad

## 1. Alerta y notificación

| # | Prueba | Resultado esperado | ✓ | Evidencia |
|---|--------|--------------------|---|-----------|
| 1.1 | SOS desde el botón en pantalla (GPS encendido) | 1 alerta en el panel con ubicación; push y WhatsApp a la Municipalidad y a la Alcaldía Auxiliar | | |
| 1.2 | SOS con GPS apagado → "Activar" | Se envía con ubicación sin reenviar | | |
| 1.3 | SOS con GPS apagado → "No gracias" | Se envía "Sin ubicación"; **exactamente 1** alerta | | |
| 1.4 | SOS por botón de encendido | **Exactamente 1** alerta (candado de 30 s) | | |

## 2. Seguimiento en vivo

| # | Prueba | Resultado esperado | ✓ | Evidencia |
|---|--------|--------------------|---|-----------|
| 2.1 | Abrir **📍 Seguir en vivo** del WhatsApp | Abre siresanmiguel.com/seguir.html con el mapa | | |
| 2.2 | Caminar 2–3 minutos | El punto se mueve en el enlace, el panel y la app | | |
| 2.3 | "Cómo llegar" | Abre Google Maps con la ruta | | |
| 2.4 | **Dejar de compartir** (notificación o app) | La notificación desaparece; el enlace dice que el ciudadano dejó de compartir; pin gris en el panel | | |
| 2.5 | Marcar la alerta como **Resuelta** | El enlace dice que la alerta ya se cerró | | |
| 2.6 | Alerta con 2 h abiertas | El teléfono deja de enviar; pin gris | | |

## 3. Gestión y bitácora

| # | Prueba | Resultado esperado | ✓ | Evidencia |
|---|--------|--------------------|---|-----------|
| 3.1 | Atender una alerta desde el panel | Aparece "atendida por [nombre]" | | |
| 3.2 | Revisar la Bitácora | Registra quién cambió el estado y cuándo | | |
| 3.3 | Aprobar un usuario nuevo con DPI | La foto del DPI tiene la marca de agua | | |
| 3.4 | Reportes y mapa de calor en el panel | Muestran las alertas de prueba | | |

## Resultado

- Pruebas aprobadas: ___ / 14
- Observaciones:
- Firma / sello Municipalidad: ____________________
- Firma / sello Alcaldía Auxiliar de La Emboscada: ____________________
