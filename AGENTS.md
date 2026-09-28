# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.
- Never commit `.no-mistakes/` validation evidence to this public repo. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.
- **Extension keyboard shortcuts need a local patch, because pi has no config hook for them.** `getShortcuts()` in pi's `dist/core/extensions/runner.js` only consults user keybindings to detect clashes with *built-in* bindings, then lets the last-registered extension win (`extensionShortcuts.set`), reporting the collision in the `[Extension issues]` startup banner. So package order in `home/.pi/agent/settings.json` is load order, and the last pin listed wins a duplicate key. `pi-powerline-footer` is worse: it intercepts keys inside the editor and returns early, so it beats `pi.registerShortcut` with no warning at all, and swallows the press when the editor is empty - always check `powerlineShortcuts` in the linked `settings.json` before assigning a key. `Ctrl+Alt+C` is settled by patch rather than by order: `pi-background-tasks` is moved to `Ctrl+Alt+N` and powerline's copy-editor-text to `Ctrl+Alt+E`, leaving `@haphazarddev/pi-copy-code-block` as the only owner. Do not resolve a new collision by reordering that array before checking whether `pi-extension-patches` already covers it.
- **Two installed packages are patched in place, and `pi-extension-patches` is the authority for both.** `~/.pi/agent/npm/node_modules/pi-powerline-footer/segments.ts` - upstream hardcodes a per-character rainbow for `think:high|xhigh|max` (`RAINBOW_COLORS` in `theme.ts`) with no config option, theme key, env var, or status key that avoids it; the patch makes that segment follow the active theme via `thinkingHigh|Xhigh|Max`. `pi-background-tasks/dist/src/extension.js` - duplicate `Ctrl+Alt+C`, moved to `Ctrl+Alt+N`. Both edits live in pi's own unmanaged package trees, so an update or reinstall silently reverts them: run `pi-extension-patches` after changing any pinned version. That script holds the patch text for both, so the older `segments.ts.orig-patched` backup is redundant.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
