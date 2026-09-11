# SIRE — Guion de demostración (Entrega Beta, 12/09/2026)

Orden sugerido para presentar la Beta en ~10–12 min, con los puntos donde
conviene **tomar captura** 📸 para el expediente de evidencia.

## Preparación (antes de empezar)
- Ten listas **cuentas de prueba** (márcalas como prueba y **bórralas al final**):
  - 1 **Ciudadano** aprobado · 1 **COCODE** de una aldea (p. ej. "La Emboscada") ·
    1 **Municipalidad**.
  - Activa `puedeVerIdentidad` a la autoridad que hará la demo del DPI
    (consola web → Usuarios → editar → "Puede ver fotos del DPI").
- Teléfono con el **APK instalado**, GPS y datos activos.
- Consola web abierta: https://sire-app-179d3.web.app
- Terminal en `C:\dev\sire` para correr las pruebas.

## Parte 1 — Pruebas automatizadas (2 min)
1. En la terminal: `flutter analyze` → **"No issues found!"** 📸
2. `flutter test` → **47 pruebas en verde** 📸
3. Menciona el reporte: `docs/PRUEBAS_BETA.md` y `docs/PRUEBAS_SEGURIDAD.md`.

## Parte 2 — App móvil: ciudadano (4 min)
4. **Registro con DPI:** llena datos, elige aldea, toma foto **anverso/reverso** →
   "Crear cuenta" → queda **"en revisión"**. 📸
5. **SOS en pantalla:** entra como ciudadano aprobado → botón **SOS** → elige
   categoría → **cuenta regresiva (RF‑13)** → se envía con ubicación. 📸
6. **SOS por botón de encendido:** activa la detección → pulsa el botón físico
   ×3 → aparece el aviso de SOS registrado. 📸

## Parte 3 — App móvil / web: autoridad (4 min)
7. **Aprobaciones:** como COCODE/Municipalidad, abre la solicitud → **ves las
   fotos del DPI** → asignas rol/aldea → **Aprobar** (queda en auditoría). 📸
8. **Bandeja + enrutamiento por aldea:** la alerta del ciudadano aparece; el
   COCODE solo ve **su** aldea. **Atender** → se registra **"Atendida por
   [nombre]"**. 📸
9. **Mapa de calor:** muestra la densidad de incidentes (ámbar→rojo). 📸
10. **Reportes:** exporta **CSV / Excel / PDF** (incluye "Atendida por" y tiempo
    de respuesta). 📸

## Parte 4 — Seguridad (2 min)
11. Abre el **Simulador de reglas** (Firestore → Reglas → Simulador) y muestra
    1–2 casos de `docs/PRUEBAS_SEGURIDAD.md` (p. ej. **S6** COCODE de otra aldea
    = *denegado*, **S14** auditoría = *denegado editar*). 📸
12. Comenta el modelo: reglas por rol/estado, aislamiento por aldea, service
    account **revocada**, HTTPS y *deny by default*.

## Parte 5 — Distribución y cierre (1 min)
13. **Descarga ciudadana:** muestra la página + **QR**
    (https://sire-app-179d3.web.app/descargar.html). 📸
14. **Repositorio:** rama `beta/pruebas-preliminares` + Pull Request (control de
    versiones/Scrum). 📸
15. **Pendientes documentados:** push y WhatsApp (requieren plan **Blaze**, en
    trámite) — no bloquean la Beta.

## Al terminar
- **Borra las cuentas/datos de prueba** de producción (perfil + fotos DPI desde
  el panel; cuenta de Authentication desde la consola de Firebase).
