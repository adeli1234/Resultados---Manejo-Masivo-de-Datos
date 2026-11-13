# Solución del mini ejercicio

Desde la raíz del proyecto, ejecutar este bloque completo. Solo lee evidencias y calcula una referencia numérica pequeña; no usa Hadoop ni modifica archivos.

```bash
python3 - <<'PY'
from pathlib import Path
from decimal import Decimal, localcontext
import re

ref = Path('resultados/ejecucion_20261103_200113')
archivos = [p for p in ref.rglob('*') if p.is_file()]
assert len(archivos) == 18
assert len(list((ref / 'distbbp').glob('*.txt'))) == 14
raw = (ref / 'pi_1_16.hex').read_bytes()
hex_guardado = raw.hex().upper()
assert len(raw) == 8
assert hex_guardado == '243F6A8885A308D3'
print('Archivos:', len(archivos), '| Bytes BBP:', len(raw))

bbp = (ref / 'bbp.log').read_text()
dist = (ref / 'distbbp.log').read_text()
bloques = []
for offset, size in re.findall(r'Map #\d+: workload=\d+, offset=(\d+), size=(\d+)', bbp):
    offset, size = int(offset), int(size)
    bloque = hex_guardado[offset:offset + size]
    assert len(bloque) == size
    bloques.append((offset, bloque))
assert bloques == [(0, '243F6A8885A3'), (12, '08D3')]
assert ''.join(b for _, b in sorted(bloques)) == hex_guardado
print('Bloques (offset, hex):', bloques)

for nombre, log, esperado in [('BBP', bbp, (2, 1, 1)),
                               ('DistBBP', dist, (28, 0, 14))]:
    maps = len(re.findall(r'Starting task: attempt_\S+_m_\d+_\d+', log))
    reduces = len(re.findall(r'Starting task: attempt_\S+_r_\d+_\d+', log))
    splits = log.count('number of splits:2')
    assert (maps, reduces, splits) == esperado
    print(nombre, '| Maps:', maps, '| Reduce:', reduces, '| trabajos con 2 splits:', splits)

with localcontext() as ctx:
    ctx.prec = 100
    def arctan_inverso(q):
        x = Decimal(1) / q
        potencia = x
        suma = Decimal(0)
        for n in range(200):
            suma += potencia / (2 * n + 1)
            potencia *= -x * x
        return suma

    pi = 16 * arctan_inverso(5) - 4 * arctan_inverso(239)
    fraccion = pi - int(pi)
    hex_machin = ''
    for _ in range(16):
        fraccion *= 16
        digito = int(fraccion)
        hex_machin += '0123456789ABCDEF'[digito]
        fraccion -= digito
    decimal_16 = format(pi, 'f')[:18]  # 3. y 16 cifras; sin redondear
    assert hex_machin == hex_guardado
    assert decimal_16 == '3.1415926535897932'
    assert 'Pi=' + decimal_16 in (ref / 'pi.txt').read_text().replace(' ', '')
    print('Machin hexadecimal:', hex_machin)
    print('Machin decimal:', decimal_16)

assert dist.count('sleep(10s)') == 14
assert '140972ms (=2:20.972)' in dist
assert '574E69A458FF 2 (12 hex digits)' in dist
print('DistBBP: 14 esperas de 10 s; bloque desde posición hexadecimal', 1000 // 4 + 1)
print('Comprobaciones completadas.')
PY
```

Salida esperada, comprobada durante esta revisión:

```text
Archivos: 18 | Bytes BBP: 8
Bloques (offset, hex): [(0, '243F6A8885A3'), (12, '08D3')]
BBP | Maps: 2 | Reduce: 1 | trabajos con 2 splits: 1
DistBBP | Maps: 28 | Reduce: 0 | trabajos con 2 splits: 14
Machin hexadecimal: 243F6A8885A308D3
Machin decimal: 3.1415926535897932
DistBBP: 14 esperas de 10 s; bloque desde posición hexadecimal 251
Comprobaciones completadas.
```

## Interpretación

Los 18 archivos son dos logs, un texto BBP, un binario BBP y 14 sumatorias DistSum. Ocho bytes representan 16 dígitos hexadecimales. Los Maps BBP calculan bloques de 12 y 4 dígitos porque el reparto estima carga aritmética; Shuffle/Sort ordena por desplazamiento y el reducer concatena.

DistBBP tiene 14 sumatorias y `nJobs=1` por sumatoria. Dos partes MapSide por trabajo dan 28 Maps. `nThreads=2` configura al coordinador y no garantiza dos tareas simultáneas. El coordinador combina las partes y las sumatorias; no hubo tareas Reduce. Tras omitir 1000 bits, equivalentes a 250 dígitos hexadecimales, comienza en el dígito 251.

La serie alternante de arctangente tiene error de truncamiento menor que el primer término omitido. Con 200 términos, el de `1/5` es menor que `5^-401/401`; el redondeo de Decimal a 100 cifras también deja un margen amplio respecto a las 16 cifras hexadecimales comprobadas. Esto aporta una comprobación numérica independiente del prefijo y no sustituye una prueba formal de todo el programa.

Tres frases posibles para el equipo:

1. «Las evidencias y la comprobación de Machin coinciden en el prefijo `243F6A8885A308D3`; DistBBP guardó el bloque lejano `574E69A458FF`».
2. «Los tiempos 1.262 s y 140.972 s corresponden a cargas e intervalos distintos y no permiten concluir superioridad de un algoritmo».
3. «La práctica demuestra la división y combinación de tareas en LocalJobRunner, sin medir escalabilidad multinodo».
