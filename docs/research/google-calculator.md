# Calculadora de Google — Referencia de Código Interno y Arquitectura

## Descripción General

La calculadora de Google es una herramienta integrada en Google Search que aparece como widget interactivo cuando el usuario busca expresiones matemáticas o la palabra "calculator". A diferencia de las calculadoras físicas de ejecución inmediata, Google usa un **modelo de entrada por expresión (formula calculator)** con evaluación que respeta el orden de operaciones estándar (PEMDAS/BODMAS).

Es un ejemplo canónico de calculadora **declarativa**: el usuario escribe QUÉ quiere calcular, no CÓMO hacerlo paso a paso.

## Modelo de Entrada: Infix Notation con Precedencia

```
Entrada: 2 + 3 × 4
Resultado: 14  (NOT 20)

Razón: La multiplicación tiene mayor precedencia que la suma.
Se evalúa como 2 + (3 × 4) = 2 + 12 = 14
```

### Contraste con calculadoras básicas (como la Casio HL-820LV)

| Aspecto | Casio HL-820LV | Google Calculator |
|---------|---------------|-------------------|
| Modelo | Imperative (chain) | Declarative (formula) |
| Precedencia | No — izquierda a derecha | Sí — PEMDAS completo |
| Paréntesis | No soportados | Soportados y anidables |
| Display | Solo resultado | Expresión completa + resultado |
| Evaluación | En cada operador | Solo al presionar `=` |

## Arquitectura Interna

### Pipeline de Evaluación

```
┌──────────┐    ┌───────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│  Input   │───►│  Lexer /  │───►│  Parser  │───►│ Evaluator  │───►│  Output  │
│ (string) │    │ Tokenizer │    │  (AST)   │    │ (traverse) │    │ (number) │
└──────────┘    └───────────┘    └──────────┘    └────────────┘    └──────────┘
```

### Fase 1: Tokenización (Lexer)

El lexer convierte la cadena de entrada en una secuencia de tokens tipados.

#### Tipos de Token

```
NUMBER      → enteros y decimales: 42, 3.14, .5, 0.001
OPERATOR    → +, -, ×, ÷, ^  (binarios)
UNARY_OP    → - (negación, cuando aparece al inicio o después de operador/paréntesis)
FUNCTION    → sin, cos, tan, log, ln, sqrt, abs, etc.
LPAREN      → (
RPAREN      → )
COMMA       → , (separador de argumentos)
CONSTANT    → π, e
```

#### Ejemplo de tokenización

```
Input:  "2 + sin(3.14) × -4"

Tokens: [
  { type: NUMBER,   value: 2 },
  { type: OPERATOR, value: '+' },
  { type: FUNCTION, value: 'sin' },
  { type: LPAREN },
  { type: NUMBER,   value: 3.14 },
  { type: RPAREN },
  { type: OPERATOR, value: '×' },
  { type: UNARY_OP, value: '-' },
  { type: NUMBER,   value: 4 },
]
```

#### Desafíos del Lexer

- **Signo negativo vs resta**: `-` es unario si aparece al inicio, después de `(`, o después de otro operador
- **Multiplicación implícita**: `2π` → `2 × π`, `3(4+5)` → `3 × (4+5)`
- **Funciones**: Identificar nombres como `sin`, `cos`, `log` como tokens de función

### Fase 2: Parsing — Shunting Yard Algorithm

Google usa internamente una variante del **algoritmo Shunting Yard** de Dijkstra (1961) para convertir la expresión infix a un AST o a Reverse Polish Notation (RPN) para evaluación.

#### Tabla de Precedencia

| Precedencia | Operadores | Asociatividad |
|-------------|-----------|---------------|
| 1 (más baja) | `+`, `-` | Izquierda |
| 2 | `×`, `÷` | Izquierda |
| 3 | Negación unaria `-` | Derecha |
| 4 | `^` (potencia) | Derecha |
| 5 (más alta) | Funciones (`sin`, `cos`, etc.) | — |

#### Pseudocódigo del Shunting Yard

```
input: lista de tokens
output: cola de salida (RPN) o AST

operator_stack = []
output_queue = []

for each token:
    if token is NUMBER or CONSTANT:
        push to output_queue
    
    if token is FUNCTION:
        push to operator_stack
    
    if token is OPERATOR (o1):
        while (top of stack is operator o2
               AND o2 is not LPAREN
               AND (o2 has greater precedence than o1
                    OR (same precedence AND o1 is left-associative))):
            pop o2 from stack → output_queue
        push o1 to operator_stack
    
    if token is LPAREN:
        push to operator_stack
    
    if token is RPAREN:
        while top of stack is not LPAREN:
            pop from stack → output_queue
        pop LPAREN (discard)
        if top of stack is FUNCTION:
            pop function → output_queue

// After all tokens processed:
while operator_stack is not empty:
    pop → output_queue
```

#### Ejemplo paso a paso

```
Input tokens: 3 + 4 × 2 ÷ ( 1 - 5 ) ^ 2

Paso a paso:
Token  │ Output Queue          │ Operator Stack    │ Notas
───────┼───────────────────────┼───────────────────┼──────────────────
3      │ 3                     │                   │
+      │ 3                     │ +                 │
4      │ 3 4                   │ +                 │
×      │ 3 4                   │ × +               │ × > +, push
2      │ 3 4 2                 │ × +               │
÷      │ 3 4 2 ×              │ ÷ +               │ ÷ = ×, pop ×
(      │ 3 4 2 ×              │ ( ÷ +             │
1      │ 3 4 2 × 1            │ ( ÷ +             │
-      │ 3 4 2 × 1            │ - ( ÷ +           │
5      │ 3 4 2 × 1 5          │ - ( ÷ +           │
)      │ 3 4 2 × 1 5 -        │ ÷ +               │ pop until (
^      │ 3 4 2 × 1 5 -        │ ^ ÷ +             │ ^ > ÷, push
2      │ 3 4 2 × 1 5 - 2      │ ^ ÷ +             │
END    │ 3 4 2 × 1 5 - 2 ^ ÷ +│                   │ flush stack

RPN: 3 4 2 × 1 5 - 2 ^ ÷ +
Resultado: 3 + ((4×2) ÷ ((1-5)^2)) = 3 + (8 ÷ 16) = 3.5
```

### Fase 3: Evaluación

Una vez en RPN o AST, la evaluación es directa:

#### Evaluación de RPN (stack-based)

```
evaluation_stack = []

for each token in RPN output:
    if token is NUMBER:
        push to evaluation_stack
    
    if token is BINARY_OPERATOR:
        right = pop()
        left = pop()
        result = apply(operator, left, right)
        push(result)
    
    if token is UNARY_OPERATOR or FUNCTION:
        operand = pop()
        result = apply(function, operand)
        push(result)

final_result = pop()  // último valor en el stack
```

#### Evaluación por AST (tree walking)

```
function evaluate(node):
    if node is NumberLiteral:
        return node.value
    
    if node is BinaryExpression:
        left = evaluate(node.left)
        right = evaluate(node.right)
        return applyOp(node.operator, left, right)
    
    if node is UnaryExpression:
        operand = evaluate(node.operand)
        return applyUnary(node.operator, operand)
    
    if node is FunctionCall:
        arg = evaluate(node.argument)
        return applyFunction(node.name, arg)
```

### Alternativa: Recursive Descent Parser

Una implementación alternativa (usada en V8/Chrome, GCC, Roslyn) es el **Recursive Descent Parser**, donde cada nivel de precedencia se convierte en una función:

```
function expression():
    return addition()

function addition():
    left = multiplication()
    while current_token is '+' or '-':
        op = consume_token()
        right = multiplication()
        left = BinaryNode(op, left, right)
    return left

function multiplication():
    left = unary()
    while current_token is '×' or '÷':
        op = consume_token()
        right = unary()
        left = BinaryNode(op, left, right)
    return left

function unary():
    if current_token is '-':
        consume_token()
        operand = unary()  // recursivo para !!x o --x
        return UnaryNode('-', operand)
    return primary()

function primary():
    if current_token is NUMBER:
        return NumberNode(consume_token().value)
    if current_token is FUNCTION:
        name = consume_token()
        expect('(')
        arg = expression()
        expect(')')
        return FunctionNode(name, arg)
    if current_token is '(':
        consume_token()
        expr = expression()
        expect(')')
        return GroupNode(expr)
    if current_token is CONSTANT:
        return NumberNode(constant_value(consume_token()))
    error("Expresión inesperada")
```

**Ventajas del recursive descent:**
- Código simple y legible
- Excelente manejo de errores (se sabe exactamente dónde falló)
- Fácil de extender con nuevos operadores
- O(n) — lineal en el tamaño de la entrada
- No requiere herramientas externas (yacc, bison, ANTLR)

## Funcionalidades de la Calculadora de Google

### Operadores Soportados

| Operador | Símbolo | Precedencia |
|----------|---------|-------------|
| Suma | `+` | 1 |
| Resta | `-` | 1 |
| Multiplicación | `×` | 2 |
| División | `÷` | 2 |
| Módulo | `mod` | 2 |
| Potencia | `^` | 3 (right-assoc) |
| Factorial | `!` | 4 (postfix) |

### Funciones Soportadas

| Función | Descripción |
|---------|-------------|
| `sin`, `cos`, `tan` | Trigonométricas |
| `arcsin`, `arccos`, `arctan` | Trigonométricas inversas |
| `ln` | Logaritmo natural |
| `log` | Logaritmo base 10 |
| `sqrt` (o `√`) | Raíz cuadrada |
| `abs` | Valor absoluto |
| `exp` | e^x |

### Constantes

| Constante | Valor |
|-----------|-------|
| `π` (pi) | 3.14159265358... |
| `e` | 2.71828182845... |

### Modos de Ángulo

- Radianes (default)
- Grados (toggle en la UI)

## Manejo de Errores

### Errores Detectables en Parsing

| Error | Ejemplo | Mensaje |
|-------|---------|---------|
| Paréntesis sin cerrar | `(2 + 3` | "Missing )" |
| Paréntesis extra | `2 + 3)` | "Unexpected )" |
| Operadores consecutivos | `2 + × 3` | "Unexpected operator" |
| Expresión vacía | ` ` | "No expression" |
| Función sin argumento | `sin()` | "Expected expression" |

### Errores Detectables en Evaluación

| Error | Ejemplo | Resultado |
|-------|---------|-----------|
| División por cero | `1 ÷ 0` | `Infinity` o Error |
| √ de negativo | `√(-1)` | `NaN` o Error |
| Overflow | `10^999` | `Infinity` |
| Dominio inválido | `arcsin(2)` | `NaN` o Error |

## Modelo de Estado de la UI

```
State = {
    expression: string,      // "2 + 3 × "
    displayValue: string,    // Lo que se muestra arriba (expresión)
    result: string | null,   // Preview del resultado (evaluación en tiempo real)
    cursor: number,          // Posición del cursor en la expresión
    angleMode: 'rad' | 'deg',
    memory: number,
    history: Expression[],
    error: string | null
}
```

### Evaluación en Tiempo Real (Live Preview)

Google muestra el resultado parcial mientras el usuario escribe. Esto requiere:

1. **Parsing tolerante**: El parser debe manejar expresiones incompletas sin crashear
2. **Cierre automático de paréntesis**: Si faltan `)`, se asumen al final
3. **Trailing operators ignorados**: `2 + 3 +` evalúa como `2 + 3`
4. **Debounce**: No reevaluar en cada keystroke sino con un pequeño delay

## Precisión Numérica

### IEEE 754 Double Precision

Google Calculator usa punto flotante de 64 bits (como JavaScript `Number`):

- Precisión: ~15-17 dígitos significativos
- Rango: ±5.0 × 10^−324 a ±1.7976931348623157 × 10^308
- Problemas conocidos: `0.1 + 0.2 ≠ 0.3` exactamente

### Estrategias de Mitigación

1. **Redondeo para display**: Mostrar máximo 10-12 dígitos significativos
2. **Comparación con epsilon**: Para determinar si un resultado es "entero"
3. **Formato inteligente**: `0.30000000000000004` → `0.3`

## Implicaciones para Calculatrix

### Lo que adoptamos del modelo Google:

1. **Evaluación con precedencia de operadores** — PEMDAS completo
2. **Soporte de paréntesis** — Aunque el layout visual sea minimalista
3. **Arquitectura Tokenizer → Parser → Evaluator** — Separación clara de concerns
4. **Recursive Descent Parser** — Simple, robusto, extensible (preferido sobre Shunting Yard para mantenibilidad)
5. **Live preview del resultado** — UX moderna que diferencia de calculadoras físicas
6. **Manejo graceful de errores** — No crashes, mensajes útiles
7. **Precisión con IEEE 754** — Con redondeo inteligente para display

### Lo que NO adoptamos:

1. **Funciones científicas completas** — La Casio HL-820LV no las tiene; mantenemos minimalismo
2. **Graficación** — Fuera de scope para una calculadora de bolsillo
3. **Historial persistente** — Mantenemos simplicidad
4. **Input por texto libre** — Usamos botones como la Casio

### Híbrido resultante: "Casio skin, Google brain"

```
┌─────────────────────────────────────────────┐
│  UI/Layout: Casio HL-820LV                  │
│  • 4 columnas de botones                    │
│  • Estética minimalista                     │
│  • Botones físicos familiares               │
│                                             │
│  Motor interno: Google-style                │
│  • Construye expresión como string          │
│  • Tokeniza → Parsea → Evalúa              │
│  • Respeta orden de operaciones             │
│  • Live preview del resultado               │
│  • Error handling robusto                   │
└─────────────────────────────────────────────┘
```

## Referencias

- Dijkstra, E. (1961). "Algol 60 translation: An Algol 60 translator for the X1" — Origen del Shunting Yard Algorithm
- Nystrom, R. "Crafting Interpreters", Chapter 6: Parsing Expressions — Recursive Descent
- Wikipedia: Shunting Yard Algorithm — Pseudocódigo y ejemplos detallados
- Wikipedia: Calculator Input Methods — Taxonomía de métodos de entrada
- Google Support: "Manage calculator, unit converter & color codes" — Funcionalidades oficiales
- IEEE 754-2019: Standard for Floating-Point Arithmetic
