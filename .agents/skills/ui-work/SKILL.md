---
name: ui-work
description: Use when changing FlClash Flutter UI, widgets, screens, glass styling, navigation surfaces, async feedback, or user-facing interactions.
---

# UI Work

## When To Use

Use this for user-facing Flutter UI changes in `lib/`, including widgets, screens, navigation surfaces, settings rows, dialogs, and interaction behavior.

## Workflow

1. Locate existing nearby widgets and reuse their patterns before adding new abstractions.
2. Follow the minimal visual language (`docs/features/glass-ui.md`, ADR 0016): neutral opaque surfaces, generous
   spacing, large connection status and restrained blue primary actions. Use shared shapes and `ColorScheme` roles. Existing `Glass*` wrappers are compatibility
   interfaces; do not reintroduce blur or specular effects. Appearance does not branch on the platform.
3. Use existing providers, notifiers, and helpers where possible.
4. Keep `child:` last in widget constructors.
5. Prefer `const` constructors and final locals.
6. Localize user-facing text through ARB; use `localization` when text changes are non-trivial.
7. Add focused widget tests when behavior changes, especially for rendering states, taps, scrolling, and empty/error states.
8. For asynchronous controls, define separately:
   - authoritative provider/domain state;
   - display-only state such as a minimum progress duration;
   - tap policy while work or display holds are active;
   - failure/disposal cleanup, normally in `finally` for animations and timers.
9. Run targeted verification:

   ```bash
   flutter analyze
   flutter test test/widgets/
   ```

## Shapes

All corner radii come from `lib/common/shape.dart`; never write a radius literal in a widget.

| Token | Value | Use |
| --- | --- | --- |
| `extraSmall` | 4 | small blocks inside a surface |
| `small` | 8 | text fields, badges, swatches |
| `medium` | 12 | compact controls and navigation rows |
| `large` | 16 | content tiles (`GlassSurface` default) |
| `extraLarge` | 28 | hero panels, dialogs, sheets |
| `full` | 1000 | pills, segmented tracks, the dock |

`AppShape` uses `RoundedRectangleBorder`; `AppRadius` supplies matching radii for clips and
decorations. Nested radii are derived, never tokens: `outer = inner + inset`.

## Motion

Use `Durations.*` and `Easing.*` only; see `.agents/rules.md` ("Shapes and Motion"). Avoid decorative continuous animations; hidden pages and unchanged charts should be idle.

## Pitfalls

- Do not introduce a new visual system for one screen.
- Do not manually edit generated localization or provider files.
- Avoid broad layout rewrites unless the requested change requires them.
- Do not mutate provider/domain state merely to smooth a transition. Keep presentation holds local and let real errors
  bypass them immediately.
- Do not leave loading animations active when callbacks throw. Test the exception path, not only the successful tap.

## Current Interaction Examples

- `CoreStatusButton` watches `coreStatusProvider` but keeps its 600-millisecond connecting hold locally. Taps are ignored
  during the hold or genuine connecting state; disconnected cancels the hold immediately.
- Proxy delay testing writes `0` while pending, the measured delay on success, and `-1` on failure. `DelayTestButton` resets
  its animation in `finally`.
