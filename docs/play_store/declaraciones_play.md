# Declaraciones de Play Console — textos usados

## ID de publicidad
No (guardado 23-oct-2026).

## Permisos de ubicación (ubicación en segundo plano) — GUARDADA 23-oct-2026
**Propósito de la app:**
SIRE es una app de alertas de emergencia comunitaria para el municipio de San Miguel Sigüilá, Guatemala. El ciudadano envía un SOS con su ubicación GPS a las autoridades locales (COCODE, Alcaldía Auxiliar y Municipalidad) para que lleguen al lugar de la emergencia.

**Función que usa la ubicación en segundo plano:**
SOS con el botón de encendido: si el usuario activa esta opción, puede enviar una alerta pulsando 3 veces el botón de encendido, incluso con la pantalla bloqueada y la app cerrada. En ese momento la app está en segundo plano y necesita obtener la ubicación para incluirla en la alerta. La ubicación solo se obtiene al disparar un SOS y mientras esa alerta sigue abierta; no se rastrea de forma continua.

**Video (≤30 s, YouTube "No listado"), con la cuenta propia, SIN disparar SOS:**
1. Abrir SIRE en la pantalla principal.
2. Activar el interruptor "Detección por botón de encendido".
3. Se ve el aviso "Ubicación todo el tiempo" (divulgación destacada) → "Continuar".
4. Se abren los ajustes de Android → elegir "Permitir todo el tiempo".
5. Volver a SIRE: el interruptor queda activado. Desactivarlo al terminar.
NO pulsar 3 veces el botón de encendido (enviaría un SOS real).

## Servicios en primer plano — GUARDADA 23-oct-2026 (mismo video)
- FOREGROUND_SERVICE_LOCATION → "Uso compartido de la ubicación iniciado por el usuario".
- FOREGROUND_SERVICE_SPECIAL_USE → "Otro", descripción:
Dos servicios de emergencia. 1) Ciudadanos: si activan la opción, un servicio detecta 3 pulsaciones del botón de encendido (incluso con pantalla bloqueada) y envía un SOS con ubicación. Debe correr sin pausas: si se detiene, el usuario en peligro no puede pedir ayuda. 2) Autoridades (COCODE/Municipalidad): un servicio escucha las alertas SOS entrantes y hace sonar una alarma aunque la app esté en segundo plano; pausarlo retrasaría la respuesta a una emergencia. Ambos muestran notificación permanente y el usuario puede desactivarlos.

Para que el MISMO video sirva a las 3 declaraciones, al final del paso 5 (antes de desactivar)
bajar la cortina de notificaciones y mostrar la notificación permanente de "Detección activa".

## Video (YouTube, No listado, canal @BeatrízVicente-g5d)
https://www.youtube.com/watch?v=1znqP2v8_Is — grabación Screen_Recording_20261023_211839 (28 s): aviso destacado → Permitir todo el tiempo → notificación "SIRE · Detección activa" → interruptor apagado.
