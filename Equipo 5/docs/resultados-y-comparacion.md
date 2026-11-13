# Resultados y comparación

## Evidencia de referencia

La carpeta [ejecucion_20261103_200113](../resultados/ejecucion_20261103_200113/) contiene 18 archivos: `bbp.log`, `distbbp.log`, `pi.txt`, `pi_1_16.hex` y 14 archivos `distbbp/P*.txt`. Antes de esta revisión, `du -sh resultados` reportó 260 KB de espacio ocupado (bloques del sistema de archivos, no tamaño lógico exacto).

El host nombró la carpeta con fecha 2026-11-03 a las 20:01:13; los registros usan 2026-11-04 a las 02:01 UTC. La diferencia de seis horas es coherente con la zona America/Mexico_City indicada para el host. No son necesariamente ejecuciones de días distintos.

| Aspecto | BBP | DistBBP |
|---|---|---|
| Parámetros numéricos/modalidad | `1 16 2` | `1000 2 1 m 2` |
| Región calculada | Primeros 16 dígitos hexadecimales fraccionarios | Bloque tras omitir 1000 bits fraccionarios |
| Resultado hexadecimal | `243F6A8885A308D3` | `574E69A458FF` (12 dígitos anunciados) |
| Representación decimal guardada | `3.1415926535897932` | No se guardó una conversión decimal equivalente |
| Trabajos Hadoop | 1 | 14 |
| Tareas Map | 2 | 2 por trabajo; 28 en total |
| Tareas Reduce | 1 | 0, modalidad MapSide |
| Tiempo registrado | 1.262 s | 140.972 s (2 min 20.972 s) |
| Ejecutor | LocalJobRunner | LocalJobRunner |

Fuentes de las cifras: [bbp.log](../resultados/ejecucion_20261103_200113/bbp.log), [pi.txt](../resultados/ejecucion_20261103_200113/pi.txt) y [distbbp.log](../resultados/ejecucion_20261103_200113/distbbp.log). El binario BBP tiene 8 bytes y su lectura hexadecimal coincide con el texto. El registro DistBBP conserva la línea completa `574E69A458FF 2 (12 hex digits)`; el significado del carácter adicional `2` no se verificó contra el código de esa versión.

## Interpretación

BBP termina con un trabajo exitoso, dos splits, dos Maps y un Reduce. Se observan bloques de 12 y 4 dígitos. El reducer recibe dos registros y ensambla la salida; no debe describirse como una suma de aproximaciones independientes.

DistBBP registra 14 envíos, 14 pares de splits y 28 inicios de tareas Map, sin inicios de tareas Reduce. Los 14 archivos DistSum contienen las sumatorias combinadas por trabajo; el número grande de `value=` es una representación interna, no los dígitos de π que deban leerse directamente. Los `duration=0(0ms)` reportados en esas sumatorias pequeñas tampoco significan que toda la ejecución duró cero.

Los registros contienen advertencias `JobTracker metrics system already initialized!` tanto en BBP como en DistBBP. En este caso no impidieron generar las salidas. También hay 14 mensajes `sleep(10s)` en DistBBP y tiempos cercanos a 10 s por trabajo. Esto indica que las esperas del control de trabajos tienen un peso importante en los 140.972 s; no se midió separadamente su contribución exacta.

## Límites metodológicos

- Las cargas no son iguales: difieren la posición, la unidad de desplazamiento, la cantidad de dígitos, la fórmula y la descomposición en trabajos. No calcular un factor de aceleración dividiendo ambos tiempos ni concluir que BBP es universalmente superior.
- BBP informa la duración alrededor de su trabajo; DistBBP informa tiempo transcurrido de su coordinación hasta `done`. Ninguno representa por sí solo el tiempo total del script, que incluye inicio del contenedor y copias.
- Se utiliza una ejecución completa como referencia, sin calentamiento controlado, repeticiones estadísticas ni mediciones independientes de CPU, memoria, disco o carga del host.
- Las tareas se ejecutaron localmente. No se ensayaron varios nodos, fallos, reintentos controlados, escalabilidad ni comparación MapSide/ReduceSide.
- Los archivos prueban los resultados guardados. La revisión actual no volvió a calcular π con Hadoop. El ejercicio ofrece una comprobación independiente del prefijo BBP; no valida de forma independiente el bloque DistBBP.
- No están fijados el digest de la imagen Docker, límites de recursos ni los archivos de configuración. La reproducibilidad se limita al entorno preparado y a las condiciones documentadas.

## Otras evidencias conservadas

| Ruta | Contenido y alcance |
|---|---|
| [resultados/pi.txt](../resultados/pi.txt) | Mismo texto BBP; aquí no tiene log asociado para atribuirle tiempo |
| [resultados/distbbp/](../resultados/distbbp/) | 14 resultados previos, con valores coincidentes con los de referencia; no atribuirles el tiempo de la ejecución posterior |
| [ejecucion_20261103_195534/bbp.log](../resultados/ejecucion_20261103_195534/bbp.log) | Intento fallido porque `hadoop` no estaba en `$PATH`; no es una ejecución completada |

## Cambios del script y validación de esta revisión

Se conservaron los comandos Hadoop, parámetros, usuario y `JAVA_HOME` ya probados. Se corrigieron únicamente:

1. Línea vacía anterior al shebang: ahora `#!/usr/bin/env bash` está en la primera línea para la invocación directa.
2. Identificador con resolución de segundos y `mkdir -p`: podía reutilizar un destino al iniciar dos ejecuciones en el mismo segundo. Ahora `mktemp -d` reserva un directorio único; su nombre también distingue las rutas del contenedor.
3. Diagnóstico de Docker: el fallo de `docker inspect` se interpretaba siempre como contenedor inexistente. Ahora se comprueba primero la disponibilidad del comando y el acceso al daemon, y se inspecciona explícitamente un contenedor. No se crea una carpeta de resultados si estas verificaciones fallan.

Verificaciones realizadas: lectura de todos los archivos existentes; análisis completo de registros; comparación de los 14 resultados previos; comprobación binaria BBP; sintaxis Bash del script y de los bloques ejecutables de la documentación; resolución de enlaces locales; ejercicio independiente; integridad SHA-256 de todas las evidencias antes y después. Se verificaron además el flujo y los fallos del script con un sustituto de Docker en una copia temporal: esto comprueba la automatización, no ejecuta Hadoop ni valida Docker real.

Límites actuales: el socket Docker devuelve `permission denied`, por lo que no se pudo inspeccionar el contenedor ni repetir la ejecución integrada. ShellCheck no está disponible; se utilizó `bash -n`. `.git` está vacío y `git status` falla; no se pudo inspeccionar historial, remoto ni diferencias contra commits. Antes de publicar, revisar Git en el entorno real, confirmar las consultas de versiones/configuración de la guía y hacer una ejecución integrada del script modificado si se requiere validar su interacción real con Docker.
