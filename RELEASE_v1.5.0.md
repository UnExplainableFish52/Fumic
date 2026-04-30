# 🎬 Fumic v1.5.0 — Cinema Mode

> **The Magical Media Player** just got a whole lot more powerful.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011-0078D6?logo=windows)](https://github.com/UnExplainableFish52/Fumic)
[![Made with Electron](https://img.shields.io/badge/Made%20with-Electron-47848F?logo=electron&logoColor=white)](https://www.electronjs.org/)

---

## 🚀 What's New

### 🎥 Cinema Mode — Full-Screen Video Player

A brand-new, immersive video experience. When you play a video, Fumic automatically enters **Cinema Mode** — a full-screen, distraction-free player designed for pure viewing.

- **Full-screen coverage** — the video takes over your entire screen, no chrome, no clutter
- **Auto-hiding controls** — transport controls, progress bar, and close button fade out after **2.5 seconds** of inactivity
- **Cursor auto-hide** — even the cursor disappears when controls hide, giving you a clean cinematic view
- **Smooth fade transitions** — controls appear and disappear with a polished 300ms animation
- **Mouse/keyboard reveal** — any movement or keypress instantly brings controls back
- **Overlay gradient** — a sleek bottom gradient ensures controls remain readable over any video content
- **Close button** — a floating ✕ button in the top-right corner for quick exit

### ⚡ Performance: Zero-Flicker Track Switching

Switching between tracks no longer causes a jarring full-screen refresh. Previously, changing songs would rebuild the entire UI — the header, navigation, collection grid, and transport dock — causing a visible flash.

**Now, track changes use surgical DOM updates:**
- Only the currently playing indicator updates
- The transport dock updates in-place (title, thumbnail, progress)
- The media card grid stays untouched
- Result: **instant, seamless transitions** between tracks

### 🔧 Metadata Loading Improvements

- **Fixed empty metadata caching** — files that returned empty metadata from the parser were being cached as "done," preventing retries. Now only genuinely parsed metadata is cached.
- **Observer memory leak fix** — the IntersectionObserver used for lazy metadata loading is now properly disconnected before creating a new one, preventing accumulated observers.
- **5-second parse timeout** — a single corrupted or problematic file can no longer block the metadata queue. Parsing now races against a timeout.

---

## 📋 Complete Feature List

Everything Fumic offers as of v1.5.0:

| | Feature | Details |
|---|---|---|
| ⌨️ | **100% Keyboard Control** | Navigate, play, seek, and manage everything without ever touching the mouse |
| 🎥 | **Cinema Mode** | Full-screen, immersive video player with auto-hiding controls |
| 🎵 | **Fullscreen Audio Player** | Dedicated audio player view with album art, metadata, and backdrop blur |
| 🆓 | **FOSS** | Licensed under GPL v3 — free forever, no strings attached |
| 📁 | **Multiple Formats** | `.mp3`, `.mp4`, `.opus`, `.wav` supported out of the box |
| 🔒 | **100% Offline** | Zero telemetry, zero analytics, zero internet required |
| 🔀 | **Shuffle & Repeat** | Full shuffle and repeat modes (All / One / Off) |
| ⏩ | **Playback Speed** | Adjustable from 0.5x to 2.0x with keyboard shortcuts |
| 🔊 | **Volume Control** | Fine-grained volume with mute/unmute support |
| 🔍 | **Instant Search** | Real-time filtering across your entire media library |
| 📑 | **Alphabetical Grouping** | Media organized by first letter with beautiful section headers |
| 🖼️ | **Album Art & Metadata** | Embedded thumbnails, titles, artists extracted automatically |
| ⚡ | **Lazy Loading** | Metadata loaded on-demand as cards scroll into view |
| 🎨 | **Premium Dark UI** | Glassmorphism, micro-animations, and a hand-crafted design system |

---

## ⌨️ Keyboard Shortcuts

### Playback

| Shortcut | Action |
|---|---|
| `Space` | Play / Pause |
| `Ctrl + Enter` | Play Selected Track |
| `← / →` | Seek 5 seconds |
| `Shift + ← / →` | Seek 10 seconds |
| `Ctrl + ← / →` | Previous / Next Track |
| `Shift + < / >` | Playback Speed Down / Up |

### Controls

| Shortcut | Action |
|---|---|
| `Ctrl + ↑ / ↓` | Volume Up / Down |
| `Ctrl + M` | Mute / Unmute |
| `Shift + S` | Toggle Shuffle |
| `Shift + L` | Toggle Loop / Repeat |

### Navigation

| Shortcut | Action |
|---|---|
| `↑ / ↓` | Navigate Media List |
| `Ctrl + K` | Focus Search |
| `Escape` | Exit Fullscreen / Cinema / Unfocus Search |
| `Ctrl + H` | Go to Home |
| `Ctrl + S` | Go to Settings |
| `Ctrl + I` | Go to Info |
| `Ctrl + A` | Switch to Audio Tab |
| `Ctrl + V` | Switch to Video Tab |
| `Ctrl + F` | Toggle Fullscreen Player / Cinema Mode |

---

## 🖥️ System Requirements

- **OS:** Windows 10 / 11 (64-bit)
- **Runtime:** No additional runtime needed — everything is bundled

---

## 📦 Installation

Download the `.exe` installer below and run it. That's it.

| Platform | Download |
|---|---|
| Windows (x64) | `Fumic-Windows-1.5.0-Setup.exe` |

> **Note:** Windows may show a SmartScreen warning since the app is not code-signed. Click "More info" → "Run anyway" to proceed. The app is fully open-source — you can verify every line of code.

---

## 🛠️ Build from Source

```bash
# Clone
git clone https://github.com/UnExplainableFish52/Fumic.git
cd Fumic

# Install dependencies
npm install

# Run in development mode
npm run dev

# Build production installer
npm run build
```

Requires [Node.js](https://nodejs.org/) v18+ and npm.

---

## 🗺️ Roadmap

- 🎶 **Music Visualizer** — real-time audio waveform during playback
- 📋 **Playlists** — create, save, and manage custom playlists
- 🎨 **Themes** — additional color schemes and customization
- 🐛 **Continuous polish** — squashing bugs, refining the experience

Have ideas? [Open an issue](https://github.com/UnExplainableFish52/Fumic/issues) or reach out!

---

## 🤝 Credits & Contact

**Developer:** [TheIdealDev52](https://github.com/UnExplainableFish52) aka Saksham Sharma

- 📧 [sharma@saksham.info.np](mailto:sharma@saksham.info.np)
- 📧 [contactsaksham52@gmail.com](mailto:contactsaksham52@gmail.com)
- 🌐 [sakshamsharma.com.np](https://sakshamsharma.com.np)

If Fumic is useful to you, consider giving it a ⭐ — it genuinely helps!

---

<div align="center">

**Built with ❤️ by Saksham Sharma**

*Because good software should be free.*

**GNU General Public License v3.0**

</div>
