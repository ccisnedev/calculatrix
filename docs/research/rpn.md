# RPN — Reverse Polish Notation

## Resumen

Investigación sobre la notación polaca inversa (RPN), cómo la gestiona la HP-50g
mediante RPL, y alternativas modernas de implementación para Calculatrix Etapa 2.

---

## 1. Fundamentos de RPN

### 1.1 Definición

RPN (Reverse Polish Notation) es una notación matemática donde los operadores
siguen a sus operandos, eliminando la necesidad de paréntesis y reglas de
precedencia.

| Infija            | RPN              |
|-------------------|------------------|
| `3 + 4`          | `3 4 +`          |
| `(3 + 4) × 5`   | `3 4 + 5 ×`     |
| `3 + 4 × 5`     | `3 4 5 × +`     |
| `(1+2)×(3+4)`   | `1 2 + 3 4 + ×` |

### 1.2 Cómo funciona el stack

1. Leer token de izquierda a derecha
2. Si es número → **push** al stack
3. Si es operador → **pop** n operandos, operar, **push** resultado

```
Entrada: 3 4 + 5 ×

Stack:  []
→ 3    [3]
→ 4    [3, 4]
→ +    [7]         ← pop 3,4; push 3+4
→ 5    [7, 5]
→ ×    [35]        ← pop 7,5; push 7×5
```

### 1.3 Ventajas sobre notación infija

- **Sin paréntesis**: la precedencia está implícita en el orden de entrada
- **Menos keystrokes**: estudios (Kasprzyk 1979, Agate 1980) demuestran ~20% menos pulsaciones
- **Menos errores**: los usuarios cometen menos equivocaciones en cálculos complejos
- **Evaluación lineal**: se procesa de izquierda a derecha, sin backtracking
- **Implementación simple**: solo requiere un stack, sin parser de precedencia

### 1.4 Historia

| Año  | Hito |
|------|------|
| 1924 | Jan Łukasiewicz inventa notación polaca (prefija) |
| 1941 | Konrad Zuse usa postfija en Z3 (2 operandos → operador) |
| 1957 | Charles Hamblin propone RPN formalmente |
| 1963 | Friden EC-130: primera calculadora con RPN y stack de 4 niveles |
| 1972 | HP-35: primera calculadora científica portátil, 4-level RPN |
| 1986 | HP introduce RPL: stack dinámico ilimitado |
| 2006 | HP 50g: última calculadora RPL de HP |
| 2013 | HP Prime: "Advanced RPN" con stack de 128 niveles |

---

## 2. El stack clásico de 4 niveles (HP-35 a HP-42S)

### 2.1 Arquitectura

```
┌─────┐
│  T  │  ← Top (nivel 4)
├─────┤
│  Z  │  ← nivel 3
├─────┤
│  Y  │  ← nivel 2
├─────┤
│  X  │  ← nivel 1 (display / resultado)
└─────┘
```

### 2.2 Comportamiento del ENTER

La tecla **ENTER↑** copia X → Y, empujando Y → Z → T. El valor anterior de T
se pierde (overflow silencioso).

### 2.3 Reglas especiales

- **Stack lift automático**: tras ingresar un número, el siguiente dígito
  levanta el stack automáticamente
- **Stack lift disable temporal**: después de ENTER, el siguiente número
  reemplaza X sin levantar (evita duplicar)
- **T-duplication on drop**: cuando un operador consume valores y el stack baja,
  T se duplica (T → T, Z) para facilitar cálculos repetitivos

### 2.4 Comandos de manipulación

| Comando  | Efecto |
|----------|--------|
| ENTER    | Duplica X → Y, levanta stack |
| x↔y     | Intercambia X ↔ Y (SWAP) |
| R↓       | Rota stack hacia abajo: X→T, T→Z, Z→Y, Y→X |
| R↑       | Rota stack hacia arriba |
| LASTx    | Recupera último X antes de operación |

### 2.5 Limitaciones

- Solo 4 valores simultáneos → expresiones con >4 niveles de anidamiento
  requieren trucos con STO/RCL
- Overflow silencioso: se pierden datos sin aviso
- T-duplication confunde a usuarios nuevos

---

## 3. RPL en la HP-50g — Stack dinámico ilimitado

### 3.1 Arquitectura

La HP-50g usa **RPL** (Reverse Polish Lisp), un sistema operativo y lenguaje
que reemplaza el stack fijo de 4 niveles con un **stack dinámico** limitado
solo por la RAM disponible (512 KB RAM + 2 MB flash).

```
┌─────────┐
│ Nivel n │  ← sin límite superior
├─────────┤
│   ...   │
├─────────┤
│ Nivel 3 │
├─────────┤
│ Nivel 2 │
├─────────┤
│ Nivel 1 │  ← "bottom" del stack visible
└─────────┘
```

### 3.2 Diferencias clave con RPN clásica

| Aspecto | RPN clásica (HP-42S) | RPL (HP-50g) |
|---------|---------------------|--------------|
| Tamaño stack | 4 niveles fijos | Ilimitado (solo RAM) |
| Overflow | Silencioso (se pierde T) | Error "Insufficient Memory" |
| Underflow | T se duplica hacia abajo | Error "Too Few Arguments" |
| ENTER | Duplica X→Y + stack lift disable | No duplica, solo separa entradas |
| Tipos en stack | Solo números reales | Cualquier objeto: números, strings, listas, matrices, programas, gráficos |
| Programabilidad | FOCAL keystroke | RPL (Forth + Lisp) |

### 3.3 Operaciones de stack en HP-50g

| Comando | Stack antes | Stack después | Descripción |
|---------|-------------|---------------|-------------|
| DUP     | ...a        | ...a a        | Duplicar nivel 1 |
| DUP2    | ...a b      | ...a b a b    | Duplicar niveles 1-2 |
| DUPN    | ...n        | ...×n         | Duplicar n niveles |
| DROP    | ...a        | ...           | Eliminar nivel 1 |
| DROP2   | ...a b      | ...           | Eliminar niveles 1-2 |
| DROPN   | ...n        | ...           | Eliminar n niveles |
| SWAP    | ...a b      | ...b a        | Intercambiar 1↔2 |
| ROT     | ...a b c    | ...b c a      | Rotar 3 niveles |
| UNROT   | ...a b c    | ...c a b      | Rotar inverso |
| ROLL    | ...n        | ...           | Rotar n niveles |
| ROLLD   | ...n        | ...           | Rotar n niveles inverso |
| PICK    | ...n        | ...copia(n)   | Copiar nivel n al tope |
| OVER    | ...a b      | ...a b a      | Copiar nivel 2 al tope |
| DEPTH   | ...         | ...n          | Número de elementos en stack |
| CLEAR   | ...         | (vacío)       | Vaciar todo el stack |

### 3.4 RPL como lenguaje

RPL combina:
- **RPN** para cálculo interactivo
- **Forth** para programación concatenativa (composición por stack)
- **Lisp** para manipulación de listas y evaluación perezosa

```rpl
« DUP * »              @ Programa: elevar al cuadrado
« 1 10 FOR I I + NEXT » @ Sumar 1..10 al valor en stack
« IF DUP 0 < THEN NEG END » @ Valor absoluto
```

### 3.5 Objetos tipados en stack

El stack RPL puede contener cualquier tipo:

- Números reales y complejos
- Strings
- Listas `{ 1 2 3 }`
- Vectores y matrices `[[ 1 2 ][ 3 4 ]]`
- Expresiones algebraicas `'X^2+1'`
- Programas `« ... »`
- Nombres `'variable'`
- Unidades `25_m/s`

---

## 4. Alternativas y mejoras modernas al RPN

### 4.1 Entry RPN (HP post-2006)

Variante donde ENTER **no** duplica el valor (comportamiento RPL) pero el stack
sigue siendo fijo. Usado en HP-35s y modelos nuevos no-RPL.
- Elimina la confusión de duplicación de ENTER
- Mantiene el stack fijo de 4 niveles

### 4.2 Advanced RPN (HP Prime, 2013)

- Stack de **128 niveles** (fijo, no dinámico)
- Comportamiento Entry RPN (ENTER no duplica)
- Overflow silencioso como RPN clásica (se pierde el fondo)
- No soporta objetos tipados como RPL

### 4.3 Stack dinámico + tipos (RPL / newRPL / DB48X)

- **newRPL**: reimplementación open-source de RPL para HP-50g y SwissMicros DM42
  - Más rápido que RPL original (compilado nativo ARM)
  - Misma semántica de stack ilimitado
- **DB48X**: otra reimplementación para SwissMicros DM42
  - Extiende RPL con Unicode, tipos adicionales
  - Presentado en FOSDEM 2023

### 4.4 Free42 dynamic stack

Desde v3 (2021), el emulador Free42 (clon de HP-42S) soporta stack dinámico
ilimitado como opción, manteniendo la interfaz RPN clásica. Mejor de ambos
mundos: UX de HP-42S + profundidad ilimitada.

### 4.5 Stacks de 8 niveles (WP 34S/43S)

Las calculadoras comunitarias WP 34S (2011) y WP 43S ofrecen stack
seleccionable de 4 u 8 niveles con soporte de tipos (reales, complejos,
enteros, strings, matrices). Compromiso entre simplicidad y capacidad.

### 4.6 Concatenative programming (Forth, Factor, Joy)

Lenguajes que extienden el concepto de RPN a programación completa:

| Lenguaje | Particularidad |
|----------|---------------|
| **Forth** | Stack de datos + stack de retorno. Palabras como funciones. Muy bajo nivel. |
| **Factor** | Stack typing moderno, garbage collection, quotations como closures |
| **Joy** | Puramente funcional y concatenativo. Sin variables nombradas. |
| **PostScript** | Stack para rendering de páginas. Operadores gráficos. |
| **dc** (Unix) | Calculadora RPN de precisión arbitraria |

---

## 5. Análisis comparativo para Calculatrix

### 5.1 Opciones de diseño

| Opción | Ventajas | Desventajas |
|--------|----------|-------------|
| **A) Stack fijo 4 niveles** | Simple de implementar y visualizar. Nostalgia HP-35. | Limitante para expresiones complejas. Requiere trucos STO/RCL. |
| **B) Stack fijo 8 niveles** | Buen compromiso. Rara vez se necesitan más. | Aún tiene overflow silencioso. |
| **C) Stack dinámico ilimitado** | Nunca pierde datos. Más potente. | Requiere scrolling en UI. Más complejidad visual. |
| **D) Híbrido: visual 4 + overflow visible** | UX de 4 niveles con indicador "+n más". No se pierden datos. | Implementación UI más compleja. |

### 5.2 Recomendación para Etapa 2

**Opción D: Stack dinámico con visualización de 4 niveles y overflow visible.**

Razones:
1. El stack interno es ilimitado (como RPL) → nunca se pierde información
2. La UI muestra los 4 niveles superiores (familiar para usuarios de HP)
3. Un indicador muestra cuántos niveles adicionales existen debajo
4. Scroll o gesto para ver niveles profundos
5. Error explícito en underflow (como RPL, nunca duplicar silenciosamente)

### 5.3 Operaciones a implementar

**Mínimo viable:**
- ENTER (separador, sin duplicación — estilo Entry RPN)
- SWAP (x↔y)
- DROP
- DUP
- ROT
- CLEAR
- DEPTH
- UNDO (deshacer última operación — mejora sobre HP)

**Extensiones Etapa 2:**
- PICK n
- ROLL n
- OVER
- DUP2 / DROP2
- LAST (recuperar argumentos de última operación, como LASTx)
- Stack visual con drag-and-drop para reordenar

### 5.4 Mejoras sobre HP-50g

| Mejora | Justificación |
|--------|---------------|
| **UNDO infinito** | La HP-50g no tiene undo general. Nosotros podemos mantener historial de estados del stack. |
| **ENTER sin duplicación** | Evita confusión del modelo clásico. Consenso moderno (Entry RPN). |
| **Tipos visuales** | Mostrar tipo del objeto en cada nivel (número, expresión, lista). |
| **Error explícito en underflow** | Nunca duplicar T silenciosamente. Mostrar "Stack vacío". |
| **Animaciones de stack** | Visualizar push/pop/swap como transiciones para entender el flujo. |
| **Expresiones inline** | Mostrar `3 4 +` como preview de resultado antes de confirmar. |

---

## 6. Implementación del evaluador RPN

### 6.1 Estructura de datos

```
Stack = List<StackObject>

StackObject = 
  | RealNumber(value: double)
  | Expression(tokens: List<Token>)
  | Matrix(rows: List<List<double>>)
  | ...
```

### 6.2 Algoritmo de evaluación

```
function evaluate(input: Token[]):
  for token in input:
    match token:
      case Number(n):
        stack.push(RealNumber(n))
      case UnaryOp(op):
        a = stack.pop()  // error si stack vacío
        stack.push(apply(op, a))
      case BinaryOp(op):
        b = stack.pop()  // error si stack vacío
        a = stack.pop()  // error si stack vacío
        stack.push(apply(op, a, b))
      case StackOp(cmd):
        executeStackCommand(cmd)
```

### 6.3 Conversión infija → RPN (Shunting Yard)

Para soportar modo algebraico que internamente usa el mismo engine:

```
function shuntingYard(infix: Token[]) -> Token[]:
  output = Queue()
  operators = Stack()
  for token in infix:
    match token:
      case Number: output.enqueue(token)
      case Operator(op):
        while operators.peek() has higher precedence:
          output.enqueue(operators.pop())
        operators.push(op)
      case '(': operators.push(token)
      case ')':
        while operators.peek() != '(':
          output.enqueue(operators.pop())
        operators.pop()  // descartar '('
  while operators not empty:
    output.enqueue(operators.pop())
  return output
```

Esto permite que Etapa 1 (algebraica) y Etapa 2 (RPN) compartan el mismo
backend de evaluación.

---

## 7. UX del modo RPN

### 7.1 Layout de pantalla propuesto

```
┌────────────────────────────┐
│ [+3 más]                   │  ← indicador de profundidad
│                            │
│ 4:    12.5                 │
│ 3:    3.14159              │
│ 2:    42                   │
│ 1:    7.5          ←result │
├────────────────────────────┤
│ entrada: _                 │  ← línea de entrada activa
└────────────────────────────┘
```

### 7.2 Feedback visual

- Push: nuevo valor "cae" al nivel 1, otros suben con animación
- Pop: valor sale, otros bajan
- Swap: los dos valores intercambian posición con crossfade
- Error: shake en el stack + mensaje

---

## 8. Fuentes

- Wikipedia: Reverse Polish notation (2026-05-12)
- Wikipedia: HP 49/50 series (2026-05-08)
- Wikipedia: RPL programming language (2026-05-13)
- HP-35 User's Manual — "The operational stack and reverse Polish notation"
- HP 50g User's Guide (F2229AA-90006)
- Ball, J.A. (1978) "Algorithms for RPN calculators"
- Agate & Drury (1980) "Electronic calculators: which notation is the better?"
- Hoffman et al. (1994) "Calculator logic: when and why is RPN superior to algebraic?"
- Nelson, R.J. (2012) "HP RPN Evolves" — HP Solve #27
- Wickes, W.C. (1988) "RPL: A Mathematical Control Language"
- newRPL: https://newrpl.wiki.hpgcc3.org
- DB48X (FOSDEM 2023): Reviving Reverse Polish Lisp
