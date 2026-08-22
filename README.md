#  GitPulse for Omarchy

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue?style=flat-square&logo=archlinux)](https://omarchy.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![GitHub CLI](https://img.shields.io/badge/Powered%20by-GitHub%20CLI-black?style=flat-square&logo=github)](https://cli.github.com/)

**GitPulse** is a lightweight, real-time GitHub status monitor, Pull Request tracker, CI/CD health indicator, and interactive notification center built specifically for [Omarchy Linux](https://omarchy.org/) and Hyprland.

---

## ✨ Features

- ** Live GitHub Pulse on your Bar:**
  - Dynamic status bar pill displaying unread notifications count, pending PR review requests, authored PRs, and active CI/CD check states.
  - Urgent alerts (in theme's urgent/red color) when CI/CD fails on your open pull requests.
  - Review request badges (in amber/accent color) when teammates request your code review.
- **⚡ Zero-Config Authentication:**
  - Automatically connects via your existing [GitHub CLI (`gh`)](https://cli.github.com/) keyring. No manual token creation or API key pasting required.
- **📋 Interactive Popup Panel:**
  - **My Pull Requests:** View your open PRs, draft status, review decisions (*Approved*, *Changes Requested*, *In Review*), and live CI check statuses (*Passed*, *Failed*, *Running*).
  - **Review Requests:** PRs waiting for your review with author and age.
  - **Notification Center:** Unread alerts, issues, mentions, and releases with **1-Click "Mark as Read"** and **"Mark All Read"** actions.
  - **Quick Shortcuts:** Direct 1-click links to create new Issues, Pull Requests, or open your GitHub dashboard.
- **🎨 100% Native Omarchy Look & Feel:**
  - Automatically inherits your current Omarchy theme (Catppuccin, Gruvbox, Tokyo Night, Nord, etc.), fonts, borders, corner radiuses, and spacing tokens.
- **🖱️ Mouse Controls:**
  - **Left Click:** Open / close interactive detail popup.
  - **Right Click:** Force immediate data refresh.
  - **Middle Click:** Open your GitHub profile in default browser.

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

## ⌨️ Global Keybindings (Hyprland)

You can assign a global hotkey to summon or toggle GitPulse by adding this to `~/.config/hypr/bindings.lua` or your Hyprland keybindings:

```lua
-- Toggle GitPulse Popup
o.bind("SUPER, G", function()
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
```

---

## 🤝 Contributing

Contributions, feature requests, and suggestions are welcome!
Feel free to open an [Issue](https://github.com/AzambekDev/omarchy-gitpulse/issues) or submit a [Pull Request](https://github.com/AzambekDev/omarchy-gitpulse/pulls).

---

## 📄 License

Distributed under the [MIT License](LICENSE).
