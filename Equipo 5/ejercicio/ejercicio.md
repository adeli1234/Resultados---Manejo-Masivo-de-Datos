# Mini ejercicio: auditar el cálculo de π

**Dificultad moderada · 20–30 minutos.** Objetivo: reconstruir una salida, interpretar tareas y comprobar un resultado con un método numérico distinto. Trabajar desde la raíz del proyecto con Bash y Python 3. No requiere Docker ni repetir Hadoop.

Usar únicamente `resultados/ejecucion_20261103_200113/`. No modificar evidencias.

## Actividades

1. Inventariar los archivos: justificar el total de 18 y distinguir registros, salida binaria, texto y sumatorias. Leer `pi_1_16.hex` como bytes; calcular su tamaño y convertirlo a hexadecimal. Explicar por qué no debe abrirse como texto.
2. Extraer de `bbp.log` los desplazamientos y longitudes de los Maps. Dividir el hexadecimal final según esos rangos y reconstruirlo ordenando por desplazamiento. Explicar por qué las longitudes no son iguales y cuál es la función del reducer.
3. Escribir un programa Python que cuente en los registros los inicios de tareas Map y Reduce y las líneas `number of splits:2`. Distinguir una tarea de sus múltiples mensajes de progreso/finalización. Obtener los totales para ambos programas.
4. Comprobar el prefijo BBP con la identidad de Machin:

   \[
   \pi=16\arctan(1/5)-4\arctan(1/239),\qquad
   \arctan(x)=\sum_{n=0}^{\infty}\frac{(-1)^n x^{2n+1}}{2n+1}.
   \]

   Usar `decimal.Decimal` con precisión 100 y 200 términos por serie. Convertir la parte fraccionaria a 16 dígitos hexadecimales mediante multiplicaciones sucesivas por 16; comparar con el binario guardado. Mostrar también los primeros 16 decimales mediante truncamiento. Evitar `float`, que no conserva suficiente precisión para esta comprobación.
5. Explicar por qué `distbbp 1000 2 1 m 2` produjo 14 trabajos y 28 Maps. ¿En qué posición hexadecimal comienza su bloque? ¿Dónde se combinan los resultados? Identificar la línea final y las esperas de 10 s.
6. Redactar tres frases: resultado comprobado, límite de la comparación temporal y límite del entorno. No atribuir desempeño de un clúster a esta ejecución local.

## Entregable y criterios

Entregar un programa o transcripción con conteos, bloques reconstruidos y comparación numérica; añadir las tres frases de interpretación. La respuesta debe diferenciar resultados guardados, comprobación independiente y aspectos no medidos. No es necesario generar nuevos tiempos.

[Consultar la solución](solucion.md) después de intentar el ejercicio. La comprobación de Machin valida el prefijo BBP; no prueba el bloque lejano DistBBP ni todas las posibles configuraciones de Hadoop.
