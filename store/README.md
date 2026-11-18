# Google Play listing

The text and graphics prepared in June 2026 for the Calculatrix listing on
Google Play (`dev.ccisne.calculatrix`). Play Console holds the live listing;
these files may differ from it.

| File | Play Console field |
|---|---|
| `listing/en-US/title.txt` | App name (at most 30 characters) |
| `listing/en-US/short_description.txt` | Short description (at most 80 characters) |
| `listing/en-US/full_description.txt` | Full description (at most 4000 characters) |
| `assets/icon/icon-512.png` | App icon, 512 × 512 |
| `assets/feature-graphic/feature-graphic-1024x500.png` | Feature graphic, 1024 × 500 |
| `assets/phone/play-phone-*.png` | Phone screenshots, 1080 × 1920 |

## Known problems

- The short description has 82 characters, two over the limit, so the live
  one in Play Console was shortened or differs.
- The screenshots are of app 0.7.1: the keypad with an empty stack or
  a one-digit draft. They show neither the `SPC` key nor exact values, and nothing of the
  matrix, stack or infix features the description lists.
- The "Precision" paragraph of the full description describes floating
  point with a tolerance and rounding to 12 digits. Since 0.7.2 the app
  keeps values exact (`1 ÷ 3` shows `1/3`) and marks approximate values
  with `~`.

Fix all three before the production listing goes live.
