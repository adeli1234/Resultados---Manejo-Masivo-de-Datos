# Explicación técnica

## Qué calcula BBP

La fórmula de Bailey–Borwein–Plouffe expresa π como:

\[
\pi=\sum_{k=0}^{\infty}\frac{1}{16^k}
\left(\frac{4}{8k+1}-\frac{2}{8k+4}-\frac{1}{8k+5}-\frac{1}{8k+6}\right).
\]

Cada término disminuye por una potencia de 16. Para extraer dígitos desde un desplazamiento `d`, se obtiene la parte fraccionaria de `16^d π`. En la parte finita de las sumas se emplea exponenciación modular; la cola decreciente se aproxima con precisión controlada. Así se pueden obtener dígitos hexadecimales de una posición sin generar todos los anteriores. Un dígito hexadecimal representa cuatro bits; no es un dígito decimal. La fórmula y su variante de Bellard se describen en el [artículo de Tsz-Wo Sze, sección 1](https://arxiv.org/html/1008.3171v2).

En `bbp 1 16 2`, se calculan las primeras 16 posiciones hexadecimales **después del punto**. El resultado es `0x3.243F6A8885A308D3`. El texto decimal conservado es `3.1415926535897932`; es una representación finita, no π completo.

## BBP: Map → Shuffle/Sort → Reduce

La entrada es generada por el programa a partir de posiciones y longitudes; no lee un archivo de datos externo. El trabajo se reparte por carga estimada, no necesariamente por igual número de dígitos. En el [registro BBP](../resultados/ejecucion_20261103_200113/bbp.log) aparecen:

| Tarea | Desplazamiento desde cero | Longitud hexadecimal | Posiciones fraccionarias |
|---|---:|---:|---|
| Map 0 | 0 | 12 | 1–12 |
| Map 1 | 12 | 4 | 13–16 |

Cada mapper calcula un bloque y emite su desplazamiento como clave y los bytes calculados como valor. Shuffle/Sort reúne y ordena los bloques por desplazamiento. El único reducer los concatena en ese orden y escribe los archivos finales. No se suman dos aproximaciones completas de π. Este comportamiento se puede contrastar con [BaileyBorweinPlouffe.java de Apache](https://github.com/apache/hadoop/blob/trunk/hadoop-mapreduce-project/hadoop-mapreduce-examples/src/main/java/org/apache/hadoop/examples/BaileyBorweinPlouffe.java).

Flujo textual para un diagrama:

```text
Parámetros: inicio=1, cantidad=16, maps=2
  → Generación de dos splits (offset=0, longitud=12) y (offset=12, longitud=4)
  → Map 0: bloque 243F6A8885A3   |   Map 1: bloque 08D3
  → Pares (offset, bytes)
  → Shuffle/Sort: reunión y orden ascendente por offset
  → Reduce único: concatenación de bloques
  → pi_1_16.hex: 8 bytes binarios
  → pi.txt: representación hexadecimal y conversión decimal
```

El registro muestra dos grupos y dos registros de entrada al reducer, `Shuffled Maps =2` y 48 bytes de shuffle. `Reduce output records=0` no significa ausencia de resultados: el ejemplo escribe los archivos finales directamente durante la limpieza del reducer, en vez de emitir registros normales con `context.write`.

## DistBBP: otra descomposición del cálculo

DistBBP utiliza una fórmula de tipo BBP basada en Bellard y coordina trabajos `DistSum`. La interfaz distingue bits omitidos, hilos del coordinador, trabajos por sumatoria, modalidad de cálculo y partes por trabajo. Puede recuperar resultados previos de su directorio local y combinar las sumas al terminar. Véase [DistBbp.java de Apache](https://github.com/apache/hadoop/blob/trunk/hadoop-mapreduce-project/hadoop-mapreduce-examples/src/main/java/org/apache/hadoop/examples/pi/DistBbp.java).

En `distbbp 1000 2 1 m 2`, `1000` es un desplazamiento **en bits**, no una cantidad de dígitos por calcular. Se empieza en el bit fraccionario 1001; como 1000/4 = 250, el bloque hexadecimal comienza en la posición 251. No corresponde al prefijo obtenido por BBP.

El [registro DistBBP](../resultados/ejecucion_20261103_200113/distbbp.log) contiene 14 sumatorias: `P8_1`, `P8_3`, `P8_5`, `P8_7` y `P20_3`, `P20_5`, …, `P20_21` (índices impares). Con un trabajo por sumatoria se lanzaron 14 trabajos; cada uno generó dos splits y ejecutó dos Maps: **28 tareas Map en total**.

### Modalidad observada: MapSide (`m`)

Cada mapper evalúa una parte de una sumatoria y escribe su resultado. El coordinador recupera y combina las partes; luego combina las 14 sumatorias para producir el bloque de π. Esa combinación en el programa cliente no es una tarea Reduce de Hadoop. No se lanzó ningún reducer ni hubo shuffle hacia reducers en estos trabajos. La distinción entre cálculo MapSide y ReduceSide se explica en el [artículo de Sze, sección 4.1](https://arxiv.org/html/1008.3171v2).

```text
Parámetros: omitir 1000 bits, 2 hilos, 1 trabajo/suma, m, 2 partes/trabajo
  → Coordinador prepara 14 sumatorias y consulta resultados anteriores
  → Directorio local nuevo: no hay resultados para reutilizar
  → 14 trabajos DistSum
      → Cada trabajo divide su sumatoria en 2 partes
      → 2 Maps calculan y escriben resultados parciales
      → Coordinador recupera y combina las partes
      → Archivo local P*.jobNNN-*.txt
  → Coordinador combina las 14 sumatorias
  → Registro: 574E69A458FF 2 (12 hex digits)
```

Las modalidades `r` (ReduceSide) y `x` (mixta) pertenecen a la interfaz del ejemplo; no se probaron en esta práctica. No dibujar una etapa Reduce para la ejecución `m` ni atribuir las 28 tareas a 28 máquinas.

## Qué demuestra el entorno

Los identificadores `job_local...`, las líneas `LocalJobRunner` y las rutas `file:/tmp/...` documentan ejecución local. Docker proporciona el entorno de software; un contenedor no constituye por sí solo un clúster Hadoop. La división en tareas ilustra el modelo de programación, pero no demuestra concurrencia entre nodos, tolerancia a fallos ni aceleración distribuida. El concepto general de ordenamiento y reducción está descrito en el [tutorial oficial de Hadoop 3.3.6](https://hadoop.apache.org/docs/r3.3.6/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html).

Las fuentes Java enlazadas se consultaron en `trunk` como referencia del algoritmo y de la interfaz; no son una copia fijada de 3.3.6. No fue posible recuperar el código de la etiqueta 3.3.6 ni inspeccionar el JAR del contenedor durante esta revisión. Los parámetros y flujos observados se sustentan además en las evidencias locales. La interpretación exacta del carácter `2` que sigue al bloque DistBBP queda sin verificar; no se añade a los 12 dígitos anunciados ni se interpreta como una medición.
