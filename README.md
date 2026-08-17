<div align="center">

<img src="Di_logo.png" alt="Dynamic Island logo" width="120" />

# Dynamic Island for KDE Plasma 6

### A living status capsule that morphs to match whatever is happening on your desktop.

Clock. Music. Notifications. Downloads. Screen sharing. IDE builds. System stats.  
All in a single adaptive panel widget — no tray clutter, no extra docks.

[![License](https://img.shields.io/github/license/DeadIndian/PlasmaKde-Dynamic-Islands?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/DeadIndian/PlasmaKde-Dynamic-Islands?style=flat-square)](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/releases)
[![Stars](https://img.shields.io/github/stars/DeadIndian/PlasmaKde-Dynamic-Islands?style=flat-square)](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/stargazers)
[![Issues](https://img.shields.io/github/issues/DeadIndian/PlasmaKde-Dynamic-Islands?style=flat-square)](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](CONTRIBUTING.md)
![Plasma 6](https://img.shields.io/badge/Plasma-6-1d99f3?style=flat-square&logo=kde&logoColor=white)
![Made with QML](https://img.shields.io/badge/made%20with-QML-41cd52?style=flat-square)

[Installation](#-installation) ·
[Features](#-features) ·
[Configuration](#%EF%B8%8F-configuration) ·
[Report Bug](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/issues) ·
[Request Feature](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/issues)

<img src="screenshots/okak.gif" alt="Dynamic Island in action" width="80%" />

</div>

---

## 📖 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Installation](#-installation)
- [Usage](#-usage)
- [Configuration](#%EF%B8%8F-configuration)
- [How It Works](#-how-it-works)
- [Requirements](#-requirements)
- [Contributing](#-contributing)
- [License](#-license)
- [Maintainers](#-maintainers)

---

## 🎯 About

Dynamic Island turns a small slice of your KDE Plasma panel into an intelligent, always-visible status capsule — inspired by Apple's Dynamic Island.

When nothing is happening it shows a clean clock. The moment something does happen — music plays, a notification arrives, a build finishes, your screen is being shared — the capsule smoothly **morphs** into a compact interactive widget with full controls. Click it to expand a glass-style overlay with detailed information.

No notification badge hunting. No taskbar scanning. Everything surfaces exactly when you need it and disappears when you don't.

---

## ✨ Features

### 🎵 Music (MPRIS)
- Album artwork in the capsule and expanded panel
- Animated audio bars while playing
- Playback progress bar
- Previous / Play-Pause / Next controls
- Scrolling title for long track names

### 🔔 Notifications
- App icon, title, and multi-line body preview
- Animated unread indicator dot
- Configurable body length cutoff

### ⌨️ Keyboard Layout
- Full layout name (not just a two-letter code)
- Visual switch announcements when you change layout

### 📥 Downloads & Jobs
- Active task detection via KJobs
- Real-time progress tracking

### 🖥️ Screen Sharing
- Capture and presentation state indicators
- Special sharing overlay when media is also playing

### 🔨 IDE Build Results
- **IntelliJ IDEA**, **Android Studio**, **Gradle**, **Maven**
- Dedicated success ✅ and failure ❌ states in the capsule

### 📊 System Monitoring
- CPU and RAM usage
- Auto-rotates with the idle clock

### 🎞️ FPS Counter
- Optional real-time FPS display
- Two styles: accent badge or plain clock font

### ⏱️ Timer & Stopwatch
- Countdown timer with configurable presets
- Stopwatch with lap support

### 🔊 Volume & Brightness
- Live volume slider with mute toggle
- Display brightness slider — all inside the expanded island

### 🔁 Quick Toggles
- Configurable toggle buttons (Night Color, Do Not Disturb, Wi-Fi, etc.)

### 🎨 Deep Customization
- Capsule size, corner radius, color, opacity
- Expanded panel dimensions per mode (music / notification / status)
- Accent color, border, follow-system-theme option
- Animation speed multiplier
- Module order and per-feature enable/disable switches
- Reorderable compact blocks (Content · Time · FPS) with 6 layout presets
- Optional "/" separators between compact modules

---

## 📸 Screenshots

| Compact — Media | Compact — Notification |
| :---: | :---: |
| <img src="screenshots/Screen1.png" width="100%" /> | <img src="screenshots/screeen2.png" width="100%" /> |

| Expanded Panel | Settings |
| :---: | :---: |
| <img src="screenshots/screen3.png" width="100%" /> | <img src="screenshots/screen4.png" width="100%" /> |

<p align="center">
  <img src="screenshots/screen5.png" width="60%" alt="System monitor state" />
</p>

---

## 🚀 Installation

### Option 1 — KDE Store (recommended)

Open the **"Get New Widgets"** dialog in Plasma, search for **Dynamic Island**, and click Install.

### Option 2 — `.plasmoid` package

Download the latest `dynamicisland-x.x.x.plasmoid` from the [Releases](https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands/releases) page, then run:

```bash
kpackagetool6 -t Plasma/Applet -i dynamicisland-x.x.x.plasmoid
```

### Option 3 — From source

```bash
git clone https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands.git
cd PlasmaKde-Dynamic-Islands
./install.sh
```

The script copies the package into `~/.local/share/plasma/plasmoids/` and refreshes the service cache automatically.

---

## 💻 Usage

After installation, **right-click your panel → Add Widgets → search "Dynamic Island"** and drag it onto the panel.

```bash
# Test it standalone (without restarting Plasma)
plasmoidviewer -a com.ifny75.dynamicisland

# Reload Plasma to apply after a source update
kquitapp6 plasmashell && kstart plasmashell
```

---

## ⚙️ Configuration

Right-click the capsule → **Configure Dynamic Island**. Settings are organized into tabs:

| Tab | What you can change |
| --- | --- |
| **Size & Shape** | Capsule dimensions, expanded panel widths per mode, corner radius, gap from panel |
| **Layout** | Block order (Content · Time · FPS), module separators, FPS style |
| **Appearance** | Background color & opacity, border, follow-system-theme, accent color |
| **Clock** | Show seconds, show date, format options |
| **Notifications** | Body length, unread indicator |
| **Modules** | Enable/disable each feature individually |
| **System & FPS** | CPU/RAM monitoring, FPS counter style |
| **Animations** | Enable/disable animations, speed multiplier |
| **Media** | Album art size, sound bar style, expanded media options |
| **Panel** | Per-expanded-panel fine-tuning |
| **Timer** | Timer presets and stopwatch options |

No file editing required — everything is in the GUI.

---

## 🧠 How It Works

Only the most important event is shown at any time. Priority order (highest → lowest):

```
Build Results → Sharing + Music → Notifications → Keyboard / Downloads → Music → Sharing → Clock
```

The compact capsule is made of three independent blocks that you can reorder:

```
[ Content block ]  [ Time block ]  [ FPS block ]
```

Each block can have optional "/" dividers between them.

---

## 📋 Requirements

| Dependency | Notes |
| --- | --- |
| **KDE Plasma 6.0+** | Required |
| **Qt 6** | Required |
| `plasma-systemmonitor` / `libksysguard` | Optional — needed for CPU/RAM monitoring. Installed by default on most Plasma distributions. |

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-thing`)
3. Make your changes — no build step needed, it's pure QML
4. Test locally with `./install.sh` then `plasmoidviewer -a com.ifny75.dynamicisland`
5. Commit (`git commit -m 'feat: add amazing thing'`)
6. Push and open a Pull Request

**Project layout:**

```
package/
├── metadata.json          ← widget identity & KDE Store metadata
└── contents/
    ├── config/
    │   ├── main.xml       ← configuration schema (KConfig)
    │   └── config.qml     ← settings page registry
    └── ui/
        ├── main.qml       ← root PlasmoidItem & all state
        ├── IslandPanel.qml
        ├── widgets/       ← expanded panel widgets (Volume, Timer, etc.)
        └── config*.qml    ← one file per settings tab
```

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 👥 Maintainers

- **Dead Indian** — [gollabharath2007@gmail.com](mailto:gollabharath2007@gmail.com) · [GitHub](https://github.com/DeadIndian)

---

<div align="center">
<sub>Built with ❤️ by Dead Indian &nbsp;·&nbsp; <a href="https://github.com/DeadIndian/PlasmaKde-Dynamic-Islands">GitHub</a> &nbsp;·&nbsp; <a href="https://store.kde.org">KDE Store</a></sub>
</div>
