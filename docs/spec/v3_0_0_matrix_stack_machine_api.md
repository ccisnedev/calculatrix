# v3.0.0 Matrix Stack Machine Public API Specification

Status: Draft
Owner: Calculatrix maintainers
Target release: v3.0.0
Primary package: calculatrix
Primary path: code/core
Companion release specification: docs/spec/v3_0_0_matrix_stack_machine.md
Companion stage specification: docs/spec/stage_3_matrix_stack_machine.md

## 1. Purpose

This document defines the intended public API for v3.0.0.

The goal is to make package:calculatrix a public matrix stack machine instead of
only a collection of matrix helpers plus a notation-specific session model.

After v3.0.0:

1. Public primitive commands are first-class API.
2. Public macros are first-class API.
3. Infix remains supported as a convenience frontend over the same kernel.
4. App and CLI consumers use the same public command vocabulary.

## 2. Naming and Package Identity

The public package name remains calculatrix.

Rationale:

1. The package is larger than a single low-level implementation detail.
2. Existing consumers already import package:calculatrix.
3. The canonical architectural model is matrix stack machine, but the public
   package identity remains Calculatrix.

The phrase matrix stack machine is therefore an architectural term and API
design guide, not a package rename requirement.

## 3. Design Goals

1. Keep the public API typed.
2. Keep the kernel matrix-first.
3. Keep committed execution stack-first.
4. Allow convenience frontends without creating a second semantic engine.
5. Keep advanced-user RPN workflows first-class.
6. Keep app and CLI as thin consumers.

## 4. Public Package Surface

The root library should continue exporting Matrix and compatibility facades,
but v3.0.0 adds an explicit machine-and-command layer.

Planned public roles:

1. Matrix values
2. Matrix display formatting
3. Matrix stack machine
4. Primitive commands
5. Public macros
6. Infix compiler or infix convenience facade
7. Optional interactive session facade
8. Typed error taxonomy

Illustrative root export shape:

```dart
library calculatrix;

export 'src/errors/errors.dart';
export 'src/machine/calculatrix_machine.dart';
export 'src/machine/calculatrix_command.dart';
export 'src/machine/calculatrix_macro.dart';
export 'src/machine/commands.dart';
export 'src/machine/macros.dart';
export 'src/evaluation/calculatrix.dart';
export 'src/evaluation/infix_compiler.dart';
export 'src/matrix/matrix.dart';
export 'src/matrix/matrix_display_formatter.dart';
export 'src/session/calculatrix_session.dart';
```

Exact filenames may differ, but these public capability groups are required.

## 5. Canonical Public Types

### 5.1 Matrix

Matrix remains the canonical committed value type.

Contract:

1. Scalars are represented as 1x1 matrices.
2. Vectors are matrices.
3. Non-square matrices are first-class values.
4. Construction, arithmetic, transpose, inverse, and structural operations are
   part of the matrix-first domain model.

v3.0.0 must expose public matrix helpers equivalent to:

1. Matrix.scalar
2. Matrix.identity
3. Matrix.zeros
4. Matrix.ones
5. Matrix.transpose
6. Matrix.inverse

If zeros and ones remain command-only rather than instance constructors, that is
acceptable as long as the public machine layer can construct them without any
GUI dependency.

### 5.2 CalculatrixMachine

CalculatrixMachine is the canonical execution surface.

It represents a mutable stack machine over Matrix values.

Required public capabilities:

1. Observe stack depth.
2. Observe top value.
3. Observe a stack snapshot.
4. Execute one command.
5. Execute a program.
6. Clear machine state.

Illustrative shape:

```dart
abstract interface class CalculatrixMachine {
  int get depth;
  Matrix? get top;
  List<Matrix> get stackSnapshot;

  void clear();
  void execute(CalculatrixCommand command);
  void executeAll(Iterable<CalculatrixCommand> program);
}
```

Contract notes:

1. stackSnapshot is read-only.
2. top returns null when the stack is empty.
3. execute throws typed domain errors when preconditions fail.
4. executeAll is equivalent to executing the same commands sequentially.

### 5.3 CalculatrixCommand

CalculatrixCommand is the canonical public unit of committed behavior.

Rules:

1. Commands are typed public values.
2. Commands are immutable.
3. Commands carry explicit parameters when needed.
4. Commands do not depend on hidden GUI state.

Illustrative base type:

```dart
sealed class CalculatrixCommand {
  const CalculatrixCommand();
}
```

### 5.4 CalculatrixMacro

CalculatrixMacro is a public product abstraction, not a private GUI trick.

Rules:

1. Macros are public API.
2. Macros are executable without a GUI dependency.
3. Macros may expand into primitive commands.
4. Macros may inspect explicit machine state required by their documented
   contract.

Illustrative shape:

```dart
abstract interface class CalculatrixMacro {
  Iterable<CalculatrixCommand> expand(CalculatrixMachine machine);
}
```

### 5.5 CalculatrixProgram

v3.0.0 should expose a typed immutable program container.

Purpose:

1. Hold compiled infix output.
2. Hold macro expansion output.
3. Support deterministic testing of command sequences.

Illustrative shape:

```dart
final class CalculatrixProgram {
  const CalculatrixProgram(this.commands);

  final List<CalculatrixCommand> commands;
}
```

### 5.6 InfixCompiler

Infix is a convenience frontend over the canonical stack machine.

v3.0.0 should expose a typed compiler-equivalent surface.

Required capabilities:

1. Compile infix text to a typed program.
2. Keep convenience execution for consumers that only need the result.
3. Preserve matrix literals as valid operands.

Illustrative shape:

```dart
abstract interface class InfixCompiler {
  CalculatrixProgram compile(String expression);
}

class Calculatrix {
  static CalculatrixProgram compileInfix(String expression);
  static Matrix evaluateInfix(String expression);
  static Matrix evaluateRpn(List<String> tokens);
}
```

evaluateInfix and evaluateRpn may remain as compatibility conveniences, but
they no longer define the semantic center of the package.

### 5.7 CalculatrixSession

If a session facade remains public, it is a consumer convenience layer above
CalculatrixMachine.

Rules:

1. It may keep transient drafts.
2. It may route commands and macros.
3. It may expose memory and shared-current-value helpers.
4. It must not redefine primitive command semantics.
5. It must not require GUI-only concepts such as focused cell or drag state.

### 5.8 CalculatrixEntryMode

If the session facade keeps an input-surface mode enum, the preferred v3.0.0
name is CalculatrixEntryMode rather than CalculatrixMode.

Contract:

1. It models entry frontends, not semantic engines.
2. Its values are infix and rpn.
3. Matrix is an app shell mode, not a core entry mode.

Illustrative shape:

```dart
enum CalculatrixEntryMode { infix, rpn }
```

Keeping the old CalculatrixMode name is acceptable only if migration cost or
compatibility concerns are intentionally prioritized. For new v3.0.0 APIs,
CalculatrixEntryMode is the preferred name.

## 6. Required Primitive Command Catalog

The following public command types are the default v3.0.0 API anchors.

### 6.1 Stack commands

1. DupCommand
2. DropCommand
3. SwapCommand
4. OverCommand
5. PickCommand
6. RollCommand
7. RotCommand

Parameter contract:

1. PickCommand carries indexFromTop.
2. RollCommand carries indexFromTop.

### 6.2 Push and construction commands

1. PushScalarCommand
2. PushMatrixCommand
3. PushZerosCommand
4. PushOnesCommand
5. PushIdentityCommand

Parameter contract:

1. PushScalarCommand carries value.
2. PushMatrixCommand carries a Matrix value.
3. PushZerosCommand carries rowCount and columnCount.
4. PushOnesCommand carries rowCount and columnCount.
5. PushIdentityCommand carries size.

### 6.3 Unary matrix commands

1. NegateCommand
2. PercentCommand
3. SqrtCommand
4. TransposeCommand
5. InverseCommand

### 6.4 Binary matrix commands

1. AddCommand
2. SubtractCommand
3. MultiplyCommand
4. DivideCommand
5. AppendRowCommand
6. AppendColumnCommand

Command semantics:

1. AddCommand consumes top two matrices and pushes the sum.
2. SubtractCommand consumes top two matrices and pushes the difference.
3. MultiplyCommand consumes top two matrices and pushes the product.
4. DivideCommand consumes top two matrices and applies the documented matrix
   division restriction.
5. AppendRowCommand consumes a target matrix and a compatible row operand and
   pushes the resulting matrix.
6. AppendColumnCommand consumes a target matrix and a compatible column operand
   and pushes the resulting matrix.

### 6.5 Parameterized structural commands

1. DeleteRowCommand
2. DeleteColumnCommand
3. DuplicateRowCommand
4. DuplicateColumnCommand
5. MoveRowCommand
6. MoveColumnCommand

Parameter contract:

1. DeleteRowCommand carries rowIndex.
2. DeleteColumnCommand carries columnIndex.
3. DuplicateRowCommand carries rowIndex.
4. DuplicateColumnCommand carries columnIndex.
5. MoveRowCommand carries fromIndex and toIndex.
6. MoveColumnCommand carries fromIndex and toIndex.

Semantic rule:

These commands operate on the top matrix and do not infer hidden selection.

## 7. Required Public Macro Catalog

The following public macros are required by the v3.0.0 product contract.

### 7.1 Shape-derived macros

1. FillZerosLikeTopMacro
2. FillOnesLikeTopMacro
3. AppendZeroRowMacro
4. AppendZeroColumnMacro

Contract:

1. These macros require a non-empty machine stack.
2. They inspect the shape of the top matrix.
3. They expand into public commands or behave equivalently through the same
   public kernel.

### 7.2 Explicit-size macro

1. CreateIdentityMacro

Contract:

1. CreateIdentityMacro carries size.
2. It pushes a fresh identity matrix for that size.

### 7.3 Macro naming flexibility

The exact class names may be adjusted before implementation starts, but the
public workflows and parameter contracts are part of the release API.

## 8. Error Model Expectations

The public API should continue using typed errors and extend them where the new
command surface requires more precision.

Required error families for v3.0.0:

1. MatrixShapeError
2. MatrixDomainError
3. MatrixIndexError
4. RpnStackUnderflowError
5. RpnStackRangeError
6. ExpressionSyntaxError
7. UnsupportedCalculatrixOperationError

Notes:

1. MatrixIndexError is the preferred error for invalid row or column indices in
   structural commands.
2. Macro failures should prefer the underlying typed domain or stack errors
   rather than introducing GUI-specific exceptions.

## 9. Compatibility and Migration

### 9.1 Compatibility conveniences to preserve

v3.0.0 should keep these convenience surfaces when practical:

1. Calculatrix.evaluateInfix
2. Calculatrix.evaluateRpn
3. A low-level stack-oriented API equivalent to the current RpnEngine

### 9.2 Preferred migration direction

The preferred consumer path after v3.0.0 is:

1. Use typed commands for deterministic workflows.
2. Use public macros for shipping product shortcuts.
3. Use infix only when algebra-style text entry is the right UX.

### 9.3 App migration direction

The app should migrate from dialog-to-literal workflows toward:

1. local draft editing
2. commit-before-execute
3. public command or macro dispatch through the core

### 9.4 CLI migration direction

The CLI should migrate from mode-name plus loose evaluation calls toward:

1. explicit command routing
2. explicit macro routing
3. infix convenience routing through the same core entrypoints

## 10. Acceptance Criteria for API Readiness

The public API is ready for v3.0.0 TDD when all of the following are true.

1. The core command layer is named and grouped.
2. The macro catalog is named and grouped.
3. Infix is defined as frontend, not semantic peer.
4. The session facade role is constrained.
5. Matrix shell behavior can target core commands without inventing new hidden
   semantics.

Assessment: ready.