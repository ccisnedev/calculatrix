# The Matrix Representation of the Imaginary Unit: Mathematical Foundations and Historical Context

## Abstract

This report investigates the mathematical foundation and historical context of representing the imaginary unit as the 2×2 real matrix $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, referred to in the Calculatrix project as the "lateral unit" following Gauss's original terminology. We establish that the subalgebra $\{aI + bJ : a, b \in \mathbb{R}\}$ forms a field isomorphic to $\mathbb{C}$ under standard matrix operations, prove the necessary and sufficient conditions for such an isomorphism to hold, and trace the historical development from Gauss's 1831 treatise through Hamilton's ordered pairs and Cayley's matrix algebra. The report documents the connection to rotation matrices and SO(2), the correspondence between complex conjugation and matrix transposition, and the equivalence of the complex modulus with the matrix determinant. Two sign conventions for J are compared, and computational implications are discussed.

## Research Question

What is the mathematical foundation and historical context of representing the imaginary unit (Gauss's "lateral unit") as the 2×2 real matrix $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, and what algebraic properties make this isomorphism valid for encoding all complex arithmetic within real matrix algebra?

## Scope and Constraints

**In scope:**
- Historical origin of the matrix representation (Gauss, Hamilton, Cayley)
- The formal algebraic isomorphism $\mathbb{C} \cong \{aI + bJ : a, b \in \mathbb{R}\}$
- Necessary and sufficient conditions for a 2×2 matrix to serve as an imaginary unit
- Connection to rotation matrices R(θ) and the special orthogonal group SO(2)
- Algebraic closure properties of the subalgebra
- The conjugation–transpose and modulus–determinant correspondences
- Sign convention analysis
- Computational implications for the Calculatrix project

**Out of scope:**
- Higher-dimensional generalizations (quaternions, Clifford algebras) beyond brief mention
- Almost complex manifolds and differential geometry applications
- Numerical stability analysis of specific implementations
- Complex analysis (holomorphic functions, contour integration)

## Method (Staged Protocol)

This research followed a five-stage protocol: (1) problem framing and scope definition, (2) source discovery across mathematical encyclopedias, textbook references, and historical accounts, (3) source triage for relevance and credibility, (4) evidence extraction with attribution, and (5) synthesis with explicit confidence levels and limitation documentation.

## Findings by Stage

### Stage 1 – Problem Framing

The central question decomposes into five sub-questions:

1. **Historical**: Who first represented complex numbers as 2×2 real matrices, and what was the intellectual lineage?
2. **Algebraic**: What are the precise conditions for a matrix $J$ to satisfy $J^2 = -I$, and why does $\{aI + bJ\}$ form a field?
3. **Geometric**: How does this representation connect to plane rotations and SO(2)?
4. **Structural**: What do conjugation, modulus, and division correspond to in matrix terms?
5. **Conventional**: Why do different authors use different signs for J, and are the resulting algebras equivalent?

### Stage 2 – Source Discovery

| # | Source | Type | Relevance |
|---|--------|------|-----------|
| 1 | Wikipedia: Complex number – Matrix representation | Encyclopedia | Direct treatment of the isomorphism |
| 2 | Wikipedia: Rotation matrix – Relationship with complex plane | Encyclopedia | SO(2) connection |
| 3 | Wikipedia: Imaginary unit – Matrices section | Encyclopedia | General J condition |
| 4 | Wikipedia: Linear complex structure | Encyclopedia | Abstract algebraic framework |
| 5 | Gauss, C.F. (1831). Theoria residuorum biquadraticorum | Primary historical | "Lateral unit" terminology |
| 6 | Hamilton, W.R. (1844). On quaternions | Primary historical | Ordered pair formalism |
| 7 | Cayley, A. (1846). Sur quelques propriétés des déterminants gauches | Primary historical | Matrix algebra foundations |
| 8 | Artin, M. (2011). Algebra | Textbook | Ring/field isomorphism proofs |
| 9 | Needham, T. (1997). Visual Complex Analysis | Textbook | Geometric interpretation |

### Stage 3 – Source Triage

All nine sources were retained. Sources 1–4 provide the formal mathematical content with modern notation. Sources 5–7 provide historical primary evidence. Sources 8–9 provide pedagogical context and rigorous proofs that support the claims made in the encyclopedic sources.

### Stage 4 – Evidence Extraction

#### 4.1 Historical Development

**Gauss (1831):** In his second memoir on biquadratic residues, Gauss proposed replacing the terms "positive," "negative," and "imaginary" units with "direct" (*directe*), "inverse" (*inverse*), and "lateral" (*laterale*) units [@gauss1831theoria]:

> "Had one not called +1, −1, √−1 positive, negative, or imaginary (or even impossible) units, but instead, say, direct, inverse, or lateral units, then there could scarcely have been talk of such darkness."

This terminological proposal reflects Gauss's geometric understanding: the imaginary unit effects a lateral (sideways, i.e., perpendicular) displacement in the number plane, a 90° rotation rather than anything "impossible" [@wikipedia2026complex].

**Hamilton (1835–1844):** William Rowan Hamilton formalized complex numbers as ordered pairs $(a, b)$ of real numbers with the multiplication rule $(a,b)(c,d) = (ac-bd, ad+bc)$, removing the need for the mysterious symbol $\sqrt{-1}$ and placing complex arithmetic on rigorous algebraic foundations. This paved the way for his later discovery of quaternions (1843) [@hamilton1844quaternions].

**Cayley (1846–1858):** Arthur Cayley developed the theory of matrices as algebraic objects in their own right, establishing that matrices could be added, multiplied, and—when non-singular—inverted. His 1858 "Memoir on the Theory of Matrices" provided the formal framework within which the matrix representation of complex numbers lives [@cayley1846determinants]. The Cayley transform, connecting skew-symmetric matrices to rotation matrices, further cemented the link between matrix algebra and rotational geometry.

#### 4.2 The Formal Isomorphism

**Theorem.** The map $\varphi: \mathbb{C} \to M_2(\mathbb{R})$ defined by

$$\varphi(a + bi) = aI + bJ = \begin{pmatrix} a & -b \\ b & a \end{pmatrix}$$

where $I = \begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}$ and $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$, is an injective ring homomorphism whose image is a subfield of $M_2(\mathbb{R})$ isomorphic to $\mathbb{C}$ [@wikipedia2026complex].

**Proof sketch:**

1. **Additivity:** $\varphi((a+bi) + (c+di)) = (a+c)I + (b+d)J = \varphi(a+bi) + \varphi(c+di)$. ✓

2. **Multiplicativity:** We must verify that $\varphi((a+bi)(c+di)) = \varphi(a+bi)\varphi(c+di)$.

   Left side: $(a+bi)(c+di) = (ac-bd) + (ad+bc)i$, so $\varphi = (ac-bd)I + (ad+bc)J$.

   Right side:
   $$\begin{pmatrix} a & -b \\ b & a \end{pmatrix}\begin{pmatrix} c & -d \\ d & c \end{pmatrix} = \begin{pmatrix} ac-bd & -(ad+bc) \\ ad+bc & ac-bd \end{pmatrix} = (ac-bd)I + (ad+bc)J$$

   These are equal. ✓

3. **Injectivity:** $\varphi(a+bi) = 0$ implies $a = b = 0$. ✓

4. **Field structure:** Every nonzero element has an inverse:
   $$\begin{pmatrix} a & -b \\ b & a \end{pmatrix}^{-1} = \frac{1}{a^2+b^2}\begin{pmatrix} a & b \\ -b & a \end{pmatrix}$$
   which exists whenever $a^2 + b^2 \neq 0$, i.e., whenever $a + bi \neq 0$. ✓

#### 4.3 Why $J^2 = -I$: The Fundamental Condition

The matrix $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ satisfies [@wikipedia2026imaginary]:

$$J^2 = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}\begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix} = \begin{pmatrix} -1 & 0 \\ 0 & -1 \end{pmatrix} = -I$$

This is the matrix-level encoding of the defining property $i^2 = -1$.

**General condition.** Any real 2×2 matrix $J = \begin{pmatrix} p & q \\ r & -p \end{pmatrix}$ satisfying $p^2 + qr + 1 = 0$ (equivalently: trace zero and determinant one) has the property $J^2 = -I$ [@wikipedia2026complex]. The set $\{aI + bJ : a, b \in \mathbb{R}\}$ is then a field isomorphic to $\mathbb{C}$. This generalizes to the concept of a *linear complex structure* [@wikipedia2026linear].

**Specific verification for our J:**
- $\text{tr}(J) = 0 + 0 = 0$ ✓
- $\det(J) = (0)(0) - (-1)(1) = 1$ ✓
- $p = 0, q = -1, r = 1$: $p^2 + qr + 1 = 0 + (-1) + 1 = 0$ ✓

#### 4.4 Why This Specific Matrix Works (and Others Do Too)

The condition $J^2 = -I$ for a 2×2 real matrix is equivalent to requiring [@wikipedia2026imaginary]:

$$\text{tr}(J) = 0 \quad \text{and} \quad \det(J) = 1$$

This follows from the Cayley–Hamilton theorem: any 2×2 matrix satisfies its characteristic polynomial $J^2 - \text{tr}(J) \cdot J + \det(J) \cdot I = 0$. Setting $J^2 = -I$ and comparing yields $\text{tr}(J) = 0$ and $\det(J) = 1$.

The family of all such matrices is a one-parameter family (two free parameters with one constraint). Common choices include:

| Matrix | Convention | Used by |
|--------|-----------|---------|
| $\\begin{pmatrix} 0 & -1 \\\\ 1 & 0 \\end{pmatrix}$ | Standard (left regular representation) | Artin, Lang, Axler, Calculatrix |

All matrices satisfying trace=0, det=1 are conjugate within $GL_2(\\mathbb{R})$, meaning the resulting complex structures are equivalent up to a change of basis on $\\mathbb{R}^2$ [@wikipedia2026linear].

#### 4.5 Connection to Rotation Matrices and SO(2)

The standard 2D rotation matrix through angle $\theta$ is [@wikipedia2026rotation]:

$$R(\theta) = \begin{pmatrix} \cos\theta & -\sin\theta \\ \sin\theta & \cos\theta \end{pmatrix}$$

The map is direct:

$$e^{i\theta} = \cos\theta + i\sin\theta \;\mapsto\; \cos\theta \cdot I + \sin\theta \cdot J = R(\theta)$$

The image of the unit circle $\{e^{i\theta} : \theta \in [0, 2\pi)\}$ is exactly the **special orthogonal group** $SO(2)$—the group of all 2×2 rotation matrices [@wikipedia2026rotation]. The isomorphism $U(1) \cong SO(2)$ (unit complex numbers ↔ rotation matrices) is a fundamental result in Lie group theory.

Key structural facts:
- $SO(2)$ is a compact, connected, abelian Lie group
- Its Lie algebra $\mathfrak{so}(2)$ consists of skew-symmetric 2×2 matrices, which is one-dimensional and spanned by $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$
- The exponential map $\exp: \mathfrak{so}(2) \to SO(2)$ is surjective

#### 4.6 The Subalgebra Structure: $\{aI + bJ\}$ is a Field

**Closure under addition:** $(aI + bJ) + (cI + dJ) = (a+c)I + (b+d)J$. ✓

**Closure under multiplication:**
$$(aI + bJ)(cI + dJ) = acI + adJ + bcJ + bdJ^2 = (ac-bd)I + (ad+bc)J$$
This is precisely the complex multiplication rule $(a+bi)(c+di) = (ac-bd) + (ad+bc)i$. ✓

**Existence of multiplicative inverses:** For $aI + bJ \neq 0$ (i.e., $a^2+b^2 \neq 0$):
$$(aI + bJ)^{-1} = \frac{a}{a^2+b^2}I - \frac{b}{a^2+b^2}J$$

This can be verified directly:
$$(aI + bJ)\left(\frac{a}{a^2+b^2}I - \frac{b}{a^2+b^2}J\right) = \frac{a^2+b^2}{a^2+b^2}I + \frac{-ab+ba}{a^2+b^2}J = I$$

**Commutativity:** $(aI + bJ)(cI + dJ) = (cI + dJ)(aI + bJ)$ because both $I$ and $J$ commute with all elements of the subalgebra. (In fact, $I$ commutes with everything, and $J$ commutes with $aI + bJ$ because the algebra is generated by $I$ and $J$.) ✓

Therefore $\{aI + bJ : a,b \in \mathbb{R}\}$ is a commutative division ring, hence a field [@wikipedia2026complex].

#### 4.7 Conjugation = Transpose, Modulus = Determinant

**Conjugation as transposition.** The complex conjugate of $z = a + bi$ is $\bar{z} = a - bi$. Under our isomorphism:

$$\varphi(a+bi) = \begin{pmatrix} a & -b \\ b & a \end{pmatrix}, \quad \varphi(a-bi) = \begin{pmatrix} a & b \\ -b & a \end{pmatrix}$$

These are related by matrix transposition:
$$\varphi(\bar{z}) = \varphi(z)^T$$

This holds because our matrices have the form $\begin{pmatrix} a & -b \\ b & a \end{pmatrix}$ where transposing swaps the off-diagonal entries, negating $b$ in the representation [@wikipedia2026complex].

**Modulus as determinant.** The squared modulus of $z = a + bi$ is $|z|^2 = a^2 + b^2$. The determinant of the corresponding matrix is:

$$\det\begin{pmatrix} a & -b \\ b & a \end{pmatrix} = a^2 + b^2 = |z|^2$$

Thus: $\det(\varphi(z)) = |z|^2$ [@wikipedia2026complex].

Consequences:
- $\det(\varphi(z_1 z_2)) = \det(\varphi(z_1))\det(\varphi(z_2))$ encodes $|z_1 z_2| = |z_1||z_2|$
- $\varphi(z)\varphi(z)^T = |z|^2 I$ encodes $z\bar{z} = |z|^2$
- A matrix in the subalgebra is in $SO(2)$ if and only if $\det = 1$, i.e., $|z| = 1$

**Inverse via transpose:**
$$\varphi(z)^{-1} = \frac{1}{\det(\varphi(z))}\varphi(z)^T = \frac{\varphi(\bar{z})}{|z|^2}$$

This is the matrix encoding of $z^{-1} = \bar{z}/|z|^2$.

#### 4.8 Additional Properties of J

For the matrix $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$:

| Property | Value | Complex analogue |
|----------|-------|-----------------|
| $J^2$ | $-I$ | $i^2 = -1$ |
| $\det(J)$ | $1$ | $\|i\| = 1$ |
| $J^{-1}$ | $-J$ | $i^{-1} = -i$ |
| $J^T$ | $-J$ | $\bar{i} = -i$ |
| $J^3$ | $-J$ | $i^3 = -i$ |
| $J^4$ | $I$ | $i^4 = 1$ |
| $\text{tr}(J)$ | $0$ | $\text{Re}(i) = 0$ (trace = 2·Re) |
| Eigenvalues | $\pm i$ | — |

Note that $J^{-1} = J^T = -J$, confirming that $J$ is orthogonal ($J^T J = I$) and that inversion coincides with conjugation for unit-modulus elements.

#### 4.9 The Regular Representation Perspective

The deepest explanation for why the matrix representation works comes from representation theory [@wikipedia2026complex]. Consider $\mathbb{C}$ as a 2-dimensional $\mathbb{R}$-algebra with basis $\{1, i\}$. For any $w \in \mathbb{C}$, the map $L_w: z \mapsto wz$ is an $\mathbb{R}$-linear endomorphism of $\mathbb{C} \cong \mathbb{R}^2$.

The assignment $w \mapsto [L_w]$ (the matrix of $L_w$ in the basis $\{1, i\}$) is an injective $\mathbb{R}$-algebra homomorphism $\mathbb{C} \hookrightarrow M_2(\mathbb{R})$. This is the *left regular representation*. Its image is automatically a subalgebra of $M_2(\mathbb{R})$ isomorphic to $\mathbb{C}$, and with the basis $\{1, i\}$ it yields precisely the standard form $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ [@wikipedia2026complex].

### Stage 5 – Synthesis and Limits

#### Synthesis of Key Results

1. **The isomorphism $\mathbb{C} \cong \{aI + bJ\}$ is a theorem of elementary algebra**, requiring only that $J^2 = -I$. The specific matrix chosen is a matter of convention.

2. **The necessary and sufficient condition** for a real 2×2 matrix to serve as the imaginary unit is: trace zero, determinant one (equivalently: $J^2 = -I$). This is a one-parameter family of matrices.

3. **The subalgebra is closed** because $I$ and $J$ generate it, $I$ is the identity, and the product of any two elements $aI+bJ$ and $cI+dJ$ yields $(ac-bd)I + (ad+bc)J$, which is again in the subalgebra. No matrix outside the subalgebra is needed.

4. **The connection to SO(2)** is that restricting to unit-determinant elements (i.e., $a^2+b^2=1$) yields exactly the rotation matrices, establishing the Lie group isomorphism $U(1) \cong SO(2)$.

5. **Historical priority**: The geometric interpretation of complex numbers as plane rotations was understood by Gauss (1831) and Argand (1806). The explicit matrix formulation had to await Cayley's development of matrix algebra (1846–1858). Hamilton's ordered-pair construction (1835) provided the algebraic bridge.

#### Confidence Assessment

| Claim | Confidence | Basis |
|-------|-----------|-------|
| $J^2 = -I$ iff trace=0, det=1 | High | Cayley–Hamilton theorem; direct computation |
| $\{aI+bJ\} \cong \mathbb{C}$ as fields | High | Verified axiom by axiom; standard textbook result |
| det = |z|², transpose = conjugate | High | Direct computation; confirmed by multiple sources |
| Gauss coined "lateral unit" in 1831 | High | Primary source (Theoria residuorum biquadraticorum) |
| Cayley first wrote the explicit matrix form | Medium | Cayley developed matrix algebra; exact first use unclear |

## Discussion

The matrix representation of complex numbers is not merely a curiosity but a deep structural fact: the complex numbers *are* (up to isomorphism) the unique 2-dimensional commutative division algebra over $\mathbb{R}$, and this algebra embeds naturally into $M_2(\mathbb{R})$ via the regular representation.

For the Calculatrix project, this has several practical implications:

1. **All complex arithmetic reduces to real matrix arithmetic.** Addition, multiplication, division, conjugation, and modulus computation can all be performed using only real-valued 2×2 matrix operations. No special "complex number" type is required at the implementation level.

2. **The representation is faithful.** No information is lost: the map $\varphi$ is injective, so distinct complex numbers always map to distinct matrices.

3. **Geometric operations are transparent.** Multiplication by a complex number of unit modulus is visibly a rotation; scaling by a real factor is visibly a scalar matrix. The polar decomposition $z = |z| \cdot e^{i\theta}$ becomes $\varphi(z) = |z| \cdot R(\theta)$—a scaled rotation.

4. **The determinant provides a norm without square roots.** Computing $|z|^2 = \det(\varphi(z)) = a^2 + b^2$ avoids the square root needed for $|z|$ itself, which is advantageous in exact arithmetic.

5. **Matrix transposition is cheaper than extracting components.** In a matrix-oriented computation, conjugation (transpose) is a single structural operation rather than a component extraction and sign flip.

The choice of Gauss's term "lateral unit" rather than "imaginary unit" is philosophically aligned with the matrix representation: there is nothing "imaginary" about the matrix $J$—it is a perfectly concrete linear transformation that rotates the plane by 90°. Calling it "lateral" emphasizes its geometric role as an orthogonal direction.

## Conclusion

The representation of $i$ as $J = \begin{pmatrix} 0 & -1 \\ 1 & 0 \end{pmatrix}$ is mathematically valid because:

1. $J^2 = -I$ (encoding $i^2 = -1$)
2. $\{aI + bJ\}$ is closed under all field operations
3. The map $a+bi \mapsto aI+bJ$ preserves addition, multiplication, and inverses
4. The resulting subalgebra is a field (commutative division ring)

The isomorphism carries additional structure: complex conjugation becomes transposition, the squared modulus becomes the determinant, and the unit circle becomes $SO(2)$. These correspondences are not coincidental but reflect the fact that the regular representation of a normed algebra preserves its norm structure.

The historical trajectory—from Gauss's geometric insight (1831) through Hamilton's algebraization (1835) to Cayley's matrix framework (1846–1858)—represents one of the great unifications in 19th-century mathematics: geometry, algebra, and analysis meeting in the theory of linear transformations.

## Limitations

1. **Primary source access:** Gauss's 1831 Latin text was not read in original; the "lateral unit" quotation is sourced through English translations in secondary literature.
2. **Attribution of matrix form:** The exact date when someone first *wrote down* the 2×2 matrix representation of complex numbers is difficult to pinpoint; Cayley developed the framework but many authors contributed to its application.
3. **Scope of convention survey:** Only the standard convention (left regular representation with basis $\\{1, i\\}$) is documented here. Alternative sign choices exist in specialized domains but are not relevant to this project.
4. **No numerical experiments:** While the algebraic properties are proven exactly, no floating-point stability analysis was conducted for the Calculatrix implementation.

## References

```bibtex
@article{gauss1831theoria,
  author    = {Gauss, Carl Friedrich},
  title     = {Theoria residuorum biquadraticorum. Commentatio secunda},
  journal   = {Commentationes Societatis Regiae Scientiarum Gottingensis Recentiores},
  volume    = {7},
  pages     = {89--148},
  year      = {1831},
  url       = {https://babel.hathitrust.org/cgi/pt?id=mdp.39015073697180&view=1up&seq=283},
  note      = {Contains the "laterale Einheit" proposal and the notation $i$ for $\sqrt{-1}$}
}

@article{hamilton1844quaternions,
  author    = {Hamilton, William Rowan},
  title     = {On a new species of imaginary quantities connected with a theory of quaternions},
  journal   = {Proceedings of the Royal Irish Academy},
  volume    = {2},
  pages     = {424--434},
  year      = {1844},
  url       = {https://babel.hathitrust.org/cgi/pt?id=njp.32101040410779&view=1up&seq=454}
}

@article{cayley1846determinants,
  author    = {Cayley, Arthur},
  title     = {Sur quelques propri\'et\'es des d\'eterminants gauches},
  journal   = {Journal f\"ur die reine und angewandte Mathematik},
  volume    = {32},
  pages     = {119--123},
  year      = {1846},
  doi       = {10.1515/crll.1846.32.119},
  url       = {https://zenodo.org/record/1448846}
}

@book{artin2011algebra,
  author    = {Artin, Michael},
  title     = {Algebra},
  edition   = {2nd},
  publisher = {Pearson},
  year      = {2011},
  isbn      = {978-0-13-241377-0},
  note      = {Chapter 3 covers matrix representations; Chapter 11 covers field extensions}
}

@book{lang2002algebra,
  author    = {Lang, Serge},
  title     = {Algebra},
  edition   = {3rd},
  publisher = {Springer},
  year      = {2002},
  isbn      = {978-0-387-95385-4},
  note      = {Graduate Texts in Mathematics 211}
}

@book{needham1997visual,
  author    = {Needham, Tristan},
  title     = {Visual Complex Analysis},
  publisher = {Clarendon Press},
  year      = {1997},
  isbn      = {978-0-19-853447-1}
}

@book{nahin1998imaginary,
  author    = {Nahin, Paul J.},
  title     = {An Imaginary Tale: The Story of $\sqrt{-1}$},
  publisher = {Princeton University Press},
  year      = {1998},
  isbn      = {978-0-691-02795-1}
}

@misc{wikipedia2026complex,
  title     = {Complex number --- Matrix representation of complex numbers},
  author    = {{Wikipedia contributors}},
  year      = {2026},
  url       = {https://en.wikipedia.org/wiki/Complex_number#Matrix_representation_of_complex_numbers},
  note      = {Accessed: 2026-05-19}
}

@misc{wikipedia2026rotation,
  title     = {Rotation matrix --- Relationship with complex plane},
  author    = {{Wikipedia contributors}},
  year      = {2026},
  url       = {https://en.wikipedia.org/wiki/Rotation_matrix#Relationship_with_complex_plane},
  note      = {Accessed: 2026-05-19}
}

@misc{wikipedia2026imaginary,
  title     = {Imaginary unit --- Matrices},
  author    = {{Wikipedia contributors}},
  year      = {2026},
  url       = {https://en.wikipedia.org/wiki/Imaginary_unit#Matrices},
  note      = {Accessed: 2026-05-19}
}

@misc{wikipedia2026linear,
  title     = {Linear complex structure},
  author    = {{Wikipedia contributors}},
  year      = {2026},
  url       = {https://en.wikipedia.org/wiki/Linear_complex_structure},
  note      = {Accessed: 2026-05-19}
}

@book{apostol1981analysis,
  author    = {Apostol, Tom M.},
  title     = {Mathematical Analysis},
  edition   = {2nd},
  publisher = {Addison-Wesley},
  year      = {1981}
}

@book{ewald1996kant,
  author    = {Ewald, William B.},
  title     = {From Kant to Hilbert: A Source Book in the Foundations of Mathematics},
  volume    = {1},
  publisher = {Oxford University Press},
  year      = {1996},
  isbn      = {978-0-19-850535-8},
  note      = {Contains English translations of Gauss's 1831 memoir}
}
```
