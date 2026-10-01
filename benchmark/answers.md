# Answer keys (verified with Giac)

## Basic set (`tasks-basic.txt`)

1. 5.417455798088861
2. inverse [[0.6 -0.7] [-0.2 0.4]], det 10
3. [[58 64] [139 154]]
4. 3+sqrt(3) = 4.7320508, 3, 3-sqrt(3) = 1.2679492
5. 10.31947044479477
6. x = 1, y = -2, z = -2

Graded to about 6 significant digits.

## Trap set (`tasks-traps.txt`)

The exact value is the only correct answer.

1. 12157665459056928801
2. 0
3. does not exist (singular)
4. [[16 -120 240 -140] [-120 1200 -2700 1680] [240 -2700 6480 -4200] [-140 1680 -4200 2800]]
5. 1
6. 0
7. [[19 22] [43 50]]
8. i, -i

## The trap set through `cx`

`trap-set.json` holds each trap as a `cx` program with the output `cx`
must give, and `code/cli/test/trap_set_test.dart` runs them with the CLI
tests, which the CLI release workflow runs before every release. Traps 3 and 8 pass with an error, because `cx` has no correct value
to give:

- Trap 3: the matrix is singular, so `singular-matrix` is the answer.
- Trap 8: the eigenvalues `i` and `-i` are complex, and `cx` has no column
  of complex values yet (issue #64). `cx` raises `complex-result`, its own
  id, and never a wrong value (runbook-trust.md D60). An agent still has
  to answer `i, -i` to be graded correct.

| # | `cx` 0.8.3 (before #54) | `cx` 0.14.0 |
|---|---|---|
| 1 | `12157665459056929000.0` (wrong, silent) | `12157665459056928801` |
| 2 | `0` | `0` |
| 3 | `singular-matrix` | `singular-matrix` |
| 4 | `15.999999999999693 ...` (approximate; no fractions in matrix literals) | the exact integer matrix |
| 5 | `0` (wrong, silent) | `1` |
| 6 | `5.551115123125783e-17` (wrong, silent) | `0` |
| 7 | `[[19 22] [43 50]]` | `[[19 22] [43 50]]` |
| 8 | generic error "undefined in the real domain" | `complex-result` |
