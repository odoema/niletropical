# CHANGES — P2 Design System

## Summary
Full design-system rebuild per master contract §1–3, §34.

## Theme & tokens
- **Primary colour** changed from tropical green `#1B5E20` → deep Nile blue `#233E85`.
- **Font** switched to Poppins via `google_fonts: ^6.2.1` (runtime download; Roboto fallback offline).
- New token files:
  - `lib/core/theme/nile_colors.dart` — brand + semantic colours (success `#1F7A4D`, warning `#B7791F`, error `#B42318`).
  - `lib/core/theme/nile_spacing.dart` — 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 scale.
  - `lib/core/theme/nile_radius.dart` — 4 / 8 / 12 / 16 / 24 / full.
  - `lib/core/theme/nile_typography.dart` — Display → Button scale on Poppins.
- `lib/core/theme/app_theme.dart` — complete ThemeData rebuild (Material 3, buttons, inputs, cards, nav, etc.). Old `AppColors` class removed; consumers should import `NileColors` / `AppTheme`.

## Reusable components (`lib/core/widgets/`)
19 Nile* widgets:
1. nile_app_bar.dart
2. nile_button.dart
3. nile_outlined_button.dart
4. nile_text_field.dart
5. nile_dropdown.dart
6. nile_card.dart
7. nile_price.dart
8. nile_badge.dart
9. nile_empty_state.dart
10. nile_error_state.dart
11. nile_loading_state.dart
12. nile_dialog.dart
13. nile_section_header.dart
14. nile_status_chip.dart
15. nile_bottom_navigation.dart
16. nile_side_navigation.dart
17. nile_data_table.dart
18. nile_search_field.dart
19. nile_confirm_dialog.dart

Barrel: `lib/core/widgets/nile_widgets.dart`.

## Showcase
- `lib/features/design_system/design_system_showcase.dart` — single screen rendering every token and component for visual review (dev / allowMockData).

## pubspec
- Added `google_fonts: ^6.2.1`.

## What is NOT in this deliverable
- App shell / routing / feature screen restyles (P3+).
- Backend migrations.
- Screens that previously referenced `AppColors` need import migration in later phases.

## Status vs §56 execution order
- Step 1 Audit — done (previous turn)
- Step 2 Design system — **this turn (P2)** ✅
- Step 3 App shell — next
