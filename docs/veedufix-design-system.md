# VeeduFix Flutter design system

This is the shared UI standard for the Customer, Partner, and Admin Flutter
apps. The live source of truth for color, type, spacing, shape, and motion is
`marketplace_shared/lib/core/theme/veedufix_design_system.dart` and the shared
theme in `core/theme/abzio_theme.dart`. `AbzioTheme` remains as a compatibility
name for existing code; new UI should use the VeeduFix semantic tokens.

## Product feel

Build a calm, premium nationwide home-services marketplace. Use warm ivory,
charcoal, warm gray, and the existing gold accent. Use Outfit for interface
text and the existing Cormorant display face sparingly. Let spacing, alignment,
typography, useful imagery, and clear hierarchy do the work. Keep surfaces
quiet, use borders or very soft elevation only when they clarify grouping, and
avoid decoration without a functional purpose.

## Shared rules

- Prefer shared VeeduFix components and semantic tokens over one-off styling.
- Use the spacing scale 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, and 56 dp.
- Use 12 dp small, 16 dp medium, and 18–20 dp large corner radii. Keep controls
  at least 44 dp high; primary actions are 54 dp and inputs target 52–56 dp.
- Use 16 dp mobile page margins by default. Let layouts adapt to narrow widths;
  do not position complete screens with fixed coordinates.
- Keep body copy at 14–15 sp, section headings at 17–20 sp, and screen titles
  at 22–26 sp. Reserve bold weights for emphasis.
- Keep loading, empty, and error states intentional and actionable. Reuse the
  existing network image/cache and shimmer utilities where appropriate.
- Render Admin-controlled catalog, price, availability, and promotional data
  from backend/CMS models. Do not hardcode mutable catalog content in widgets.
- Avoid default floating Material cards, generic app bars or navigation,
  oversized pills, arbitrary gradients, heavy shadows, and excess gold.

## Components

Use `VeeduFixButton`, `VeeduFixSecondaryButton`, `VeeduFixCard`,
`VeeduFixSectionHeader`, and `VeeduFixBottomNav` from
`marketplace_shared.dart` when their semantics match. The shared
`InputDecorationTheme` sets the standard field treatment; use it for ordinary
fields and add a reusable shared component if a recurring field pattern needs
behavior beyond decoration. Existing reusable marketplace components such as
network image widgets, shimmer widgets, and `PremiumEmptyState` should be
preferred over screen-specific duplicates.

## Screen workflow

Before a UI change, identify the screen's goal, primary content, primary action,
and secondary actions. Inspect the screen and shared widgets first; preserve
working behavior and data flows. Implement in shared components where a pattern
will recur. Review the rendered screen at 320, 360, 375, 390, and 412 dp when
the environment supports it. Check safe areas, scrolling, keyboard behavior,
text wrapping, image crop, touch targets, and loading/error/empty states.

## Extending the system

Add colors, spacing, radii, or reusable UI patterns to the shared design-system
files instead of creating screen-local visual standards. Update this guide
when a lasting rule changes. Admin, Partner, and Customer surfaces may differ
in information density and workflows, but should retain the same brand tokens
and component language.
