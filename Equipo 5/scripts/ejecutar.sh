#!/usr/bin/env bash
set -euo pipefail

# Equipo 5 - Pi por formula BBP
# Requiere el contenedor "hadoop" con Hadoop 3.3.6.

CONTENEDOR="hadoop"
JAR="/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar"

JAVA_HOME_CONTENEDOR="/usr/lib/jvm/java-17-openjdk-amd64"

# Detectar la carpeta principal del repositorio.
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Diferenciar un problema del daemon/permisos de un contenedor inexistente.
echo "Verificando Docker y contenedor..."
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: No se encuentra docker en el host." >&2
    exit 1
fi
if ! docker info >/dev/null; then
    echo "ERROR: No se puede acceder al daemon Docker; revisa el servicio y los permisos." >&2
    exit 1
fi
if ! docker inspect --type container "$CONTENEDOR" >/dev/null 2>&1; then
    echo "ERROR: No existe el contenedor $CONTENEDOR." >&2
    exit 1
fi

docker start "$CONTENEDOR" >/dev/null

# mktemp evita colisiones incluso si dos ejecuciones comienzan en el mismo segundo.
mkdir -p "$PROYECTO/resultados"
DESTINO="$(mktemp -d "$PROYECTO/resultados/ejecucion_$(date +%Y%m%d_%H%M%S)_XXXXXX")"
ID="${DESTINO##*/}"
echo "Evidencias de esta ejecución: $DESTINO"

# Los tres directorios son nuevos; no se borran salidas anteriores.
DIR_BBP="/tmp/bbp_equipo5_$ID"
DIR_REMOTO="/tmp/distbbp_equipo5_remote_$ID"
DIR_LOCAL="/tmp/distbbp_equipo5_local_$ID"

echo "Ejecutando BBP..."
docker exec -u hadoop \
    -e JAVA_HOME="$JAVA_HOME_CONTENEDOR" \
    "$CONTENEDOR" \
    /opt/hadoop/bin/hadoop jar "$JAR" bbp 1 16 2 "$DIR_BBP" \
    2>&1 | tee "$DESTINO/bbp.log"

docker cp "$CONTENEDOR:$DIR_BBP/pi.txt" "$DESTINO/pi.txt"
docker cp "$CONTENEDOR:$DIR_BBP/pi_1_16.hex" "$DESTINO/pi_1_16.hex"

echo "Ejecutando DistBBP..."
docker exec -u hadoop "$CONTENEDOR" \
    mkdir -p "$DIR_LOCAL"

docker exec -u hadoop \
    -e JAVA_HOME="$JAVA_HOME_CONTENEDOR" \
    "$CONTENEDOR" \
    /opt/hadoop/bin/hadoop jar "$JAR" distbbp 1000 2 1 m 2 \
    "$DIR_REMOTO" "$DIR_LOCAL" \
    2>&1 | tee "$DESTINO/distbbp.log"

docker cp "$CONTENEDOR:$DIR_LOCAL" "$DESTINO/distbbp"

echo "Ejecuciones terminadas."
echo "Resultados guardados en: $DESTINO"
