<div align="center">

#  gitpulse

### Real-time GitHub dashboard & notification center for Omarchy

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-7aa2f7?style=flat-square&logo=archlinux&logoColor=white)](https://omarchy.org/)
[![Hyprland](https://img.shields.io/badge/hyprland-ready-56b6c2?style=flat-square)](https://hyprland.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-e5c07b?style=flat-square)](LICENSE)

*Track your PRs, review requests, CI runs, and inbox alerts directly from the Omarchy status bar.*

</div>

---

## Overview

**GitPulse** is a lightweight status bar widget and keyboard-driven popup panel for [Omarchy Linux](https://omarchy.org/). It connects to your existing GitHub CLI (`gh`) session to stream pull requests, CI/CD health checks, and unread notifications without background daemons or token juggling.

### Highlights

- **Live status bar pill:** Displays pending reviews, authored PRs, unread mentions, and urgent CI failure alerts (`✖`).
- **Keyboard-first popup:** Built-in Vim keybindings (`j`/`k`, `1-3`, `h`/`l`, `o`, `x`, `r`, `q`) and visual cursor tracking.
- **Zero-token auth:** Reads directly from your authenticated `gh` keyring.
- **Theme-reactive:** Inherits your active Omarchy color palette, borders, and corner radiuses automatically.

---

## Keyboard Navigation

When the popup is open, all actions are accessible from the home row without touching your mouse:

| Key | Action |
| :--- | :--- |
| `j` / `↓` | Move cursor down |
| `k` / `↑` | Move cursor up |
| `1` | Switch to **My PRs** tab |
| `2` | Switch to **Review Requests** tab |
| `3` | Switch to **Alerts / Notifications** tab |
| `h` / `l` (or `Tab` / `Shift+Tab`) | Cycle through tabs |
| `Enter` / `o` / `Space` | Open selected PR / notification in browser |
| `x` / `d` | Mark selected notification as read |
| `a` | Mark all notifications as read |
| `r` | Force refresh GitHub data |
| `p` | Open your GitHub profile |
| `n` / `i` | Create new PR / new Issue |
| `q` / `Esc` | Close popup |

---

## Installation

Install via the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/AzambekDev/omarchy-gitpulse.git --enable --yes
```

### Manual Install

```bash
git clone https://github.com/AzambekDev/omarchy-gitpulse.git ~/.config/omarchy/plugins/azambekdev.gitpulse
omarchy-shell shell rescanPlugins
omarchy plugin enable azambekdev.gitpulse right
```

---

## Global Keybinding

To toggle the panel with a global shortcut in Hyprland, add this to `~/.config/hypr/bindings.lua`:

```lua
-- GitPulse panel toggle
o.bind("SUPER + CTRL + G", "GitPulse", "omarchy-shell shell toggle azambekdev.gitpulse '{}'")
```

---

## Configuration

Customize behavior in `~/.config/omarchy/shell.json` under `bar.layout`:

```jsonc
{
  "id": "azambekdev.gitpulse",
  "pollIntervalSeconds": 60,   // Polling frequency in seconds (default: 60)
  "showCiStatus": true,        // Show CI pass/fail status in bar (default: true)
  "showReviewRequests": true,  // Show review request count (default: true)
  "showNotifications": true,   // Show unread notification badge (default: true)
  "compactView": false         // Compact icon-only mode in bar (default: false)
}
```

---

## IPC Interface

Control GitPulse from scripts, hooks, or terminal:

```bash
omarchy-shell call azambekdev.gitpulse refresh      # refresh data
omarchy-shell call azambekdev.gitpulse open         # open panel
omarchy-shell call azambekdev.gitpulse close        # close panel
omarchy-shell call azambekdev.gitpulse markAllRead  # clear notifications
```

---

## License

[MIT](LICENSE) © [Azambek Sattarov](https://github.com/AzambekDev)
