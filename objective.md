# 🎵 Project: Fumic
> **Vision:** A high-performance, keyboard-driven media environment for mouse-free operation and zero-interruption playback.

## 🛠 Project Core Philosophy
- **Mouse-Free Workflow:** Every action (play, seek, volume, navigation) must be accessible via keyboard shortcuts.
- **Performance First:** No lag or stuttering, especially on high-definition video files.
- **Privacy & Local Focus:** Built to play local files (MP4, WAV) without ads or data collection.

---

## 🎹 Keyboard Control Specification

### **Navigation & Playback**
| Action | Keyboard Shortcut | Notes |
| :--- | :--- | :--- |
| **Search Library** | `Ctrl + K` | Focuses the search bar immediately |
| **Play/Pause** | `Space` | |
| **Seek Forward (10s)** | `Shift + Right Arrow` | |
| **Seek Backward (10s)** | `Shift + Left Arrow` | |
| **Seek Forward (5s)** | `Right Arrow` | |
| **Seek Backward (5s)** | `Left Arrow` | |
| **Volume Up** | `Ctrl + Up Arrow` | |
| **Volume Down** | `Ctrl + Down Arrow` | |
| **Next Track/Video** | `Ctrl + Right Arrow` | |
| **Previous Track/Video**| `Ctrl + Left Arrow` | |
| **Play Selected** | `Ctrl + Enter` | Play the currently highlighted file |
| **Close App** | `Alt + F4` | |

### **Playlist Management**
- **Add to Playlist:** `Ctrl + V` or `Ctrl + Z` (To be finalized: intended for quick "liking" of a track).
- **Traverse:** Use `Up/Down` Arrows to highlight/select files in the explorer view without initiating playback.

---

## 🖼 UI Layout & Features

### **1. The Home Screen (File Explorer)**
- **Dual Tab System:** Toggle between 'Audio' and 'Video' views.
- **Playlists:** Nested under the Audio tab for quick categorization.
- **Search Bar:** Global search for all indexed MP4 and WAV files.
- **Visual Feedback:** A "Highlight" state that allows the user to see which file is selected while traversing with arrows.

### **2. Playback View (The Controller)**
- **Minimalist Aesthetic:** Focused on the media.
- **Visual Buttons:** Although shortcuts are primary, standard buttons (Play, Pause, Next, Prev, Repeat, Volume) will be present for visual confirmation of state.

---

## 🏗 Technical Requirements & Decisions

### **Tech Stack**
- **Framework:** Electron.
- **Primary Formats:** `MP4` (Video) and `WAV` (Audio). Focus on optimization for these specifically.
- **Performance Target:** Zero playback issues for large files or high-bitrate videos that currently struggle on default Windows players.

### **Development Roadmap**
1. **Initialize Electron:** Set up the main and renderer processes.
2. **Keyboard Listener:** Implement the global shortcut listener for internal app focus.
3. **Local File System Indexer:** Create a fast way to read and display local directories.
4. **Custom Media Controls:** Link the UI and shortcuts to the HTML5 video/audio elements.
5. **Playlist Logic:** Implement local storage (JSON or SQLite) to save user preferences and playlists.

---

## Current Session Design Plan

- Fix the stylistic visualizer first by keeping a Flutter-rendered visualizer mounted in non-performance mode, with the native audio-filter output treated as an enhancement rather than the only visible layer.
- Upgrade Settings around real controls only: visualizer enable/mode/background/artwork/reduce-motion/start-fullscreen/default speed, library actions, and compact practical descriptions.
- Upgrade Info as a premium about/help surface: strong hero, open-source/community sections, grouped shortcut reference, and refined FAQ cards.
- Improve global polish through shared dark-theme tokens, spacing, borders, focus/hover states, and empty-state/card treatments without touching the full-player layout beyond visualizer-related fixes.
