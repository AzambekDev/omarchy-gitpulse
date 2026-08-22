#  GitPulse for Omarchy

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue?style=flat-square&logo=archlinux)](https://omarchy.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![GitHub CLI](https://img.shields.io/badge/Powered%20by-GitHub%20CLI-black?style=flat-square&logo=github)](https://cli.github.com/)

**GitPulse** is a lightweight, real-time GitHub status monitor, Pull Request tracker, CI/CD health indicator, and interactive notification center built specifically for [Omarchy Linux](https://omarchy.org/) and Hyprland. Designed for both keyboard-first (anti-mouse) power users and mouse-driven workflows alike.

---

## ✨ Features

- ** Live GitHub Pulse on your Bar:**
  - Dynamic status bar pill displaying unread notifications count, pending PR review requests, authored PRs, and active CI/CD check states.
  - Urgent alerts (in theme's urgent/red color) when CI/CD fails on your open pull requests.
  - Review request badges (in amber/accent color) when teammates request your code review.
- **⚡ Zero-Config Authentication:**
  - Automatically connects via your existing [GitHub CLI (`gh`)](https://cli.github.com/) keyring. No manual token creation or API key pasting required.
- **⌨️ 100% Keyboard-Driven & Anti-Mouse Friendly:**
  - Full Vim-style navigation support (`j`/`k`, `h`/`l`, `1`/`2`/`3`, `o`, `x`, `r`, `q`).
  - Active visual cursor tracking that highlights selected items and seamlessly synchronizes with mouse hover.
- **📋 Interactive Popup Panel:**
  - **My Pull Requests:** View your open PRs, draft status, review decisions (*Approved*, *Changes Requested*, *In Review*), and live CI check statuses (*Passed*, *Failed*, *Running*).
  - **Review Requests:** PRs waiting for your review with author and age.
  - **Notification Center:** Unread alerts, issues, mentions, and releases with **1-Click "Mark as Read"** and **"Mark All Read"** actions.
  - **Quick Shortcuts:** Direct links to create new Issues, Pull Requests, or open your GitHub dashboard.
- **🎨 100% Native Omarchy Look & Feel:**
  - Automatically inherits your current Omarchy theme (Catppuccin, Gruvbox, Tokyo Night, Nord, etc.), fonts, borders, corner radiuses, and spacing tokens.
- **🖱️ Mouse Controls:**
  - **Left Click:** Open / close interactive detail popup.
  - **Right Click:** Force immediate data refresh.
  - **Middle Click:** Open your GitHub profile in default browser.

---

## ⌨️ Keyboard Navigation Reference

When the GitPulse popup is open, you never need to touch your mouse:

| Keybinding | Action |
| :--- | :--- |
| <kbd>j</kbd> / <kbd>↓</kbd> | Move cursor down through list items |
| <kbd>k</kbd> / <kbd>↑</kbd> | Move cursor up through list items |
| <kbd>1</kbd> | Switch to **My PRs** tab |
| <kbd>2</kbd> | Switch to **Review Requests** tab |
| <kbd>3</kbd> | Switch to **Notifications / Alerts** tab |
| <kbd>h</kbd> / <kbd>l</kbd> or <kbd>Tab</kbd> / <kbd>Shift+Tab</kbd> | Cycle through tabs |
| <kbd>Enter</kbd> / <kbd>o</kbd> / <kbd>Space</kbd> | Open selected PR / notification in browser |
| <kbd>x</kbd> / <kbd>d</kbd> | Mark selected notification as read |
| <kbd>a</kbd> | Mark **all** notifications as read |
| <kbd>r</kbd> | Force refresh GitHub data (with spin animation) |
| <kbd>p</kbd> | Open your GitHub profile in browser |
| <kbd>n</kbd> | Open New Pull Request page in browser |
| <kbd>i</kbd> | Open Issues dashboard in browser |
| <kbd>Esc</kbd> / <kbd>q</kbd> | Close popup |

---

## 🚀 Installation

Install GitPulse with a single command via the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/AzambekDev/omarchy-gitpulse.git --enable --yes
```

### Manual Installation

If you prefer to clone manually:

```bash
mkdir -p ~/.config/omarchy/plugins/azambekdev.gitpulse
git clone https://github.com/AzambekDev/omarchy-gitpulse.git ~/.config/omarchy/plugins/azambekdev.gitpulse
omarchy-shell shell rescanPlugins
omarchy plugin enable azambekdev.gitpulse right
```

---

## 🔑 Prerequisites

GitPulse requires the GitHub CLI (`gh`) and `jq`:

```bash
# Ensure gh is authenticated
gh auth login
```

---

## ⚙️ Configuration

You can customize GitPulse in `~/.config/omarchy/shell.json` under `bar.layout`:

```jsonc
{
  "id": "azambekdev.gitpulse",
  "pollIntervalSeconds": 60,   // Poll interval in seconds (default: 60)
  "showCiStatus": true,        // Show CI pass/fail status icon in bar (default: true)
  "showReviewRequests": true,  // Show review requests badge in bar (default: true)
  "showNotifications": true,   // Show notifications badge in bar (default: true)
  "compactView": false         // Compact icon-only mode in bar (default: false)
}
```

---

## 🌐 Global Keybinding (Hyprland)

Bind a shortcut to toggle GitPulse from anywhere in Hyprland by editing `~/.config/hypr/bindings.lua`:

```lua
-- Toggle GitPulse Popup with Super+Ctrl+G
o.bind("SUPER + CTRL + G", function()
  hl.exec("omarchy-shell shell toggle azambekdev.gitpulse '{}'")
end)
```

---

## 🛠️ CLI & IPC Commands

GitPulse integrates with Omarchy's shell IPC:

```bash
# Force refresh GitHub data
omarchy-shell call azambekdev.gitpulse refresh

# Open popup
omarchy-shell call azambekdev.gitpulse open

# Close popup
omarchy-shell call azambekdev.gitpulse close

# Mark all unread notifications as read
omarchy-shell call azambekdev.gitpulse markAllRead

# Cycle tabs
omarchy-shell call azambekdev.gitpulse nextTab
omarchy-shell call azambekdev.gitpulse prevTab
```

---

## 🤝 Contributing

Contributions, feature requests, and suggestions are welcome!
Feel free to open an [Issue](https://github.com/AzambekDev/omarchy-gitpulse/issues) or submit a [Pull Request](https://github.com/AzambekDev/omarchy-gitpulse/pulls).

---

## 📄 License

Distributed under the [MIT License](LICENSE).
