# blackmatter-ayatsuri — Claude Orientation

One-sentence purpose: home-manager module for ayatsuri — macOS window manager
+ Rhai-scripted automation + MCP control surface.

## Classification

- **Archetype:** `blackmatter-component-hm-only`
- **Flake shape:** `substrate/lib/blackmatter-component-flake.nix`
- **Option namespace:** `blackmatter.components.ayatsuri`
- **Upstream:** `github:pleme-io/ayatsuri` (consumed via flake input, overlay merged in)

## What NOT to do

- Don't fork ayatsuri's binary logic here. This is the HM *wrapper* — config
  generation, launchd agent wiring, Rhai script installation.
- Don't hardcode monitor/workspace counts. Rhai config is user-side.
