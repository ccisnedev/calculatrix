# Roadmap

> **Filosofía de versionado**: cada etapa culmina en una major release estable.
> Las versiones `X.y.z` posteriores a cada `.0` son mejoras y correcciones sobre esa base.

- **Package**: `dev.ccisne.calculatrix`
- **Framework**: Flutter (web-first para QA, luego multiplataforma)
- **Arquitectura**: MVVM (Controller extends ChangeNotifier + notifyListeners)
- **QA**: TDD + Widget tests + Integration tests (Semantics-driven)

---

## Etapa 1 — "Casio Skin, Google Brain" (0.x.x → 1.0.0)

Calculadora básica con layout inspirado en la Casio HL-820LV y motor de evaluación
con precedencia de operadores al estilo Google Calculator.

### v0.1.0 — Foundation ✅

- [x] Proyecto Flutter scaffolded (`dev.ccisne.calculatrix`)
- [x] Estructura MVVM: `lib/{models,controllers,views,widgets}`
- [x] Modelo de dominio: `Token` (number, operator, paren), `TokenType` enum
- [x] `Tokenizer`: string → List\<Token\>
- [x] Unit tests del Tokenizer (TDD)
- [x] Widget test básico: app arranca sin crash

### v0.2.0 — Parser & Evaluator ✅

- [x] `Parser`: List\<Token\> → árbol de expresión (AST)
- [x] Recursive descent con precedencia PEMDAS
- [x] `Evaluator`: AST → double
- [x] Operaciones: `+`, `-`, `×`, `÷`
- [x] Paréntesis y negación unaria
- [x] Unit tests exhaustivos (TDD): casos normales + edge cases
- [x] `CalculatorController` (ChangeNotifier) conecta input → evaluación

### v0.3.0 — UI Casio Layout ✅

- [x] Grid de botones 4 columnas (layout HL-820LV)
- [x] Todos los widgets con `Semantics` labels
- [x] Display: expresión arriba + resultado abajo (live preview)
- [x] Diferenciación visual de teclas por grupo funcional
- [x] Widget tests: cada botón tiene semántica, display actualiza
- [x] Integration test: secuencia completa `3 + 4 = 7`

### v0.4.0 — Funcionalidades Casio ✅

- [x] Raíz cuadrada (`√`)
- [x] Porcentaje (`%`)
- [x] Memoria (MC, MR, M-, M+)
- [x] Cambio de signo (`+/-`)
- [x] Indicadores de estado: M, Error
- [x] Tests unitarios de cada función
- [x] Integration test: flujo con memoria

### v0.5.0 — Polish & Hardening ✅

- [x] Manejo de errores (÷0, overflow, √ negativo)
- [x] Precisión numérica con redondeo inteligente (12 dígitos significativos)
- [x] Constante de repetición (`=` repetido)
- [x] Haptic/visual feedback en botones
- [x] Integration test: todos los flujos de error

### v1.0.0 — Release Estable ✅

- [x] Feature-complete para calculadora básica con precedencia
- [x] Documentación de usuario
- [x] CI/CD pipeline (GitHub Actions: test + build web)
- [x] Full regression test suite passing

### v1.x.x — Mejoras y correcciones sobre v1

- Bug fixes
- Mejoras de UX/rendimiento
- Refinamiento visual

---

## Etapa 2 — "RPN / Notación Polaca Inversa" (1.x.x → 2.0.0)

Modo RPN con stack visible, inspirado en la HP-50g. El usuario opera con una pila
de resultados usando `Enter` para push y operadores para pop-apply-push.

### v1.x.x → v2.0.0

- [ ] Modelo de stack (pila de N niveles con display)
- [ ] Entrada RPN: número → Enter → número → operador
- [ ] Display de stack (X, Y, Z, T registers visibles)
- [ ] Toggle de modo: Algebraico ↔ RPN
- [ ] Operaciones de stack: SWAP, DROP, DUP, ROT
- [ ] Historial de stack (undo)
- [ ] UI adaptada: botón `Enter` prominente, sin `=`
- [ ] Tests completos para modo RPN

### v2.0.0 — Release Estable

- [ ] Dual-mode calculator (algebraico + RPN)
- [ ] Documentación de ambos modos

### v2.x.x — Mejoras y correcciones sobre v2

- Bug fixes
- Operaciones de stack avanzadas
- Macros / programación keystroke (backlog)

---

## Etapa 3 — "Matrices" (2.x.x → 3.0.0)

Operaciones con matrices: entrada, visualización y álgebra lineal básica.

### v2.x.x → v3.0.0

- [ ] Modelo de datos: Matrix (m×n)
- [ ] Editor de matrices (entrada por celdas)
- [ ] Suma y resta de matrices
- [ ] Multiplicación de matrices
- [ ] Multiplicación escalar
- [ ] Transpuesta
- [ ] Determinante
- [ ] Matriz inversa
- [ ] Display de matrices en grid
- [ ] Integración con modos algebraico y RPN
- [ ] Tests de álgebra lineal

### v3.0.0 — Release Estable

- [ ] Calculadora con soporte completo de matrices
- [ ] Documentación de operaciones matriciales

### v3.x.x — Mejoras y correcciones sobre v3

- Eigenvalues / eigenvectors (backlog)
- Factorizaciones (LU, QR)
- Matrices dispersas

---

## Backlog General

- Performance profiling
- Observability (metrics, tracing)
- Temas visuales / dark mode
- Exportación de historial
- PWA / modo offline
