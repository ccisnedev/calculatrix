# Winget Installer Format Decision for Calculatrix (2026)

## Abstract

This report evaluates whether Inno Setup is the best installer option for a Windows Package Manager submission in 2026, and whether WinGet officially recommends it over other installer formats. Based on official Microsoft, Flutter, and Inno Setup documentation, the answer is no: WinGet does not recommend a single installer format globally, and Inno Setup is not a formally preferred format over MSI, MSIX, or other supported types [@microsoft2026manifest] [@microsoft2026repository]. However, Inno Setup is an officially supported WinGet installer type, WinGet understands its silent-install behavior, and Flutter explicitly presents Inno Setup as a natural way to wrap the Windows release bundle it generates [@microsoft2026manifest] [@flutter2026building]. For a self-hosted, non-Store-first Flutter desktop distribution like Calculatrix, Inno Setup is therefore a strong practical first choice, but that conclusion is project-fit reasoning rather than a blanket WinGet recommendation [@flutter2026building] [@flutter2026deployment] [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline].

## Research Question

Is Inno Setup the best installer option in 2026 for preparing Calculatrix for WinGet, and is it the installer format recommended by WinGet? [@microsoft2026manifest] [@microsoft2026repository]

## Scope and Constraints

This investigation is limited to official documentation from Microsoft, Flutter, and Inno Setup. It focuses on Windows Package Manager compatibility, silent-install expectations, Flutter Windows distribution shape, and the operational implications of MSIX versus a traditional installer for a self-hosted desktop app [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building] [@flutter2026deployment]. Community blog posts, forum folklore, and third-party packaging tutorials are out of scope except where Flutter itself links to them as supplemental material; those linked materials are not used as evidence here [@flutter2026building].

## Method (Staged Protocol)

The investigation followed a staged protocol: define the question, collect candidate official sources, triage them for relevance and recency, extract only directly supported claims, and synthesize a bounded conclusion with explicit uncertainty [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building] [@flutter2026deployment] [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline].

## Findings by Stage

### Stage 1 - Problem Framing

The operative question breaks into three sub-questions: whether WinGet prefers one installer format, whether Inno Setup is fully compatible with WinGet’s submission requirements, and whether Flutter’s Windows output shape makes Inno Setup a better initial fit than MSIX for a self-hosted release path [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building] [@flutter2026deployment]. Success means finding official evidence that either establishes a preferred installer format or shows that the decision must be made by project fit rather than by WinGet policy [@microsoft2026manifest] [@microsoft2026repository].

### Stage 2 - Source Discovery

The candidate source set included Microsoft’s WinGet manifest specification and submission guidance, Flutter’s Windows building and Windows deployment documentation, and Inno Setup’s official command-line documentation for installer and uninstaller behavior [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building] [@flutter2026deployment] [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline]. These sources cover supported installer types, validation policy, Flutter distribution patterns, and silent-mode support without relying on secondary interpretation [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building].

### Stage 3 - Source Triage

Microsoft’s WinGet documentation is the highest-authority source for what the repository accepts and validates, so it anchors the compatibility question [@microsoft2026manifest] [@microsoft2026repository]. Flutter’s official docs are the highest-authority source for the structure of Flutter Windows distribution outputs and the packaging paths Flutter itself presents [@flutter2026building] [@flutter2026deployment]. Inno Setup’s own documentation is the highest-authority source for whether its installer and uninstaller support unattended operation, which WinGet requires [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline]. No lower-quality or redundant sources were needed after those pages covered all major sub-questions [@microsoft2026manifest] [@microsoft2026repository] [@flutter2026building] [@flutter2026deployment].

### Stage 4 - Evidence Extraction

WinGet’s manifest schema lists multiple supported installer types: `exe`, `msi`, `msix`, `inno`, `wix`, `nullsoft`, `appx`, and `font`, which means WinGet does not define one exclusive preferred installer family in the schema itself [@microsoft2026manifest]. The same documentation says that if an executable installer was built using Nullsoft or Inno, those specific values may be used, and the WinGet client will automatically set silent and silent-with-progress behaviors for them [@microsoft2026manifest]. Microsoft’s submission guidance requires that installers support non-interactive modes, install and uninstall correctly for administrators and non-administrators, and come directly from the publisher’s HTTPS release location [@microsoft2026repository].

Flutter’s Windows build documentation states that the Windows release output is an executable plus DLLs and a `data` directory, and that it is relatively simple to add that folder to an installer such as Inno Setup or WiX [@flutter2026building]. The same Flutter documentation presents multiple Windows distribution approaches rather than a single mandated path: MSIX through the Store, MSIX through self-hosting, or distributing your own bundle, which reinforces that Flutter itself does not prescribe a universal installer choice [@flutter2026building]. Flutter’s deployment docs for the Microsoft Store explicitly tie MSIX packaging to Store workflows and note that self-hosted MSIX distribution requires a certificate signed by a Certificate Authority known to Windows [@flutter2026building] [@flutter2026deployment].

Inno Setup’s own documentation confirms silent and very-silent install modes (`/SILENT`, `/VERYSILENT`), non-restart behavior (`/NORESTART`), and install mode control (`/ALLUSERS`, `/CURRENTUSER`) [@jrsoftware2026setupcmdline]. Its uninstaller also supports `/SILENT`, `/VERYSILENT`, and `/NORESTART`, which matters because WinGet validates uninstall behavior, not only installation [@jrsoftware2026uninstcmdline] [@microsoft2026repository].

### Stage 5 - Synthesis and Limits

The strongest supported conclusion is that WinGet does not officially recommend Inno Setup as the single best installer type in 2026; instead, it supports multiple installer formats and validates outcomes such as silent install, uninstall, and direct publisher hosting [@microsoft2026manifest] [@microsoft2026repository]. The strongest project-fit conclusion is that Inno Setup is a very good first option for a self-hosted Flutter Windows app because Flutter’s output is already a bundle that can be wrapped by an installer, and WinGet explicitly recognizes `inno` as an installer type with understood silent behavior [@flutter2026building] [@microsoft2026manifest] [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline]. Confidence in the first conclusion is high because it is directly specified by Microsoft; confidence in the second is medium-high because it combines direct documentation with bounded reasoning about this project shape rather than an explicit Microsoft recommendation phrase [@microsoft2026manifest] [@flutter2026building].

## Discussion

If the question is “What does WinGet recommend?”, the answer is conservative: WinGet recommends compliance with its validation rules, not a single packaging tool [@microsoft2026repository]. If the question is “What is the best first option for Calculatrix right now?”, Inno Setup has a clear operational advantage because it can wrap the existing Flutter release bundle without forcing the project into Store-oriented MSIX identity and certificate work before the release pipeline exists [@flutter2026building] [@flutter2026deployment]. MSI remains a credible alternative and may offer stronger Windows-native upgrade semantics in some ecosystems, but the official sources gathered here do not elevate MSI above Inno as a WinGet requirement or first-choice mandate [@microsoft2026manifest].

## Conclusion

WinGet does not officially recommend Inno Setup as the one best installer option in 2026, and there is no evidence in the official documentation gathered here that Microsoft prefers Inno over MSI, MSIX, WiX, or other supported installer types [@microsoft2026manifest] [@microsoft2026repository]. For Calculatrix specifically, Inno Setup is the strongest first-choice installer path because it is officially supported by WinGet, it satisfies WinGet’s silent-install model when authored correctly, and Flutter’s official Windows distribution model makes wrapping the generated release bundle in an installer such as Inno Setup straightforward [@microsoft2026manifest] [@flutter2026building] [@jrsoftware2026setupcmdline] [@jrsoftware2026uninstcmdline]. The practical decision is therefore: choose Inno Setup as the first installer format for the WinGet path, but describe it as the best fit for this repo, not as a formal WinGet recommendation [@flutter2026building] [@microsoft2026repository].

## Limitations

This report does not compare authoring ergonomics, maintenance cost, or long-term upgrade behavior across Inno Setup, WiX, and MSI using primary benchmark data, because the official sources gathered here do not provide that comparative analysis [@microsoft2026manifest] [@microsoft2026repository]. It also does not evaluate Microsoft Store publishing strategy beyond what Flutter’s Store-facing documentation says about MSIX and signing, so the conclusions apply to the immediate WinGet path rather than the full Microsoft Store path [@flutter2026deployment]. No official source in this set states “Inno Setup is recommended by WinGet,” so any stronger claim would exceed the evidence [@microsoft2026manifest] [@microsoft2026repository].

## References

```bibtex
@misc{microsoft2026manifest,
  title={Create your package manifest},
  year={2026},
  url={https://learn.microsoft.com/en-us/windows/package-manager/package/manifest},
  note={Microsoft Learn, accessed 2026-05-30}
}

@misc{microsoft2026repository,
  title={Submit your manifest to the repository},
  year={2026},
  url={https://learn.microsoft.com/en-us/windows/package-manager/package/repository},
  note={Microsoft Learn, accessed 2026-05-30}
}

@misc{flutter2026building,
  title={Building Windows apps with Flutter},
  year={2026},
  url={https://docs.flutter.dev/platform-integration/windows/building},
  note={Flutter documentation, accessed 2026-05-30}
}

@misc{flutter2026deployment,
  title={Build and release a Windows desktop app},
  year={2026},
  url={https://docs.flutter.dev/deployment/windows},
  note={Flutter documentation, accessed 2026-05-30}
}

@misc{jrsoftware2026setupcmdline,
  title={Setup Command Line Parameters},
  year={2026},
  url={https://jrsoftware.org/ishelp/topic_setupcmdline.htm},
  note={Inno Setup documentation, accessed 2026-05-30}
}

@misc{jrsoftware2026uninstcmdline,
  title={Uninstaller Command Line Parameters},
  year={2026},
  url={https://jrsoftware.org/ishelp/topic_uninstcmdline.htm},
  note={Inno Setup documentation, accessed 2026-05-30}
}
```