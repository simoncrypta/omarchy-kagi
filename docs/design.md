# kagi-search: design

Checked against `omarchy 4.5.0-3` and Hyprland 0.56.2 on 2026-11-08. Paths
below are relative to `/usr/share/omarchy` unless they start with `~`.

## What the plugin mechanism can and cannot do

A third-party plugin is a folder in `~/.config/omarchy/plugins/<id>/` with a
`manifest.json`. `omarchy plugin add <git-url>` clones it into a stage,
validates it, moves it to `<id>` and rescans the shell
(`bin/omarchy-plugin-add:119-150`). `omarchy plugin remove <id>` disables it if
enabled, deletes a git checkout and rescans (`bin/omarchy-plugin-remove:74-117`).
`file://` URLs are accepted (`bin/omarchy-git-url-check`, `TRANSPORTS`).

The manifest only describes QML for the shell to load: `kinds` from `bar`,
`bar-widget`, `menu`, `overlay`, `panel`, `service`, each with its entry point
(`bin/omarchy-plugin-validate:97-109`; `shell/services/PluginRegistry.qml:43-90`
reads nothing else). So:

- **Keybindings: not possible.** No manifest field, and Hyprland loads only
  Omarchy's defaults, the theme, toggles and the user's `~/.config/hypr/*.lua`
  (`default/hypr/omarchy.lua`, and the stock `config/hypr/hyprland.lua:14-23`).
  The documented place for a user binding is
  `~/.config/hypr/bindings.lua` (header of the stock `config/hypr/bindings.lua`).
- **Menu rows: not possible.** The menu reads exactly two files, the packaged
  default and `~/.config/omarchy/extensions/omarchy-menu.jsonc`
  (`shell/plugins/menu/Menu.qml:56-57`). Providers are a closed list
  defined in that file (`Menu.qml:318-358`); an unknown name is ignored
  (`Menu.qml:418-419`).
- **No install or remove hook.** `plugin add` and `plugin remove` run no code
  from the plugin.

So the user adds the binding and the menu rows by hand, from snippets in the
README, the way Omarchy expects any personal binding. Other third-party
plugins work the same way: none of them edits these files. Install is
`omarchy plugin add` plus two pastes; uninstall is deleting those lines and
`omarchy plugin remove`.

The manifest has to name a kind with an entry point, so it declares a
`service` with an empty `Service.qml`. A manifest whose only kind is one
Omarchy does not know, with no entry points, also validates today
(`bin/omarchy-plugin-validate:95-96`: "a kind not listed is left alone"), but
that leans on unlisted behaviour a later release could refuse; an empty
service is a plugin every release accepts. The plugin does not need to be enabled:
nothing in it runs inside the shell, and leaving it disabled keeps
`~/.config/omarchy/shell.json` untouched (enabling writes the id into
`plugins[]`; `PluginRegistry.qml:148-163` reads it back).

## Id

`kagi-search`. Not `omarchy.*` (reserved, `bin/omarchy-plugin-validate:53`),
not a personal namespace, and not `kagi.*`, which would read as published
by Kagi.
It matches the id pattern in `omarchy-plugin-validate:51`.

## Commands

`bin/kagi` (bash; `jq`, `wl-clipboard` and the Omarchy commands below):

| Command | Does |
|---------|------|
| `kagi search` | `omarchy-menu-input "Kagi"`. Cancel (exit 1) or empty/blank input: nothing. Otherwise `omarchy-launch-browser "https://kagi.com/search?q=<@uri query>"`. |
| `kagi summarize` | `wl-paste --no-newline --type text`, trimmed. If it is one `http(s)://` URL with no whitespace: `omarchy-launch-browser "https://kagi.com/summarizer/index.html?url=<@uri url>"`. Otherwise `omarchy-notification-send` "Clipboard has no URL" and nothing opens. |

Encoding is jq's `@uri`, which escapes everything but `A-Za-z0-9-_.~`, so
`!`, `?`, `&`, `#`, `+`, quotes and spaces are all percent-encoded and UTF-8 is
encoded byte by byte. Bangs, snaps and the trailing `?` Quick Answer are plain
query text to Kagi, so they need nothing special.

### The `omarchy-menu-input` contract

From `bin/omarchy-menu-input:37-58` and `finishRequest` in
`shell/plugins/menu/Menu.qml:144-160`:

- Escape on an empty field writes nothing to the selection file: the command
  exits 1. With text in the field, Escape first clears it
  (`Menu.qml:1337-1339`).
- Enter writes `printf '%s\n' <text>`: the command prints the text and exits 0.
  Enter on an empty field prints an empty line and **exits 0**, so the caller
  must treat blank input itself.

### Snippets

The README's binding and menu rows call
`~/.config/omarchy/plugins/kagi-search/bin/kagi`. The `~` expands because
Hyprland runs a bind's command through a shell (stock binds use `||`,
`default/hypr/bindings/utilities.lua:42`) and menu actions run through
`bash -lc` (`shell/Commons/Util.qml:68-70`).

### The chord: SUPER + SHIFT + K

Stock Omarchy binds nothing to SUPER + SHIFT + K (no match in
`default/hypr/**/*.lua`), and K is for Kagi. SUPER + SHIFT + S, the first
choice, is Google Maps by default (`default/hypr/bindings/applications.lua:35`).
`o.bind` on a chord that is already bound adds a second action rather than
replacing the first (`default/hypr/helpers.lua:138-152`), so the README tells
users to check with `omarchy menu keybindings --print` and use `o.rebind` to
replace.

## Cloned menus

`omarchy-menu-input` summons `omarchy.menu`; if the user has cloned the menu
with `omarchy plugin clone omarchy.menu`, the registry routes the call to the
enabled clone (`shell/services/PluginRegistry.qml:171-182`). The plugin relies
only on input mode (`mode: "input"`, a prompt, and the selection and done
files), which clones keep from the copy they were made from. A clone made from
an older Omarchy may lack later menu features such as `--multiple`; the
plugin uses none of them.

## Surviving `omarchy update`

- Nothing lives under `/usr/share/omarchy`, which the package replaces.
- The plugin folder is a user git checkout; nothing in `bin/omarchy-update*`
  touches `~/.config/omarchy/plugins` (the only mention of plugins is the
  reload message in `bin/omarchy-update-restart:67`).
- The plugin never reads or writes `shell.json`, so the Elsewhen-style
  migrations that rewrite it don't matter.
- Migrations that touch `bindings.lua` keep a user's added line:
  `migrations/1781485962.sh` replaces the file only when its sha256 equals a
  stock one (a file with an added binding never does), and
  `migrations/1793477875.sh` only appends.
- Only public commands are used: `omarchy-menu-input`,
  `omarchy-launch-browser`, `omarchy-notification-send`, and the `o.bind`
  helper that `bindings.lua` itself documents.
- `omarchy refresh hyprland` resets `bindings.lua` (it backs it up first,
  `bin/omarchy-refresh-hyprland:7`). That is the user's choice; paste
  the binding again afterwards.
