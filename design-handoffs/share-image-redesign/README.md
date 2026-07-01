# Handoff: WristScan Share Card Redesign

## Overview
This package redesigns the "save & share" image cards WristScan generates from reports.
It covers **three** of the app's share cards, giving each a stronger visual hierarchy,
an elevated "featured" card treatment, and a proper stat-card/leaderboard layout instead
of flat lists and plain charts.

The three cards in scope map 1:1 to existing SwiftUI views:

| Design file (this bundle)        | SwiftUI struct to update      | File                          | Export size |
|----------------------------------|-------------------------------|-------------------------------|-------------|
| `Rewind Share Card.dc.html`      | `RewindShareCard`             | `RewindView.swift`            | 1080 × 1350 |
| `Watch Spec Card.dc.html`        | `WatchDetailShareCard`        | `WatchDetailView.swift`       | 1080 × 1600 |
| `Top Wrist Checks Card.dc.html`  | `WearChartShareCard`          | `AnalyticsDashboardView.swift`| 1080 × 1350 |

> **Out of scope:** `DistributionShareCard` (Collection Distribution) is intentionally
> NOT part of this handoff — leave it as-is for now.

## About the Design Files
The `.dc.html` files in this bundle are **design references** — HTML/CSS prototypes that
show the intended look, layout, and hierarchy. They are **not** production code to copy.
The task is to **recreate these designs in the existing SwiftUI share-card views**, using
the app's established patterns: the cards are already SwiftUI `View` structs rendered
off-screen by `ImageRenderer` in `ShareCardExporter.swift`. Keep that architecture; only
the `body` of each `*ShareCard` struct changes.

The prototype uses Google web fonts (Nunito / Manrope / JetBrains Mono) only because a
browser can't call SF fonts reliably. **In SwiftUI, use the native equivalents — do NOT
add web fonts:**

- Nunito (rounded display)  →  `.font(.system(size:, weight:, design: .rounded))`
- Manrope (values/body)     →  `.font(.system(size:, weight:))`  *(default design)*
- JetBrains Mono (labels)   →  `.font(.system(size:, weight:, design: .monospaced))`

This matches what the current cards already do (`design: .rounded` for titles,
`design: .monospaced` for labels).

## Fidelity
**High-fidelity.** Colors, type scale, spacing, and radii below are final. Recreate
pixel-for-pixel in SwiftUI. All sizes are given in **points in the card's own coordinate
space** (the card is framed at its export size, e.g. 1080 pt wide, before `ImageRenderer`
scales it). Use these point values directly.

---

## Design Tokens

### Colors
| Token                 | Value (hex)  | SwiftUI                                            | Use |
|-----------------------|--------------|----------------------------------------------------|-----|
| Background base       | `#121214`    | `Color(red: 0.07, green: 0.07, blue: 0.08)`        | Card background (existing) |
| Background top tint   | `#191920`    | `Color(red: 0.098, green: 0.098, blue: 0.125)`     | Top of optional radial |
| Background bottom     | `#0F0F12`    | `Color(red: 0.059, green: 0.059, blue: 0.071)`     | Bottom of optional radial |
| Surface / card        | `#1F1F24`    | `Color(red: 0.12, green: 0.12, blue: 0.14)`        | All inner cards/panels |
| Surface elevated      | `#292930`    | `Color(red: 0.16, green: 0.16, blue: 0.19)`        | Image placeholder fill |
| **Amber gold**        | `#D9AB61`    | `Color.amberGold` *(existing)*                     | Primary accent, labels, #1 |
| Amber light           | `#F0D29A`    | `Color(red: 0.94, green: 0.824, blue: 0.604)`      | Highlight / gradient top |
| Text primary          | `#FFFFFF`    | `.white`                                           | Values, model names |
| Text secondary        | `#8B8B92`    | `Color(red: 0.545, 0.545, 0.573)`                  | Brand eyebrow, units |
| Text tertiary         | `#7F7F87`    | `Color(red: 0.498, 0.498, 0.529)`                  | Section eyebrows |
| Text muted            | `#6F6F77`    | `Color(red: 0.435, 0.435, 0.467)`                  | Footer, ref number |
| Hairline border       | `#FFFFFF @ 6%`  | `.white.opacity(0.06)`                          | Card borders |
| Divider               | `#FFFFFF @ 7%`  | `.white.opacity(0.07)`                          | Grid cell dividers |
| Amber border (pill)   | `#D9AB61 @ 38%` | `.amberGold.opacity(0.38)`                      | Outline pills |
| Amber fill (pill)     | `#D9AB61 @ 7–12%` | `.amberGold.opacity(0.07)` / `0.12`           | Pill / stat backgrounds |
| Track (empty bar)     | `#FFFFFF @ 5%`  | `.white.opacity(0.05)`                          | Leaderboard bar track |

**Amber tonal ramp** (used for the leaderboard bars, ranked bright → dark):
`#F0D29A` → `#D9AB61` → `#C89A53` → `#B0863F` → `#8F6D34`.
Bar #1 uses a gradient `#A87E3F → #F0D29A`; ranks 2–5 use the flat ramp colors above.

### Background
The mock uses a subtle radial gradient (top-center highlight) for depth:
`RadialGradient(colors: [#191920, #131317, #0F0F12], center: .top, startRadius: 0, endRadius: ~1200)`.
This is optional polish — the flat `#121214` the cards use today is acceptable if a
gradient is inconvenient.

### Typography scale (points, in-card space)
| Role                        | Family / design | Weight  | Size | Tracking |
|-----------------------------|-----------------|---------|------|----------|
| Header title                | rounded         | .heavy(800) | 50 | -0.8 |
| Section eyebrow             | monospaced      | .semibold/.bold | 15 | ~3.5 |
| **Hero eyebrow (enlarged)** | monospaced      | .bold   | **27** | ~4 |
| Brand eyebrow               | monospaced      | .semibold | 18–20 | 2.5 |
| Model name (hero focal)     | default         | .heavy  | 74 | -1.5 |
| Model name (leaderboard/spec)| default        | .heavy  | 30 | — |
| Stat / metric value         | default         | .heavy  | 44–46 | — |
| Spec value                  | default         | .bold   | 28 | — |
| Card micro-label            | monospaced      | .bold   | 12–13 | 1.2–1.5 |
| Rank numeral                | rounded         | .black(900) | 52 | — |
| Footer / caption            | monospaced      | .semibold | 15 | 2 |
| Unit suffix (mm, m, days)   | default         | .semibold | 16–21 | — (secondary color) |

### Radii, spacing, shadows
- Outer content padding: **64 pt** top/sides, **56 pt** bottom (`.padding()` on the root VStack).
- Featured/hero card radius: **30**; image inside: **28**; stat/spec cards: **22–24**; pills: **capsule**; dots & bar caps: **5–8**.
- Featured card shadow: `color: .black.opacity(0.45), radius: 30, y: 30` + a 1 pt top inner highlight (`.white.opacity(0.05)`).
- Featured card border: **1 pt `amberGold.opacity(0.22)`** (this is the "winner" cue).
- Plain cards border: **1 pt `.white.opacity(0.06)`**.
- Glow on #1 elements (medal, top bar, rank numeral): amber shadow `radius: ~18, opacity 0.4–0.5`.

---

## Screens / Views

### 1. Rewind Share Card  (`RewindShareCard`, 1080 × 1350)
**Purpose:** Poster of the user's collection rewind; the "most worn watch" is the hero.

**Layout** — vertical stack, `.padding(64/56)`, root aligned leading:
1. **Header row** (`HStack`, top-aligned, `Spacer()` between):
   - Left `VStack`: eyebrow `COLLECTION INSIGHT` (mono 15, tertiary, tracked 3.5) → title `WristScan Rewind` (rounded 50, heavy).
   - Right: **period pill** (capsule, `amberGold.opacity(0.07)` fill, `0.38` amber border, 11×20 padding) containing a 7 pt amber dot (with amber glow) + `THIS YEAR` (mono 15, amber, tracked 2).
2. **Hero section** (spacing 20), grows to fill:
   - Eyebrow `MOST WORN WATCH` — **mono 27, bold, amber, tracked 4** (this is the enlarged label the user asked for).
   - **Featured card** (surface `#1F1F24`, radius 30, amber `0.22` border, big shadow):
     - **Watch image** filling the card top, height **626 pt**, `.scaledToFill` clipped, `object-position ≈ center 40%` (in SwiftUI: `.scaledToFill().frame(height:626).clipped()` — align so the whole watch is visible; the source photo already frames the full watch). A bottom scrim gradient (`clear → #1F1F24`) fades the image into the caption.
     - **`#1` medal**, absolute top-left (24,24): amber capsule holding a 34 pt dark circle with amber `1` (rounded, heavy) + `TOP PICK` (mono 13, dark `#171512`, tracked 1.5).
     - **Caption** (`HStack`, bottom-aligned, padding 30/44/40): left `VStack` = brand `CITIZEN` (mono 18, secondary, tracked 2.5) + model `Nighthawk` (default 74, heavy, line 0.95); right = amber-fill rounded stat (radius 18, `amberGold.opacity(0.12)` fill, `0.22` border) with `15` (44, heavy, amber) over `WRIST CHECKS` (mono 12, amber, tracked 1.5).
3. **Spacer** (flex) so the stat card + footer sit at the bottom.
4. **Stat card** — one surface card, radius 28, hairline border, a **4-column grid** (`TOTAL WEARS 51`, `LONGEST STREAK 11 days`, `WATCHES WORN 5`, `TOP BRAND Rolex`). Each cell: mono 13 amber label (tracked 1.5) + value (default 46, heavy). Cells 2–4 have a leading `1 pt .white.opacity(0.07)` divider. Units (`days`) render at 21 pt in secondary color.
5. **Footer** (`HStack`): a 22 pt amber ring "watch mark" (circle stroke + a small hand) + `CAPTURED WITH WRISTSCAN` (mono 15, muted, tracked 2).

**Key change vs. current:** the winner is now an elevated, amber-bordered card with a photo hero + medal (was a flat box), and the four pills became one unified 4-cell stat card with dividers.

### 2. Watch Spec Card  (`WatchDetailShareCard`, 1080 × 1600)
**Purpose:** Single-watch spec sheet.

**Layout** — vertical stack, `.padding(64/56)`:
1. **Header** (`HStack`): left `VStack` = eyebrow `WATCH SPEC SHEET` (mono 15, tertiary) → brand `CITIZEN` (mono 20, amber, tracked 3) → model `Nighthawk` (rounded 62, heavy) → `REF · BJ7000-52E` (mono 17, muted). Right = **wrist-check pill** (capsule, amber outline): `WRIST CHECK` (mono 15, amber) · 1 pt divider · `16` (default 22, heavy, white).
2. **Hero image**, full width, height **470**, radius 28, hairline border, big shadow. *(In the app this is the watch's `heroImage`; keep the existing `UIImage` binding. If none, keep the current placeholder: elevated `#292930` fill + amber clock glyph.)*
3. **Specifications** — eyebrow `SPECIFICATIONS` (mono 15, tertiary) + a surface card (radius 24) laid out as a **3-column × 2-row grid** of spec cells: `CASE MATERIAL / CASE SIZE / WATER RESIST` on top, `LUG TO LUG / LUG WIDTH / WATCH TYPE` below. Each cell: mono 12 amber label (tracked 1.2) + value (default 28, bold); units at 16 pt secondary. Interior dividers: `.white.opacity(0.07)` (top row bottom-border, and leading borders on columns 2–3).
4. **Wear frequency** — eyebrow row: `WEAR FREQUENCY` (mono 15, amber) with `LAST 12 MONTHS` (mono 13, muted) right-aligned. Then a surface card (radius 24, height 210) containing **12 vertical bars** (`HStack`, bottom-aligned): each bar is a rounded rect (radius 5) filled `linear #A87E3F → #D9AB61`, height ∝ that month's count, with a mono 12 month-initial label under it. The most recent / peak month is brighter (`#D9AB61 → #F0D29A`) with an amber glow. *(Bind to the existing `chartData: [MonthlyWearLog]`; replace the Swift `Chart`/`BarMark` with this custom bar row, or keep `Chart` but restyle — see note below.)*
5. **Spacer**, then a **2-cell footer stat row** (`TIMES WORN 16`, `LAST WORN Jan 30, 2026`) as two surface cards (radius 22), amber mono labels + values (44 / 32 heavy).
6. **Footer mark**: amber ring + `CAPTURED WITH WRISTSCAN`.

> **Chart note:** you may keep Swift Charts `BarMark` for the wear-frequency chart if
> preferred — just restyle: `.foregroundStyle(Color.amberGold.gradient)`, `cornerRadius(5)`,
> hide gridlines/axis borders, use monospaced 12 pt axis labels in `#6F6F77`, and highlight
> the latest bar. The custom `HStack` of bars in the mock is only there because HTML has no
> Swift Charts.

### 3. Top Wrist Checks Card  (`WearChartShareCard`, 1080 × 1350)
**Purpose:** Ranked leaderboard of the 5 most-checked watches (replaces the vertical bar chart with rotated labels).

**Layout** — vertical stack, `.padding(64/56)`:
1. **Header**: eyebrow `WRISTSCAN INSIGHTS` (mono 15, tertiary) → title `Top Wrist Checks` (rounded 50, heavy); right = period pill `THIS YEAR` (same as Rewind).
2. **Leaderboard card** — one surface card (radius 30, hairline border, big shadow, padding 20/44), a `VStack` that distributes 5 rows evenly (`justify-content: space-around`). Each **row** (`HStack`, center-aligned, gap 30, 22 pt vertical padding, `.white.opacity(0.06)` bottom divider except last):
   - **Rank numeral** (rounded 52, black), width 62. `#1` is `amberGold` with an amber text-glow; ranks 2–5 are `#55555D`.
   - **Middle `VStack`** (grows): a baseline `HStack` of model name (default 30, heavy, white) + brand (mono 15, secondary, tracked 1.5); below it a **progress bar** — 14 pt tall track (`.white.opacity(0.05)`, radius 8) with a fill (radius 8) whose width = `count / maxCount`. Fill color by rank: #1 gradient `#A87E3F → #F0D29A` + amber glow; #2 `#D9AB61`; #3 `#C89A53`; #4 `#B0863F`; #5 `#8F6D34`.
   - **Count** (default 44, heavy, white), right-aligned, fixed width 110.
3. **Footer** (`HStack`, space-between): amber ring + `CAPTURED WITH WRISTSCAN` on the left; on the right `TOTAL` (mono 14) · `49` (default 24, heavy, amber) · `CHECKS` (mono 14).

**Sample data** (top 5 by wrist checks): Citizen Nighthawk 15 · Rolex Submariner 11 · Seiko SKX007 9 · Omega Speedmaster 8 · Tudor Black Bay 6. Bar widths = 100% / 73.3% / 60% / 53.3% / 40%. Wire these to the real `distribution` array; `maxCount` is the top entry.

---

## Interactions & Behavior
These are **static images** rendered by `ImageRenderer` — no interaction, hover, or animation.
The only "live" behavior is that all copy and numbers are data-bound to the report/metrics
already passed into each card struct (`RewindMetrics`, the watch model, the analytics
`distribution`). No new state, navigation, or data fetching is introduced.

## State Management
No new state. Reuse the existing inputs each `*ShareCard` already receives from
`RewindView` / `WatchDetailView` / `AnalyticsDashboardView`. The share/save plumbing in
`ShareCardExporter.swift` (`prepareAndShare`, `ImageRenderer`, `exportSize`) is unchanged —
export sizes stay 1080×1350 (Rewind, Top Checks) and 1080×1600 (Spec).

## Assets
- `assets/nighthawk_full.jpg` — sample watch photo used in the Rewind + Spec mocks (cropped
  from the user's own detail-screen screenshot). In production, use the watch's real
  `heroImage`/`winningWatchImage` `UIImage` — this file is only for visual reference.
- The small "watch mark" in footers is drawn with primitives (a stroked circle + one hand),
  not an asset — recreate with `Circle().stroke` + a small `Capsule`, or swap for an
  existing app glyph/logo if one exists.
- No icon fonts or external images are required.

## Screenshots
Full renders of each card (the visual target) are in `screenshots/`:
- `screenshots/1-rewind.png` — Rewind Share Card
- `screenshots/2-watch-spec.png` — Watch Spec Card
- `screenshots/3-top-wrist-checks.png` — Top Wrist Checks Card

## Files (in this bundle)
- `Rewind Share Card.dc.html` — Rewind card reference
- `Watch Spec Card.dc.html` — Watch spec sheet reference
- `Top Wrist Checks Card.dc.html` — Leaderboard reference
- `assets/nighthawk_full.jpg` — sample photo
- `image-slot.js`, `support.js` — runtime for the HTML prototypes (needed only to open the
  `.dc.html` files in a browser; **not** part of the SwiftUI implementation)

To view a prototype: open any `.dc.html` in a browser (the two `.js` files must sit beside
it). They render at full export size.
