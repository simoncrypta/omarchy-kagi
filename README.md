# kagi-search

Omarchy plugin that hands a search to Kagi in your browser. You bring your own Kagi subscription. No API key.

Not affiliated with or endorsed by Kagi Inc. Kagi is a trademark of Kagi Inc.

## Requirements

Omarchy, `jq`, and `wl-clipboard`. The browser must already be signed in to Kagi.

## Install

```sh
omarchy plugin add https://github.com/simoncrypta/omarchy-kagi.git
```

A local clone works too: `omarchy plugin add file:///path/to/omarchy-kagi`.

Enabling is not needed: nothing here runs inside the shell, and the empty service exists only because a manifest kind needs an entry point.

Omarchy plugins can't add keybindings or menu rows, so add them yourself. Add the binding to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + K", "Kagi search", "~/.config/omarchy/plugins/kagi-search/bin/kagi search")
```

SUPER+SHIFT+K is free in stock Omarchy. Check yours with `omarchy menu keybindings --print`; if it is taken, pick another chord, or replace it with `o.rebind`.

For a Kagi submenu in the Omarchy menu, add these rows inside the outer `{ }` of `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
  "kagi": {"icon":"󰩃","label":"Kagi"},
  "kagi.search": {"icon":"󰍉","label":"Search","action":"~/.config/omarchy/plugins/kagi-search/bin/kagi search"},
  "kagi.summarize": {"icon":"󰈙","label":"Summarize clipboard URL","action":"~/.config/omarchy/plugins/kagi-search/bin/kagi summarize"},
```

Both files reload on save.

## Usage

SUPER+SHIFT+K opens a prompt titled Kagi. Enter opens the search. Escape, or Enter on a blank prompt, does nothing. With text in the prompt, the first Escape clears it and the second closes the prompt; that is how the Omarchy menu handles Escape.

A bang (`!w`), a snap (`@r`), or a trailing `?` is plain query text. Kagi interprets it.

The Kagi menu has Search and Summarize clipboard URL. Summarize opens the Summarizer when the clipboard is one `http(s)` URL, and otherwise shows a notification.

## Uninstall

Delete the binding and the menu rows you added, then:

```sh
omarchy plugin remove kagi-search
```

## Update

```sh
omarchy plugin update kagi-search
```

## Tests

```sh
tests/run.sh
```

Design: [docs/design.md](docs/design.md).
