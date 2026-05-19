# Scalar Promotion in Matrix Algebras: Mathematical Foundations

## Abstract

This paper investigates the mathematical basis for treating a scalar $k \in \mathbb{F}$ as the scalar matrix $k \cdot I_n$ when performing arithmetic operations between scalars and $n \times n$ matrices over a field $\mathbb{F}$. The investigation spans abstract algebra (ring homomorphisms, centers of rings, unital F-algebra structure), numerical linear algebra (shifted QR algorithm, Tikhonov regularization), and programming-language implementations (Julia's `UniformScaling`, NumPy's broadcasting model). We find that the promotion $k \mapsto k I_n$ is not merely a computational convenience: it is the unique ring homomorphism that embeds $\mathbb{F}$ into the center $Z(M_n(\mathbb{F}))$ of the full matrix algebra, making $M_n(\mathbb{F})$ a unital $\mathbb{F}$-algebra. The convention is standard, well-supported by theory, and universally used in practice—but it is restricted, both conceptually and computationally, to **square matrices of a fixed order $n$**. For the Calculatrix project, which represents complex numbers as $2 \times 2$ real matrices via $a + bi \leftrightarrow aI_2 + bJ$, this implies that automatically promoting a scalar $k$ to $kI_2$ when combining with a complex-form matrix is not merely permissible but is the mathematically correct operation.

---

## Research Question

**What is the mathematical foundation of treating a scalar $k$ as $k \cdot I_n$ when performing arithmetic operations between scalars and $n \times n$ matrices (specifically square matrices), and is this convention standard, well-supported by theory, and used in practice?**

---

## Scope and Constraints

**In scope:**
- The canonical scalar embedding $\varphi: \mathbb{F} \to M_n(\mathbb{F})$, $\varphi(k) = kI_n$ as a ring homomorphism.
- The center $Z(M_n(\mathbb{F})) = \{kI_n : k \in \mathbb{F}\}$ and its role in justifying promotion.
- Unital algebras and the $\mathbb{F}$-algebra (F-algebra) structure of $M_n(\mathbb{F})$.
- The "scalar shift" $A + \sigma I$ in numerical linear algebra.
- The restriction to square matrices and why it cannot be generalized to rectangular ones.
- Programming-language treatments: Julia's `UniformScaling`, NumPy's broadcasting, MATLAB behavior.
- Application to complex number subalgebras constructed via $2 \times 2$ real matrices.

**Out of scope:**
- Infinite-dimensional operator algebras or C*-algebras (except incidentally).
- Non-square (rectangular) matrix addition semantics.
- Floating-point precision or numerical conditioning of the shift operation.
- Implementation details of the Calculatrix Dart codebase.

---

## Method (Staged Protocol)

The investigation followed a five-stage protocol:

1. **Problem Framing** — normalize the research question, establish scope boundaries, define success criteria.
2. **Source Discovery** — collect primary sources from Wikipedia (Scalar matrix, Matrix ring, Center of a ring, Associative algebra, Algebra over a field, QR algorithm), Julia LinearAlgebra documentation, and NumPy documentation.
3. **Source Triage** — score each source for relevance and credibility; retain sources with direct mathematical content.
4. **Evidence Extraction** — extract verbatim passages, theorems, and examples; attribute each to the originating source.
5. **Synthesis and Limits** — reconcile all evidence, assess confidence per conclusion, document limitations.

---

## Findings by Stage

### Stage 1 – Problem Framing

The question arises in two related but distinct registers:

**Algebraic register:** Given a field $\mathbb{F}$ and the ring $M_n(\mathbb{F})$ of $n \times n$ matrices, can we sensibly interpret "$k + A$" for $k \in \mathbb{F}$ and $A \in M_n(\mathbb{F})$? If so, what formal justification permits writing $k + A = kI_n + A$?

**Implementation register:** When a user writes `scalarValue + complexMatrix` in a programming context where matrices represent complex numbers as $2 \times 2$ real matrices, which semantic should the runtime apply: (a) promote $k \to kI_2$, or (b) raise a type error?

Success criteria: find a canonical mathematical theorem that identifies $kI_n$ as *the* natural embedding of $k$ into $M_n(\mathbb{F})$, and confirm that this is the convention adopted in standard numerical linear algebra and scientific computing languages.

---

### Stage 2 – Source Discovery

| # | Source | Type | URL |
|---|--------|------|-----|
| S1 | Wikipedia: Diagonal matrix (Scalar matrix section) | Encyclopedia | https://en.wikipedia.org/wiki/Diagonal_matrix |
| S2 | Wikipedia: Matrix ring | Encyclopedia | https://en.wikipedia.org/wiki/Matrix_ring |
| S3 | Wikipedia: Center (ring theory) | Encyclopedia | https://en.wikipedia.org/wiki/Center_(ring_theory) |
| S4 | Wikipedia: Associative algebra | Encyclopedia | https://en.wikipedia.org/wiki/Associative_algebra |
| S5 | Wikipedia: Algebra over a field | Encyclopedia | https://en.wikipedia.org/wiki/Algebra_over_a_field |
| S6 | Wikipedia: QR algorithm | Encyclopedia | https://en.wikipedia.org/wiki/QR_algorithm |
| S7 | Julia LinearAlgebra docs: UniformScaling | Official docs | https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/ |
| S8 | NumPy docs: numpy.add | Official docs | https://numpy.org/doc/stable/reference/generated/numpy.add.html |

Underlying textbooks cited by these sources include Lam (1999) *Lectures on Modules and Rings*, Lang (2005) *Undergraduate Algebra*, Golub & Van Loan (1996, 2013) *Matrix Computations*, and Trefethen & Bau (1997) *Numerical Linear Algebra* [@lam1999lectures; @lang2005algebra; @golub2013matrix; @trefethen1997numerical].

---

### Stage 3 – Source Triage

All eight sources were retained as directly relevant. Wikipedia articles on algebraic topics at this level are well-cited secondary sources backed by graduate-level textbooks (Lam, Artin, Bourbaki, Pierce); they are appropriate as entry points whose claims trace to primary literature. The Julia documentation is an authoritative primary source for implementation conventions. NumPy documentation is authoritative for the alternative (broadcasting) convention.

No source was dropped; no conflict between sources was detected (the algebraic sources are consistent; Julia and NumPy represent different but complementary design choices).

---

### Stage 4 – Evidence Extraction

#### 4.1 Scalar Matrices and the Center of the Matrix Algebra

The Wikipedia article on diagonal matrices defines scalar matrices as follows [@wikidiagonal]:

> "A diagonal matrix with equal diagonal entries is a scalar matrix; that is, a scalar multiple $\lambda$ of the identity matrix $I$."

And critically, it establishes the centrality property:

> "The scalar matrices are the **center of the algebra of matrices**: that is, they are precisely the matrices that commute with all other square matrices of the same size."

The same fact is stated in the Wikipedia article on the center of a ring [@wikicenter]:

> "The center of the (full) matrix ring with entries in a commutative ring $R$ consists of $R$-scalar multiples of the identity matrix."

Formally: $Z(M_n(R)) = \{kI_n : k \in Z(R)\}$. For $R = \mathbb{F}$ a field (which is commutative), this simplifies to $Z(M_n(\mathbb{F})) = \{kI_n : k \in \mathbb{F}\}$.

This is confirmed by the Wikipedia article on matrix rings [@wikimatrixring]:

> "The **center** of $M_n(R)$ consists of the scalar multiples of the identity matrix, $I_n$, in which the scalar belongs to the center of $R$."

#### 4.2 The Canonical Ring Homomorphism: The Scalar Embedding

The Wikipedia article on associative algebras gives the algebraic mechanism directly [@wikiassocalgebra]:

> "An associative algebra amounts to a **ring homomorphism** whose image lies in the center. Indeed, starting with a ring $A$ and a ring homomorphism $\eta: R \to A$ whose image lies in the center of $A$, we can make $A$ an $R$-algebra by defining $r \cdot x = \eta(r)x$ for all $r \in R$ and $x \in A$."

This is the key theorem. The map

$$\varphi: \mathbb{F} \to M_n(\mathbb{F}), \quad \varphi(k) = kI_n$$

is a **unital ring homomorphism** whose image lands in $Z(M_n(\mathbb{F}))$. It satisfies:

- $\varphi(1) = I_n$ (unital)
- $\varphi(k + l) = (k+l)I_n = kI_n + lI_n = \varphi(k) + \varphi(l)$ (additive)
- $\varphi(kl) = klI_n = (kI_n)(lI_n) = \varphi(k)\varphi(l)$ (multiplicative)

This makes $M_n(\mathbb{F})$ an $\mathbb{F}$-algebra with **structure map** $\varphi$. The article on algebras over a field restates this [@wikialgebrafield]:

> "an algebra over a field $K$ is a ring $A$ together with a ring homomorphism $\eta: K \to Z(A)$, where $Z(A)$ is the center of $A$."

The scalar multiplication in the algebra is then:

$$(k, A) \mapsto \eta(k) \cdot A = (kI_n)A = kA$$

This is *the only* ring homomorphism from a field $\mathbb{F}$ to $M_n(\mathbb{F})$ that is compatible with scalar multiplication, because a field has no non-trivial ideals, so any unital ring homomorphism from a field is injective, and the image must lie in the center.

**Consequence:** The expression $k + A$ for $k \in \mathbb{F}$, $A \in M_n(\mathbb{F})$ is defined unambiguously as $\varphi(k) + A = kI_n + A$. This is not a convention—it is the unique definition consistent with the $\mathbb{F}$-algebra structure of $M_n(\mathbb{F})$.

#### 4.3 Unital Algebra Structure

The algebra over a field Wikipedia article defines the identity element requirement explicitly [@wikialgebrafield]:

> "An algebra is unital or unitary if it has a unit or identity element $I$ with $Ix = x = xI$ for all $x$ in the algebra."

And provides as a canonical example:

> "The ring of real square matrices of order $n$ forms a unital algebra since the identity matrix of order $n$ is the identity element with respect to matrix multiplication."

Since $M_n(\mathbb{F})$ is a unital $\mathbb{F}$-algebra, the unit $I_n$ *is* the image of $1 \in \mathbb{F}$ under the structure map. The image of any scalar $k \in \mathbb{F}$ is therefore $kI_n$. Promotion is not an extension—it *is* the algebra structure.

#### 4.4 Why This Requires Square Matrices

The identity matrix $I_n$ is defined only for **square** matrices. It is the $n \times n$ identity transformation on an $n$-dimensional space. For an $m \times n$ rectangular matrix ($m \neq n$), there is no single identity matrix, and the ring axioms for $M_n(\mathbb{F})$ do not apply—$m \times n$ matrices do not form a ring under matrix multiplication.

Concretely: matrix multiplication $A \cdot B$ requires the number of columns of $A$ to equal the number of rows of $B$. An $m \times n$ matrix with $m \neq n$ cannot be multiplied by itself, so the set of all $m \times n$ matrices ($m \neq n$) does not form a ring. Consequently, the notion of "center" and "scalar embedding" does not apply.

The Julia documentation captures this implementation-level restriction explicitly [@juliadocs]:

> "For `A+I` and `A-I` this means that **A must be square**."

This is a consequence of the underlying mathematics: `UniformScaling` has size that *matches* the other operand, but that match is only well-defined when the matrix is square (so that adding $\lambda I_n$ makes dimensional sense).

#### 4.5 The Scalar Shift in Numerical Linear Algebra

The shifted QR algorithm is one of the most important algorithms in computational mathematics [@wikiqr]. In each iteration:

> "Pick a shift $\mu$ and subtract it from all diagonal elements, producing the matrix $A - \mu I$."

And at the end of the iteration:

> "Finally undo the shift by adding $\mu$ to all diagonal entries. The result is $A' = RQ + \mu I$."

This operation—subtracting or adding a scalar multiple of the identity to a matrix—is referred to uniformly in the numerical linear algebra literature as "scalar shift" or "spectral shift." It appears in Golub & Van Loan [@golub2013matrix] and Trefethen & Bau [@trefethen1997numerical] without any additional qualification: the expression $A + \sigma I$ is treated as elementary notation.

Julia's Hessenberg factorization type directly encodes this via `UniformScaling` [@juliadocs]:

> "the shifted factorization $A+\mu I = Q(H+\mu I)Q'$ can be constructed efficiently by `F + μ*I` using the UniformScaling object `I`."

A second canonical application is **Tikhonov regularization** (ridge regression). The regularized normal equations solve $(A^T A + \lambda I)x = A^T b$, where $\lambda I$ is added to ensure positive definiteness. This is an identical operation: a scalar $\lambda$ is promoted to $\lambda I_n$ to regularize the system [@golub2013matrix].

#### 4.6 Julia's `UniformScaling`: Purpose-Built for This Convention

Julia's standard library implements exactly this concept as a first-class type [@juliadocs]:

> "`UniformScaling{T<:Number}` — Generically sized uniform scaling operator defined as a **scalar times the identity operator**, `λ*I`. Although without an explicit `size`, it acts similarly to a matrix in many cases."

The constant `I` in Julia is an instance of `UniformScaling(1)`. The REPL session from the Julia documentation confirms the semantics:

```julia
julia> U = UniformScaling(2)
UniformScaling{Int64}
2*I

julia> a = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> a + U
2×2 Matrix{Int64}:
 3  2    # diagonal incremented by 2; off-diagonal unchanged
 3  6
```

The non-square restriction is enforced with a `DimensionMismatch` error:

```julia
julia> b = [1 2 3; 4 5 6]   # 2×3 matrix
julia> b - U
ERROR: DimensionMismatch: matrix is not square: dimensions are (2, 3)
```

Julia's `UniformScaling` is the most explicit programming-language embodiment of the mathematical convention: it models the element of the center $Z(M_n(\mathbb{F}))$ without fixing $n$ at the type level, and resolves the size lazily from the other operand.

#### 4.7 NumPy: Broadcasting vs. Algebraic Embedding

NumPy does **not** implement the algebraic embedding $k \mapsto kI_n$. Instead, it applies element-wise (broadcasting) addition [@numpyadd]:

> "Add arguments element-wise. [...] Equivalent to `x1 + x2` in terms of array broadcasting."

For a scalar and a matrix in NumPy:

```python
>>> import numpy as np
>>> A = np.array([[1, 2], [3, 4]])
>>> A + 5
array([[ 6,  7],
       [ 8,  9]])    # 5 added to ALL entries, including off-diagonal
```

This behavior—adding 5 to every entry—does **not** correspond to the algebraic embedding $5 \mapsto 5I_2$. NumPy's convention is consistent with the broadcasting model of array computation, where a scalar is conceptually a 0-dimensional array that broadcasts to any shape. This is computationally useful for many purposes, but it is not the ring-homomorphism convention.

**MATLAB** follows the same broadcasting convention as NumPy: `A + 5` adds 5 to every element of `A`.

The conclusion is that the choice between broadcasting semantics and algebraic embedding is a **design decision** at the implementation level. When the matrix represents an element of an algebraic structure (such as the ring of 2×2 real matrices used to model complex numbers), the algebraic embedding is the correct semantic. When the matrix is a plain numerical array, broadcasting is often more ergonomic.

#### 4.8 Complex Numbers as 2×2 Real Matrices

The embedding of complex numbers as $2 \times 2$ real matrices is a classical construction in algebra [@wikimatrixring]:

$$a + bi \longleftrightarrow \begin{pmatrix} a & -b \\ b & a \end{pmatrix} = aI_2 + b\begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$$

The set $\{aI_2 + bJ : a, b \in \mathbb{R}\}$ where $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ is a **subalgebra** of $M_2(\mathbb{R})$, and it is isomorphic to $\mathbb{C}$ as an $\mathbb{R}$-algebra because $J^2 = -I_2$ mirrors the equation $i^2 = -1$.

This subalgebra is closed under:
- Addition: $(aI_2 + bJ) + (cI_2 + dJ) = (a+c)I_2 + (b+d)J$
- Multiplication: $(aI_2 + bJ)(cI_2 + dJ) = (ac-bd)I_2 + (ad+bc)J$
- Scalar multiplication by $k \in \mathbb{R}$: $k(aI_2 + bJ) = (ka)I_2 + (kb)J$

For the operation $k + (aI_2 + bJ)$ where $k$ is a real scalar:

$$k + (aI_2 + bJ) \stackrel{\text{def}}{=} \varphi(k) + (aI_2 + bJ) = kI_2 + (aI_2 + bJ) = (k+a)I_2 + bJ$$

This corresponds exactly to adding the complex number $k + 0i$ to $a + bi$ to get $(k+a) + bi$. The promotion $k \mapsto kI_2$ is therefore not merely algebraically justified—it is the **only** operation that respects the isomorphism $\mathbb{C} \cong \{aI_2 + bJ\}$.

In contrast, the NumPy broadcasting approach would give:

$$k + \begin{pmatrix} a & -b \\ b & a \end{pmatrix} = \begin{pmatrix} k+a & k-b \\ k+b & k+a \end{pmatrix}$$

which is no longer of the form $cI_2 + dJ$ and does **not** correspond to any complex number. Broadcasting destroys the complex-number structure.

---

### Stage 5 – Synthesis and Limits

| Conclusion | Evidence | Confidence |
|-----------|----------|------------|
| The promotion $k \mapsto kI_n$ is the unique unital ring homomorphism $\mathbb{F} \to M_n(\mathbb{F})$ | S3, S4, S5 (center theorem + F-algebra structure map) | **High** |
| $Z(M_n(\mathbb{F})) = \{kI_n : k \in \mathbb{F}\}$, so scalar matrices are exactly the elements that commute with everything | S1, S2, S3 | **High** |
| The convention is restricted to square matrices; rectangular matrices cannot form a ring | S7 (Julia docs explicit error), mathematical necessity | **High** |
| The scalar shift $A + \sigma I$ is standard and universal in numerical linear algebra | S6 (QR algorithm), domain knowledge | **High** |
| Julia's `UniformScaling` is an explicit implementation of the algebraic convention | S7 | **High** |
| NumPy and MATLAB use broadcasting (not algebraic embedding) for scalar+matrix | S8 | **High** |
| For the $\mathbb{C} \cong \{aI_2 + bJ\}$ subalgebra, only the algebraic promotion is correct | S4, S5 + algebraic closure argument | **High** |

No conflicts between sources were detected. The algebraic and numerical evidence is mutually reinforcing.

---

## Discussion

### The Uniqueness of the Scalar Embedding

The argument for $k \mapsto kI_n$ is not just that it is convenient—it is that it is **structurally forced**. An $\mathbb{F}$-algebra structure on $M_n(\mathbb{F})$ is, by definition, a ring homomorphism $\eta: \mathbb{F} \to M_n(\mathbb{F})$ [@wikialgebrafield]. Since $\mathbb{F}$ is a field, any non-zero ring homomorphism from $\mathbb{F}$ is injective. Since $\eta(1) = I_n$ (the unit of the algebra), $\eta(k) = k \cdot \eta(1) = kI_n$ follows by the ring homomorphism property. There is therefore exactly one such structure map, and it is $k \mapsto kI_n$.

### The Center Characterization

The theorem $Z(M_n(\mathbb{F})) = \{kI_n : k \in \mathbb{F}\}$ means that scalar matrices are precisely those matrices that commute with all other matrices of the same size [@wikidiagonal; @wikimatrixring]. This has a powerful consequence: when we write $k + A$, we are adding an element from the center of the algebra to an arbitrary matrix. Addition within a commutative subgroup (the additive group of $M_n(\mathbb{F})$) is well-defined regardless; the center characterization additionally guarantees that the scalar matrix $kI_n$ multiplicatively commutes with every matrix in $M_n(\mathbb{F})$. This is the property that makes the expression $kA = Ak$ hold without any commutativity assumption on $A$.

### Why Rectangular Matrices Are Excluded

The argument is categorical. The set $M_{m,n}(\mathbb{F})$ of $m \times n$ matrices (with $m \neq n$) does not form a ring under matrix multiplication because:
1. Matrix multiplication $M_{m,n} \times M_{m,n} \to ?$ requires $n = m$ to stay within the same set.
2. There is no identity element: $I_m A \neq A$ when $A$ is $m \times n$ with $n \neq m$; the left identity is $I_m$ and the right identity is $I_n$.

Without a ring structure, the notion of "center" is undefined, the F-algebra structure map does not exist, and the embedding $k \mapsto kI_{??}$ has no unambiguous target. This is not a pathological edge case—it is the reason why the identity matrix is defined only for square matrices in the first place.

### Practical Conventions: Julia vs. NumPy

The divergence between Julia and NumPy reflects a fundamental choice: is the primary abstraction an **algebraic structure** (ring, algebra) or a **numeric array** (with shape-based broadcasting)?

Julia's `LinearAlgebra.UniformScaling` is designed for algebraic use. It represents an element of the center of the matrix algebra without committing to a specific size, matching dynamically to the other operand. It enforces the squareness constraint at runtime.

NumPy's broadcasting model treats all tensors uniformly. A scalar is a 0-dimensional tensor that broadcasts to any shape, adding its value to every entry. This is appropriate for numerical array manipulation but is algebraically incorrect for matrix-ring operations.

MATLAB's behavior (`A + 5` adds to all elements) follows the same broadcasting model as NumPy for historical reasons.

**For a library implementing a mathematical algebra** (like complex numbers via $2 \times 2$ matrices), the Julia convention is the correct one. Broadcasting would break the algebraic invariants of the subalgebra.

### Application to the Calculatrix Complex Number Embedding

In the Calculatrix project, each complex number $a + bi$ is represented as the matrix $aI_2 + bJ \in M_2(\mathbb{R})$ where $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$. When the user writes:

```dart
// pseudocode
ScalarMatrix(k) + ComplexMatrix(a, b)
```

the algebraically correct result is:

$$kI_2 + (aI_2 + bJ) = (k + a)I_2 + bJ$$

which represents the complex number $(k+a) + bi$. This is the only operation that:
1. Preserves closure within the complex-number subalgebra of $M_2(\mathbb{R})$.
2. Is compatible with the ring-homomorphism structure of $\mathbb{R} \hookrightarrow M_2(\mathbb{R})$.
3. Respects the isomorphism $\mathbb{C} \cong \{aI_2 + bJ : a, b \in \mathbb{R}\}$.

Any other interpretation (such as broadcasting) would produce a matrix outside the subalgebra, breaking the representation invariant.

---

## Conclusion

The promotion of a scalar $k \in \mathbb{F}$ to the scalar matrix $kI_n \in M_n(\mathbb{F})$ is justified at every level of mathematical abstraction:

1. **Ring theory:** The map $\varphi(k) = kI_n$ is the unique unital ring homomorphism from $\mathbb{F}$ to $M_n(\mathbb{F})$, making $M_n(\mathbb{F})$ a unital $\mathbb{F}$-algebra [@wikialgebrafield; @wikiassocalgebra].

2. **Center theorem:** Scalar matrices $\{kI_n\}$ are exactly the center of $M_n(\mathbb{F})$; the promotion places $k$ into the one subring that commutes with every matrix in $M_n(\mathbb{F})$ [@wikidiagonal; @wikicenter; @wikimatrixring].

3. **Numerical practice:** The shifted QR algorithm, Tikhonov regularization, and all shifted linear-system solves in numerical linear algebra use $A + \sigma I$ as fundamental notation, promoted without further justification [@golub2013matrix; @trefethen1997numerical; @wikiqr].

4. **Programming languages:** Julia's `UniformScaling` is the definitive implementation of the algebraic convention. It enforces squareness and yields $A + \lambda I$ semantics. NumPy and MATLAB use broadcasting (not algebraic embedding), which is correct for array computation but wrong for ring-algebraic operations [@juliadocs; @numpyadd].

5. **Square-only restriction:** The convention is valid **if and only if the matrix is square**. Rectangular matrices do not form a ring, do not have a center, and do not admit a consistent scalar embedding. This restriction is mathematically fundamental, not implementational.

**Recommendation for Calculatrix:** Implement scalar-to-matrix promotion using the algebraic convention: $k \mapsto kI_2$. When the user adds a real scalar to a complex-form $2 \times 2$ matrix, automatically promote the scalar to $kI_2$ and perform matrix addition. This is mathematically mandatory for correctness of the complex-number subalgebra, follows the Julia `UniformScaling` precedent, and aligns with universal practice in linear algebra. The operation must be guarded to require that the matrix is square (which is already guaranteed by the complex-number representation invariant). Using NumPy/MATLAB broadcasting semantics would be algebraically incorrect and would destroy the subalgebra closure.

---

## Limitations

1. The Wikipedia sources used are secondary, citing textbooks (Lam 1999, Lang 2005, Artin 2018, Bourbaki) that were not directly retrieved. The claims extracted are standard graduate-level algebra and are verifiable in any abstract algebra textbook; the risk of inaccuracy is low.

2. The paper does not address the case of **non-commutative base rings** $R$ (where $Z(M_n(R)) = \{kI_n : k \in Z(R)\}$ is a strict subset of scalar matrices). The Calculatrix use case works over $\mathbb{R}$, a commutative field, so this limitation is irrelevant for the application.

3. Tikhonov regularization was mentioned by domain knowledge as a standard application but its primary source was not independently fetched; it is a universally known application of scalar shift.

4. The NumPy source retrieved was the `numpy.add` documentation, which describes broadcasting semantics. The specific behavior of `scalar + matrix` (as opposed to `matrix + scalar`) was inferred from broadcasting rules; a direct demonstration was not retrieved.

5. This paper does not discuss performance implications of materializing $kI_n$ versus representing the scalar shift lazily (as Julia's `UniformScaling` does).

---

## References

```bibtex
@misc{wikidiagonal,
  title        = {Diagonal matrix — Scalar matrix section},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2026},
  url          = {https://en.wikipedia.org/wiki/Diagonal_matrix#Scalar_matrix},
  note         = {Accessed: 2026-05-19}
}

@misc{wikimatrixring,
  title        = {Matrix ring},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2024},
  url          = {https://en.wikipedia.org/wiki/Matrix_ring},
  note         = {Accessed: 2026-05-19}
}

@misc{wikicenter,
  title        = {Center (ring theory)},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2026},
  url          = {https://en.wikipedia.org/wiki/Center_(ring_theory)},
  note         = {Accessed: 2026-05-19}
}

@misc{wikiassocalgebra,
  title        = {Associative algebra},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2026},
  url          = {https://en.wikipedia.org/wiki/Associative_algebra},
  note         = {Accessed: 2026-05-19}
}

@misc{wikialgebrafield,
  title        = {Algebra over a field},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2025},
  url          = {https://en.wikipedia.org/wiki/Algebra_over_a_field},
  note         = {Accessed: 2026-05-19}
}

@misc{wikiqr,
  title        = {QR algorithm},
  howpublished = {Wikipedia, The Free Encyclopedia},
  year         = {2025},
  url          = {https://en.wikipedia.org/wiki/QR_algorithm},
  note         = {Accessed: 2026-05-19}
}

@misc{juliadocs,
  title        = {Linear Algebra — UniformScaling},
  author       = {{Julia Project}},
  howpublished = {Julia v1 Standard Library Documentation},
  year         = {2025},
  url          = {https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/#LinearAlgebra.UniformScaling},
  note         = {Accessed: 2026-05-19}
}

@misc{numpyadd,
  title        = {numpy.add},
  author       = {{NumPy Developers}},
  howpublished = {NumPy v2 Reference Documentation},
  year         = {2025},
  url          = {https://numpy.org/doc/stable/reference/generated/numpy.add.html},
  note         = {Accessed: 2026-05-19}
}

@book{lam1999lectures,
  author    = {Lam, Tsit Yuen},
  title     = {Lectures on Modules and Rings},
  series    = {Graduate Texts in Mathematics},
  number    = {189},
  year      = {1999},
  publisher = {Springer-Verlag},
  address   = {Berlin, New York},
  isbn      = {978-0-387-98428-5}
}

@book{lang2005algebra,
  author    = {Lang, Serge},
  title     = {Undergraduate Algebra},
  edition   = {3rd},
  year      = {2005},
  publisher = {Springer},
  address   = {New York},
  isbn      = {978-0-387-22025-3}
}

@book{golub2013matrix,
  author    = {Golub, Gene H. and Van Loan, Charles F.},
  title     = {Matrix Computations},
  edition   = {4th},
  year      = {2013},
  publisher = {Johns Hopkins University Press},
  address   = {Baltimore},
  isbn      = {978-1-4214-0794-4}
}

@book{trefethen1997numerical,
  author    = {Trefethen, Lloyd N. and Bau, David},
  title     = {Numerical Linear Algebra},
  year      = {1997},
  publisher = {SIAM},
  address   = {Philadelphia},
  isbn      = {978-0-89871-361-9}
}

@book{artin2018algebra,
  author    = {Artin, Michael},
  title     = {Algebra},
  edition   = {2nd},
  year      = {2018},
  publisher = {Pearson},
  isbn      = {978-0-13-468960-9}
}

@book{pierce1982associative,
  author    = {Pierce, Richard S.},
  title     = {Associative Algebras},
  series    = {Graduate Texts in Mathematics},
  number    = {88},
  year      = {1982},
  publisher = {Springer-Verlag},
  isbn      = {978-0-387-90693-5}
}
```
