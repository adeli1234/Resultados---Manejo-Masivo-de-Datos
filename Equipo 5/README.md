# Equipo 5 · MapReduce con Hadoop 3.3.6

Repositorio técnico de la práctica de cálculo de π con los ejemplos oficiales `bbp` y `distbbp`. Incluye automatización, evidencias reales, explicación del procesamiento y un ejercicio para el equipo. No contiene una implementación Java propia ni diapositivas.

**Alcance comprobado:** Ubuntu como host, Docker y un contenedor `hadoop` con Debian 12, Java 17 y Hadoop 3.3.6. Se ejecutó con **LocalJobRunner**, dentro de un solo contenedor; no se demostró un clúster multinodo.

## Lectura recomendada

1. [Explicación técnica y flujos para diagramar](docs/explicacion-tecnica.md).
2. [Resultados y límites de la comparación](docs/resultados-y-comparacion.md).
3. [Guía de demostración](docs/guia-demostracion.md).
4. [Ejercicio](ejercicio/ejercicio.md) y [solución](ejercicio/solucion.md).

## Prerrequisitos

- Bash y herramientas habituales de Ubuntu (`date`, `mktemp`, `tee`, `od`, `tr`, `find`). Python 3 para el ejercicio.
- Docker instalado, daemon accesible y permiso del usuario para operarlo.
- Contenedor existente llamado `hadoop`, con usuario `hadoop` y permiso de escritura en `/tmp`.
- Ejecutable `/opt/hadoop/bin/hadoop` y JAR oficial `/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar`.
- `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64` dentro del contenedor; esta ruta corresponde al entorno amd64 probado.
- Configuración Hadoop en modo local y sistema de archivos local (`mapreduce.framework.name=local`, `fs.defaultFS=file:///`). No cambiar a HDFS/YARN para seguir estos comandos.

El contenedor y su configuración deben estar preparados previamente. No hay Dockerfile, imagen fijada por digest ni copia de la configuración Hadoop en este repositorio: la reconstrucción del entorno desde cero no está verificada. Java 17 describe el entorno de la práctica; no implica una declaración de compatibilidad general de Hadoop.

Desde la raíz del proyecto, las siguientes consultas no lanzan trabajos:

```bash
docker info
docker inspect --format '{{.State.Status}} {{.Config.Image}}' hadoop
docker start hadoop
```

Con el contenedor iniciado, comprobar versiones y disponibilidad del JAR:

```bash
docker exec -u hadoop cat /etc/os-release
docker exec -u hadoop /usr/lib/jvm/java-17-openjdk-amd64/bin/java -version
docker exec -u hadoop -e JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
  hadoop /opt/hadoop/bin/hadoop version
docker exec -u hadoop sh -c 'test -r /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar && test -w /tmp'
```

## Ejecución automática

Desde la raíz:

```bash
bash -n scripts/ejecutar.sh  # Solo valida la sintaxis; no ejecuta Hadoop.
bash scripts/ejecutar.sh
```

El script también puede invocarse mediante su ruta absoluta desde otra carpeta. Verifica acceso a Docker y existencia del contenedor, lo inicia, ejecuta BBP y después DistBBP y copia las salidas al host. Cada ejecución crea `resultados/ejecucion_FECHA_HORA_SUFIJO/` con nombres únicos, sin borrar evidencias. Si falla, conserva lo que haya alcanzado a guardar; un directorio parcial no prueba éxito.

Se mantienen la ruta absoluta de Hadoop y `JAVA_HOME` explícito porque `docker exec` no garantiza el entorno de una terminal interactiva. `set -euo pipefail` permite detectar fallos incluso al enviar el registro a `tee`.

## Comandos y parámetros

Se ejecutan **dentro del contenedor**, a través de `docker exec`. Los comandos completos y la copia al host están en la [guía de demostración](docs/guia-demostracion.md).

```text
/opt/hadoop/bin/hadoop jar JAR bbp 1 16 2 DIRECTORIO_NUEVO
/opt/hadoop/bin/hadoop jar JAR distbbp 1000 2 1 m 2 DIR_REMOTO DIR_LOCAL
```

`JAR` representa la ruta oficial indicada en los prerrequisitos; los directorios representan rutas en el contenedor.

| Ejemplo | Parámetro | Significado en la práctica |
|---|---|---|
| bbp | `1` | Primera posición hexadecimal fraccionaria de π (índice inicial 1) |
| bbp | `16` | Cantidad de dígitos hexadecimales; trabajar con múltiplos de 4 |
| bbp | `2` | Número de tareas Map solicitadas |
| bbp | directorio | Carpeta de trabajo que aún no debe existir |
| distbbp | `1000` | Bits fraccionarios que se omiten; empieza en el bit 1001 |
| distbbp | `2` | Hilos de trabajo del coordinador; no número de nodos |
| distbbp | `1` | Trabajos por sumatoria; con 14 sumatorias resultaron 14 trabajos |
| distbbp | `m` | Cálculo MapSide, sin tareas Reduce en esta ejecución |
| distbbp | `2` | Partes por trabajo; aquí 2 tareas Map por trabajo |
| distbbp | directorios | Área de trabajos y carpeta de resultados recuperables, respectivamente |

Aunque se llame `DIR_REMOTO`, en esta práctica se resolvió al sistema de archivos local del contenedor. No se necesita un conjunto de datos externo: las entradas son parámetros numéricos.

## Resultados esperados y comprobación sin Docker

La ejecución de referencia es [ejecucion_20261103_200113](resultados/ejecucion_20261103_200113/), con 18 archivos: dos registros, dos archivos BBP y 14 resultados DistSum.

| Ejemplo | Resultado guardado | Tareas | Tiempo observado |
|---|---|---|---|
| BBP | `243F6A8885A308D3`; texto decimal `3.1415926535897932` | 2 Maps, 1 Reduce | 1.262 s |
| DistBBP | `574E69A458FF`, después de omitir 1000 bits | 14 trabajos × 2 Maps, sin reducers | 140.972 s |

Son mediciones internas de los programas, no del script completo. Las cargas y las regiones de π difieren; estos tiempos no demuestran cuál algoritmo es más rápido.

```bash
REF=resultados/ejecucion_20261103_200113
cat "$REF/pi.txt"
od -An -v -tx1 "$REF/pi_1_16.hex" | tr -d ' \n'
printf '\n'
tail -n 5 "$REF/distbbp.log"
find "$REF" -type f | wc -l
```

El `.hex` contiene 8 bytes binarios (16 dígitos), por eso se usa `od` en vez de `cat`. `pi.txt` agrupa dígitos mediante espacios. DistBBP registra literalmente `574E69A458FF 2 (12 hex digits)`; conservar la línea completa como evidencia y distinguir el bloque de 12 dígitos del texto que lo sigue.

## Estructura

```text
README.md
.gitignore
scripts/ejecutar.sh
docs/explicacion-tecnica.md
docs/resultados-y-comparacion.md
docs/guia-demostracion.md
ejercicio/ejercicio.md
ejercicio/solucion.md
resultados/
  pi.txt                         # Evidencia previa, sin log asociado aquí
  distbbp/                       # 14 resultados previos
  ejecucion_20261103_195534/      # Intento fallido: Hadoop fuera de PATH
  ejecucion_20261103_200113/      # Ejecución completa de referencia
```

`datos/` está vacío y no interviene en el cálculo; Git no conserva carpetas vacías. Los resultados existentes se mantienen, incluidos el intento fallido y los registros `.log`.

## Errores comunes

| Síntoma | Acción |
|---|---|
| `permission denied` al socket Docker | Comprobar acceso al daemon en el host; resolver permisos según la configuración de la máquina |
| Contenedor inexistente | Revisar `docker ps -a`; el script requiere el contenedor preparado y no lo crea |
| `hadoop: executable file not found in $PATH` | Usar `/opt/hadoop/bin/hadoop`; el intento de las 19:55 conserva este fallo |
| Java no encontrado | Comprobar la ruta de Java y pasar `-e JAVA_HOME=...` a `docker exec` |
| Directorio de salida existente | Elegir un identificador nuevo; no borrar resultados para repetir |
| No aparece `pi.txt` | Verificar éxito de BBP y que la posición inicial sea 1; el ejemplo solo genera la conversión decimal desde ese inicio |
| DistBBP tarda unos 2 min 21 s | El registro incluye 14 esperas de 10 s; no confundirlas con tiempo aritmético |
| `JobTracker metrics system already initialized!` | Advertencia observada incluso en trabajos exitosos; revisar el desenlace y las salidas, no solo la palabra `WARN` |

## Reproducibilidad y estado de revisión

Conservar parámetros, versiones, modo local, directorios nuevos y registros completos. Los nombres y marcas temporales pueden variar: el host nombró la ejecución el 3 de noviembre y los logs del contenedor indican el 4 de noviembre UTC. No exigir tiempos idénticos.

Se revisaron todos los archivos existentes, los conteos de tareas, el binario BBP y la coherencia documental. Las verificaciones de esta revisión se detallan en [resultados y comparación](docs/resultados-y-comparacion.md). No se repitieron los cálculos: el acceso al socket Docker está denegado en esta sesión. `.git` está vacío y `git status` no reconoce este directorio como repositorio Git; queda por revisar los metadatos Git en el entorno de publicación. No se hicieron commits ni pushes.
