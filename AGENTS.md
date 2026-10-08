# VeeduFix Flutter UI standard

For every UI change in this repository, follow [the VeeduFix design system](docs/veedufix-design-system.md).

- Inspect the current screen and shared Flutter theme/components before editing.
- Use semantic tokens and reusable `marketplace_shared` components. Extend a shared component when a pattern recurs; avoid duplicate screen-local styling.
- Preserve existing behavior and data flows while improving the visual hierarchy and interaction states.
- Keep customer, Partner, and Admin surfaces in the same brand system while adapting their layouts to their tasks.
- Do not hardcode Admin-controlled catalog, pricing, availability, or promotion content in Flutter UI.
- For visual changes, review the rendered screen at the supported mobile widths and correct layout, safe-area, keyboard, and overflow issues when a runnable environment is available.
