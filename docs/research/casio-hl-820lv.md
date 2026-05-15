# Casio HL-820LV — Referencia de Layout, Botones y Funcionalidades

## Descripción General

La Casio HL-820LV es una calculadora de bolsillo básica de 8 dígitos, representativa del diseño clásico de calculadoras compactas de los años 2000-2010. Es una calculadora de "ejecución inmediata" (chain calculation / AES — Algebraic Entry System), donde cada operación binaria se ejecuta al presionar el siguiente operador o la tecla `=`.

**No usa orden de operaciones** — evalúa estrictamente de izquierda a derecha.

## Especificaciones Técnicas

| Propiedad | Valor |
|-----------|-------|
| Dígitos del display | 8 |
| Tipo de display | LCD de 7 segmentos |
| Alimentación | Dual: Solar + Batería (LR1130 × 1) |
| Dimensiones | ~100 × 62 × 9 mm |
| Peso | ~45g (con batería) |
| Carcasa | Tipo wallet/cartera rígida plegable |

## Layout de Botones

### Distribución Física (4 columnas × 6 filas aprox.)

```
┌─────────────────────────────────────────┐
│            [ DISPLAY 8 DÍGITOS ]        │
│  Indicadores: M  -  E                  │
├─────────────────────────────────────────┤
│                                         │
│   [MC]    [MR]    [M-]    [M+]         │
│                                         │
│   [OFF]   [√]     [%]     [÷]          │
│                                         │
│   [7]     [8]     [9]     [×]          │
│                                         │
│   [4]     [5]     [6]     [-]          │
│                                         │
│   [1]     [2]     [3]     [+]          │
│                                         │
│   [0]     [.]     [+/-]   [=]          │
│                                         │
│               [AC]  [C]                 │
│                                         │
└─────────────────────────────────────────┘
```

### Nota sobre variantes
Algunas variantes tienen `AC/C` como un solo botón de doble función, o `ON/AC` combinado. El layout exacto puede variar ligeramente entre regiones (HL-820LV-BK, HL-820LV-WE, etc.), pero las funcionalidades son idénticas.

## Catálogo Completo de Teclas

### Teclas Numéricas (10)

| Tecla | Función |
|-------|---------|
| `0` - `9` | Entrada de dígitos |
| `.` | Punto decimal |

### Teclas de Operación (4)

| Tecla | Función | Comportamiento |
|-------|---------|---------------|
| `+` | Suma | Ejecuta operación pendiente, establece suma como próxima operación |
| `-` | Resta | Ejecuta operación pendiente, establece resta como próxima operación |
| `×` | Multiplicación | Ejecuta operación pendiente, establece multiplicación |
| `÷` | División | Ejecuta operación pendiente, establece división |

### Tecla de Resultado

| Tecla | Función | Comportamiento |
|-------|---------|---------------|
| `=` | Igual / Ejecutar | Ejecuta la operación pendiente y muestra resultado. Presiones repetidas repiten la última operación con el último operando |

### Teclas de Memoria (4)

| Tecla | Función | Comportamiento |
|-------|---------|---------------|
| `MC` | Memory Clear | Borra el contenido de la memoria (M → 0) |
| `MR` | Memory Recall | Muestra el valor almacenado en memoria |
| `M-` | Memory Subtract | Resta el valor mostrado del valor en memoria |
| `M+` | Memory Add | Suma el valor mostrado al valor en memoria |

### Teclas Especiales

| Tecla | Función | Comportamiento |
|-------|---------|---------------|
| `√` | Raíz cuadrada | Calcula √ del valor mostrado inmediatamente (operación unaria postfija) |
| `%` | Porcentaje | Contexto-dependiente (ver sección Porcentaje) |
| `+/-` | Cambio de signo | Invierte el signo del valor mostrado |

### Teclas de Control

| Tecla | Función | Comportamiento |
|-------|---------|---------------|
| `AC` | All Clear | Resetea todo: display, operación pendiente, acumulador. NO borra memoria |
| `C` | Clear Entry | Borra solo la entrada actual (último número ingresado), mantiene la operación |
| `OFF` | Apagar | Apaga la calculadora (en modelos solo-batería; en solar, puede ser ON/OFF) |

## Indicadores del Display

| Indicador | Significado |
|-----------|-------------|
| `M` | Hay un valor almacenado en memoria (≠ 0) |
| `-` | El valor mostrado es negativo |
| `E` | Error (overflow, división por cero, √ de negativo) |

## Comportamiento Funcional Detallado

### Modelo de Ejecución: Immediate Execution (Chain Calculation)

La HL-820LV usa el modelo AES (Algebraic Entry System) **sin jerarquía de operadores**:

```
Entrada: 2 + 3 × 4 =
Resultado: 20  (NO 14)

Razón: (2 + 3) = 5, luego 5 × 4 = 20
Cada operador ejecuta la operación anterior inmediatamente.
```

### Regla de Evaluación

1. El usuario ingresa un número → se muestra en display
2. El usuario presiona un operador (+, -, ×, ÷) → se ejecuta cualquier operación pendiente, el resultado se muestra, y el nuevo operador queda pendiente
3. El usuario presiona `=` → se ejecuta la operación pendiente con el número actual

### Constante de Repetición (= repetido)

```
5 + 3 = → 8
      = → 11  (8 + 3)
      = → 14  (11 + 3)
```

El último operando y operador se "recuerdan" para repeticiones con `=`.

### Comportamiento del Porcentaje (%)

El `%` es la tecla más compleja. Su comportamiento depende del contexto:

| Secuencia | Interpretación | Resultado |
|-----------|---------------|-----------|
| `200 × 10 %` | 10% de 200 | 20 |
| `200 + 10 %` | 200 + 10% de 200 | 220 |
| `200 - 10 %` | 200 - 10% de 200 | 180 |
| `200 ÷ 10 %` | (200 ÷ 10) × 100 | 2000 (markup) |

### Raíz Cuadrada (√)

- Operación unaria inmediata (postfija al display)
- `9 √` → 3
- √ de negativo → Error (`E`)
- Puede encadenarse: `81 √ √` → 3

### Condiciones de Error

| Condición | Display |
|-----------|---------|
| Resultado > 99,999,999 | `E` (overflow) |
| Resultado < -99,999,999 | `E` (underflow) |
| División por 0 | `E` |
| √ de número negativo | `E` |

**Recuperación de error:** Presionar `C` o `AC` para limpiar el estado de error.

### Auto Power-Off

La calculadora se apaga automáticamente después de ~7 minutos de inactividad (en modo batería).

## Ergonomía y Diseño Visual

### Diferenciación de Teclas por Color

| Grupo | Color típico |
|-------|-------------|
| Dígitos (0-9, .) | Gris claro / blanco |
| Operadores (+, -, ×, ÷) | Gris oscuro |
| Igual (=) | Gris oscuro / azul |
| AC / C | Rojo / naranja |
| Memoria (MC, MR, M-, M+) | Gris medio |
| Funciones (√, %, +/-) | Gris medio |

### Características Táctiles

- Teclas planas tipo membrana (ligeramente elevadas)
- Tamaño de tecla numérica: ~9mm × 7mm
- Separación entre teclas: ~2mm
- Textura mate antideslizante en la carcasa

## Implicaciones para Calculatrix

### Lo que adoptamos de la HL-820LV:

1. **Layout de 4 columnas** — Estándar de la industria, ergonómico
2. **Separación visual de grupos funcionales** — Color/tamaño distingue categorías
3. **Tecla `=` prominente** — Posición inferior-derecha, fácil acceso con pulgar
4. **Minimalismo funcional** — Solo las operaciones esenciales, sin clutter
5. **Display de 8 dígitos** — Limitación deliberada que define el carácter del producto
6. **Indicadores de estado** — M, -, E como feedback mínimo pero suficiente
7. **Dual clear (AC/C)** — Dos niveles de "deshacer" son intuitivos

### Lo que NO adoptamos:

1. **Ejecución inmediata sin precedencia** — Usaremos el motor de Google (con orden de operaciones)
2. **Sin paréntesis** — Nuestro motor los soportará, aunque el layout no tenga botón visible
3. **Comportamiento % dependiente de contexto** — Lo simplificaremos
4. **Auto power-off** — No aplica en software

## Referencias

- Casio Official Product Page: HL-820LV series
- Wikipedia: Calculator Input Methods — Immediate Execution / AES
- Manual de usuario Casio HL-820LV (versión multi-idioma incluida en packaging)
