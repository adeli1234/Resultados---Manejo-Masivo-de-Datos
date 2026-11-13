# Guía de demostración

Ejecutar los bloques Bash en una misma terminal del host Ubuntu, desde la raíz del proyecto. Los comandos `docker exec` actúan dentro del contenedor. No se requiere instalar componentes ni arrancar servicios HDFS/YARN para esta práctica local.

## 1. Mostrar las evidencias (sin ejecutar Hadoop)

```bash
REF=resultados/ejecucion_20261103_200113
cat "$REF/pi.txt"
od -An -v -tx1 "$REF/pi_1_16.hex" | tr -d ' \n'
printf '\n'
rg 'Start Digit|Number of Digits|Number of Maps|Duration is' "$REF/bbp.log"
rg 'bits skipped|nThreads|nJobs|nParts|: done|hex digits' "$REF/distbbp.log"
```

Se necesita `rg` para estas consultas; si no está instalado, usar `grep -E` con los mismos patrones. Explicar: «BBP obtuvo el prefijo hexadecimal `243F6A8885A308D3` y la representación decimal `3.1415926535897932`. DistBBP obtuvo otro bloque, `574E69A458FF`, después de omitir 1000 bits».

Los tiempos de referencia son **1.262 s** y **140.972 s**. Son tiempos observados de los programas, no una garantía para la demo ni una comparación con cargas equivalentes. Para una exposición breve, las evidencias permiten explicar DistBBP sin esperar otra ejecución completa.

## 2. Revisar el entorno antes de una demo en vivo

```bash
docker info
docker inspect --format '{{.State.Status}} {{.Config.Image}}' hadoop
docker start hadoop
docker exec -u hadoop cat /etc/os-release
docker exec -u hadoop /usr/lib/jvm/java-17-openjdk-amd64/bin/java -version
docker exec -u hadoop -e JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
  hadoop /opt/hadoop/bin/hadoop version
```

Comprobar Debian 12, Java 17 y Hadoop 3.3.6. La configuración preparada debe conservar `mapreduce.framework.name=local` y `fs.defaultFS=file:///`. Revisar `core-site.xml` y `mapred-site.xml` en el directorio efectivo de configuración del contenedor (`HADOOP_CONF_DIR`, si está definido; normalmente `/opt/hadoop/etc/hadoop`). La ubicación efectiva no se pudo verificar en esta revisión. Después de ejecutar, confirmar `LocalJobRunner`, `job_local...` y rutas `file:/...` en el registro. Si aparecen YARN/HDFS, detener la comparación con las evidencias locales y revisar la configuración.

## 3. Opción automática: ambos ejemplos

```bash
bash scripts/ejecutar.sh
```

El script imprime el destino de las evidencias. Reservar al menos unos tres minutos como margen orientativo; el total no fue medido. Conservar esa ruta para mostrar los archivos nuevos. El éxito termina con `Ejecuciones terminadas.`; comprobar también las salidas.

## 4. Opción manual: solo BBP para una demo breve

Este bloque usa un directorio nuevo del host y nombres derivados para las rutas del contenedor. No ejecutar la opción automática además de la manual salvo que se necesite otra corrida.

```bash
set -euo pipefail
JAR=/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar
JAVA_CONT=/usr/lib/jvm/java-17-openjdk-amd64
mkdir -p resultados
DEMO=$(mktemp -d "$PWD/resultados/demo_$(date +%Y%m%d_%H%M%S)_XXXXXX")
DEMO_ID=${DEMO##*/}
BBP_DIR=/tmp/bbp_equipo5_$DEMO_ID

docker exec -u hadoop -e JAVA_HOME="$JAVA_CONT" \
  hadoop /opt/hadoop/bin/hadoop jar "$JAR" bbp 1 16 2 "$BBP_DIR" \
  2>&1 | tee "$DEMO/bbp.log"
docker cp "hadoop:$BBP_DIR/pi.txt" "$DEMO/pi.txt"
docker cp "hadoop:$BBP_DIR/pi_1_16.hex" "$DEMO/pi_1_16.hex"
cat "$DEMO/pi.txt"
printf 'Evidencias: %s\n' "$DEMO"
```

Resultado esperado: 16 dígitos `243F6A8885A308D3`, decimal `3.1415926535897932`, dos Maps y un Reduce. Explicar: «Los Maps calculan bloques; Shuffle/Sort los ordena por posición y el reducer los concatena». El trabajo registrado tardó 1.262 s; el comando completo puede tardar más.

## 5. Extensión manual opcional: DistBBP

Continuar en la misma terminal después del bloque anterior, que define las variables:

```bash
REMOTO=/tmp/distbbp_equipo5_remote_$DEMO_ID
LOCAL=/tmp/distbbp_equipo5_local_$DEMO_ID
docker exec -u hadoop mkdir -p "$LOCAL"

docker exec -u hadoop -e JAVA_HOME="$JAVA_CONT" \
  hadoop /opt/hadoop/bin/hadoop jar "$JAR" distbbp 1000 2 1 m 2 \
  "$REMOTO" "$LOCAL" 2>&1 | tee "$DEMO/distbbp.log"
docker cp "hadoop:$LOCAL" "$DEMO/distbbp"
tail -n 5 "$DEMO/distbbp.log"
find "$DEMO/distbbp" -type f | wc -l
```

Esperar el bloque `574E69A458FF` y 14 archivos de resultados locales. El registro de referencia termina con `574E69A458FF 2 (12 hex digits)`. Explicar: «Son 14 sumatorias con un trabajo por sumatoria y dos Maps por trabajo. La combinación final la hace el coordinador. Elegimos MapSide, por lo que no hubo tareas Reduce».

Los 140.972 s observados incluyen esperas: el log imprime `sleep(10s)` una vez por trabajo. `2` hilos y `2` partes no significan dos computadoras ni demuestran que las tareas corrieron simultáneamente.

## Fallos y respuestas breves

| Situación | Explicación o acción |
|---|---|
| Docker no responde o deniega permisos | Revisar `docker info`; resolver acceso en el host antes de la demo |
| `hadoop` no está en PATH | Usar el ejecutable absoluto de los bloques, como hace el script |
| Java no se encuentra | Revisar la ruta `JAVA_CONT`; la ruta documentada es amd64 |
| BBP informa que la carpeta existe | Generar una nueva demo con otro identificador; conservar las salidas |
| DistBBP no genera trabajos nuevos | Puede estar reutilizando una carpeta local con resultados; para repetir la carga usar rutas nuevas |
| `.hex` se ve ilegible | Es binario; mostrarlo con `od` o abrir `pi.txt` |
| La advertencia de métricas aparece | Ya ocurrió en ejecuciones exitosas; comprobar final del registro y archivos |
| Preguntan por el clúster | Se usó LocalJobRunner dentro de un contenedor, sin nodos distribuidos |
| Preguntan cuál es más rápido | Las cargas y mediciones difieren; esta práctica no permite determinarlo |

Los bloques manuales están revisados sintácticamente; no se ejecutaron contra Docker durante esta revisión por falta de acceso al socket. La ejecución real anterior corresponde al script original funcional. No borrar archivos ni el contenedor después de la demostración.
