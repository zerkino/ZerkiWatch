# ZerkiWatch design system (v7 draft)

Starting point: the colours and fonts that already exist in `ZerkiWatch.bat` and in the iPhone page.
The goal is to **refine and name** them, not to redesign the app. Every value below is either
taken from the code (marked *existing*) or is a proposal for the light theme / new states (marked *new*).

## 1. Principles
1. **Status first.** The one thing the user must see at a glance is the network mode: INTERNET or LOCAL.
2. **Calm, dense, readable.** Dark navy surfaces, one accent per meaning, numbers set in a semibold face with tabular figures.
3. **Colour means something.** Green = fine / Internet reachable, amber = local mode / warning, red = cut / error, blue + violet = download / upload. No decorative colours.
4. **Same system everywhere.** Main window, bar, widget, dialogs, menus and the iPhone page use the same tokens.
5. **Restraint in motion.** Short, useful, never blocking. None on frequent actions. Reduced-motion is respected on the iPhone page.
6. **Accessible by default.** Contrast, visible focus, full keyboard use, readable at 125 % and 150 % Windows scaling.

## 2. Colour tokens

| Token | Dark (existing) | Light (new) | Use |
|---|---|---|---|
| `bg` | `#0A0E1C` (10,14,28) | `#F4F6FB` | window background |
| `surface` | `#131A30` (19,26,48) | `#FFFFFF` | cards, menus |
| `surface-top` | `#1C2646` (28,38,70) | `#EEF2FA` | top of card gradient, hover |
| `border` | `#263256` (38,50,86) | `#D5DCEB` | card and control borders |
| `text` | `#F0F4FF` (240,244,255) | `#0F172A` | main text |
| `muted` | `#8A96B8` (138,150,184) | `#5B6785` | labels, units, secondary text |
| `ok` | `#34D399` (52,211,153) | `#0E9F6E` | Internet reachable, low load |
| `warn` | `#FBBF24` (251,191,36) | `#B45309` | local mode, medium load |
| `bad` | `#F87171` (248,113,113) | `#DC2626` | cut, errors, high load |
| `down` | `#38BDF8` (56,189,248) | `#0284C7` | download |
| `up` | `#A78BFA` (167,139,250) | `#7C3AED` | upload |
| `gpu` | `#F472B6` (244,114,182) | `#DB2777` | GPU gauge |
| `disk` | `#FBBF24` | `#B45309` | disk gauge |
| `ram` | `#2DD4BF` (45,212,191) | `#0D9488` | RAM gauge |

Floating bar (existing): gradient `#1A2444` → `#0A0E1C`, border `#2C3A62`, rounded corners (10 px at 100 %).
Rule: the light-theme values must keep **4.5:1** contrast for text and **3:1** for graphics against their background (to be checked in step 6).

## 3. Typography
- Family: **Segoe UI** (Segoe UI Variable is not assumed to exist on Windows 10). iPhone page: system font stack.
- Existing sizes (pt, Windows): big number 20 semibold, percentage 17, bar value 17, bar percentage 15, row 9.5, small 9, card title 8.5 semibold with letter-spacing, window title 13.
- Scale (proposal): 8.5 caption / 9 small / 9.5 body / 13 section title / 17 value / 20 hero.
- Numbers: semibold, fixed decimals (`0.0` below 100, `0` above) so they do not jump. iPhone page: `font-variant-numeric: tabular-nums`.
- Capitalised small titles keep their wide letter-spacing (`.16em` on the iPhone page).

## 4. Spacing, shape, depth
- Base unit **4 px**; common steps 8 / 12 / 16 / 24.
- Cards: 16 px padding, 1 px border, radius 20 px on the iPhone page, 10–12 px on Windows.
- Depth by **border and a subtle top gradient**, not by heavy shadows (only the big iPhone switch has a shadow).
- Dialogs: 20 px outer margin, buttons 110 x 30 px minimum, primary button on the right.
- Touch targets on the iPhone page: **44 px** minimum.

## 5. Components and states
| Component | Default | Hover | Pressed | Focus | Disabled |
|---|---|---|---|---|---|
| Button (flat) | `surface` + `border` | `surface-top` | slightly darker | 2 px `down` outline | 40 % opacity |
| Menu item | `surface` | `surface-top` | `surface-top` | same as hover | `muted` |
| Toggle (main switch) | green = Internet, red = cut | slight lift | — | outline | grey while busy |
| Gauge ring | track `#2C344E`, colour by load (`ok` < 60 %, `warn` 60–85 %, `bad` ≥ 85 %) | tooltip | — | — | `muted` when no data |
| Dialog field | `surface` + `border` | `border` lighter | — | `down` outline | `muted` |

Mode indicator (bar, widget, main window, iPhone): dot **and** word. Green dot + `INTERNET`, amber dot + `LOCAL`; the word is translated and never replaced by colour alone.

## 6. Motion
- Duration 120–250 ms, `ease-out`; never above 300 ms.
- Allowed: window/tab fade-in, switch knob slide (already 250 ms on the iPhone page), notification appearance, mode colour crossfade.
- Not allowed: animation on every metric update, on keyboard shortcuts, or anything that loops.
- Windows: no additional timers; reuse the existing 1 s monitor tick and draw only what changed.
- iPhone page: `@media (prefers-reduced-motion: reduce)` removes transitions.

## 7. Signature element
A **thin gradient line under the bar** (download blue → GPU pink, already drawn at the bottom of the floating bar), reused as the underline of the active tab, the top edge of cards and the page header on the iPhone. It is the only decorative element.

## 8. Layout notes
- Main window: 1080 x 560 (client), cards in a grid; step 7 groups the content in tabs without changing the panels themselves.
- Bar / widget: 650 x 46 at 100 %, scale 85 / 100 / 125 %.
- Dialogs: 380 x 190 (PIN) and 520 x 700 (certificate); keep text areas large enough for German strings.
- iPhone page: single column, max width 460 px, safe-area insets respected.

## 9. Checks before each release
- Contrast of every token pair in both themes.
- Keyboard: Tab order, Enter / Esc in each dialog, visible focus.
- 100 %, 125 %, 150 % scaling; one and two monitors.
- Longest strings (German) fit without clipping.
- iPhone page: Safari, dark and light, reduced motion, 44 px targets.
