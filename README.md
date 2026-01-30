# Simulación de Incendio Forestal con Agentes (R)

Este proyecto implementa una simulación de incendio forestal utilizando un enfoque **Multi-Agent Based (MBA)** en R.

El modelo representa un bosque como una grilla bidimensional donde:

- Cada celda puede contener árboles, zonas secas, fuego o terreno quemado.
- Un conjunto de agentes (guardabosques) patrulla el entorno, detecta focos de incendio, limpia zonas secas y combate el fuego.

La simulación incorpora efectos climáticos, propagación estocástica del fuego y desgaste energético de los agentes.

---

##  Características principales

### Entorno

- Grilla de tamaño configurable (`n × n`)
- Estados posibles de celda:

| Estado |
|--------|
| tree |
| dry |
| fire1 |
| fire2 |
| fire3 |
| burned |
| extinguished |
| cleared |

La progresión del fuego ocurre en tres niveles (`fire1 → fire2 → fire3 → burned`).

---

### Propagación del fuego

La propagación depende de:

- Viento
- Humedad
- Temperatura
- Nivel del fuego

Reglas:

- Fuego nivel 1 y 2 solo se propaga en zonas secas.
- Fuego nivel 3 puede propagarse tanto en zonas secas como en árboles.
- Cada paso incrementa la intensidad del fuego hasta quemar completamente la celda.

El proceso es estocástico y depende de probabilidades dinámicas influenciadas por el clima.

---

### Agentes (guardabosques)

Cada agente es una clase S4 con atributos:

- Posición `(x,y)`
- Energía
- Nivel de alerta

Los agentes pueden:

- Patrullar aleatoriamente
- Moverse hacia focos de incendio dentro de su radio de detección
- Limpiar zonas secas cercanas al fuego
- Apagar incendios
- Regresar a la base para recuperar energía

La energía disminuye al:

- Limpiar terreno
- Apagar fuego (según nivel)
- Rodear zonas con alta densidad de fuego

Si la energía llega a cero, el agente muere.

---

### Comunicación

Cuando múltiples agentes coinciden en una misma celda, comparten su nivel de alerta, permitiendo coordinación emergente.

---

##  Parámetros principales

```r
n = 50                 # tamaño del bosque
n_agents = 200        # número de agentes
r_com = 5             # radio detección
clean_rad = 10        # radio limpieza
dry_prob = 0.6        # probabilidad de zonas secas
max_steps = 10        # límite de iteraciones
```

## Ejemplos resultados con 200 agentes


<img width="699" height="551" alt="Simulacion_200_100" src="https://github.com/user-attachments/assets/f7b9d00f-abb4-4702-885c-5f85255f368f" />
<img width="699" height="551" alt="Evolucion_celdas_200" src="https://github.com/user-attachments/assets/4a06c422-b65e-4838-a860-c92983dd5798" />
<img width="699" height="551" alt="Supervivencia_200" src="https://github.com/user-attachments/assets/8b6cbf26-3bb5-4b1a-8cf8-bfcf58436f01" />

