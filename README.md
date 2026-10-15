# AI Usage Panel 📊

A sleek, lightweight desktop status panel and interactive GTK4 popup for monitoring token consumption, session quotas, and subscription limits across modern AI developer CLIs:
- **Claude Code** (`~/.claude/`) — Token counts & official Anthropic OAuth plan limits / session countdown
- **Grok CLI** (`~/.grok/`) — Token counts per prompt and model
- **Antigravity CLI** (`~/.gemini/antigravity-cli/`) — Token counts extracted directly from conversation SQLite databases via protobuf wire parser

Designed for modern Wayland desktops (e.g., **Niri**, **Hyprland**, **Sway**) with native integration for **Noctalia**, **Waybar**, **GNOME Shell**, and **Ryoku**.

---

## ✨ Features

- **Real-Time Bar Indicator**: Displays current active session percentage or token volume right in your status bar.
- **Interactive TokyoNight GTK4 Popup**: Click the bar widget to toggle a floating dashboard displaying:
  - Plan type & session limit progress bars.
  - Reset countdowns (*"Resets in X hours Y minutes"*).
  - 7-day token consumption bar chart by day.
  - 30-day model usage breakdown.
- **Multi-Service Tabs**: Seamlessly switch between Claude, Grok, and Antigravity.
- **Delta Caching**: File metadata (`mtime` and size) caching ensures instant launches without reparsing gigabytes of session logs on every click.
- **Flexible Desktop Support**:
  - **Noctalia**: Native Luau plugin widget.
  - **Waybar**: JSON custom module with click toggles.
  - **GNOME Shell**: Full native top-bar extension (`ai-usage@local`).
  - **Ryoku**: Native Quickshell bar plugin with a themed QML panel.
  - **Niri**: Floating window rules for popup placement.

---

## 📂 Repository Structure

```
ai-usage-panel/
├── backend/
│   ├── usage.py            # Core log scanner, protobuf wire parser & Anthropic OAuth client
│   └── ai-usage-cli.py     # Waybar & CLI helper formatting JSON outputs
├── gtk-popup/
│   └── ai-usage-popup.py   # GTK4 popup application (styled with TokyoNight theme)
├── integrations/
│   ├── noctalia/           # Noctalia Luau widget plugin (plugin.toml + ai-usage.luau)
│   ├── waybar/             # Waybar custom module config & snippets
│   ├── gnome-shell/        # Native GNOME Shell 45-50 extension (extension.js, metadata, CSS)
│   ├── ryoku/              # Ryoku (Quickshell) bar plugin: manifest, QML service/widget/panel
│   └── niri/               # Niri window-rules snippet for top-right floating
├── install.sh              # One-step installation script
├── .gitignore
├── LICENSE                 # MIT License
└── README.md
```

---

## 🛠️ Prerequisites & Dependencies

On Arch Linux:
```bash
sudo pacman -S python python-gobject gtk4
```

*(Optional font: `ttf-cascadia-mono-nerd` or any monospace nerd font for optimal glyph rendering)*

---

## 🚀 Quick Install

Run the included installer to copy all files to standard user paths:

```bash
git clone https://github.com/<your-username>/ai-usage-panel.git
cd ai-usage-panel
chmod +x install.sh
./install.sh
```

---

## ⚙️ Configuration

### 1. Noctalia Setup
Add the widget to `~/.config/noctalia/bar.toml`:

```toml
[widget."ai-usage"]
type = "local/ai-usage:ai-usage"

[bar.default]
end = [
    # ... other widgets
    "ai-usage",
]
```

### 2. Waybar Setup
Add the module to your `~/.config/waybar/config.jsonc`:

```jsonc
"custom/ai-usage": {
    "exec": "~/.config/waybar/scripts/ai-usage.py",
    "on-click": "~/.config/waybar/scripts/ai-usage-popup.py",
    "exec-on-event": false,
    "return-type": "json",
    "interval": 600,
    "tooltip": false
}
```

And add `"custom/ai-usage"` into your `modules-right` or `modules-left` array.

### 3. Niri Window Rules (Floating Popup)
Add to `~/.config/niri/config.kdl`:

```kdl
window-rule {
    match app-id="^dev\\.local\\.AiUsagePopup$"
    open-floating true
    open-focused true
    default-floating-position x=12 y=8 relative-to="top-right"
    focus-ring { off; }
    border { off; }
    geometry-corner-radius 6
    clip-to-geometry true
}
```

### 4. GNOME Shell
Enable the extension after installation:
```bash
gnome-extensions enable ai-usage@local
```

### 5. Ryoku
The Ryoku plugin is self-contained and installs with Ryoku's own plugin
manager (`install.sh` is not needed):
```bash
ryoku plugin add integrations/ryoku --bar --yes
```
It appears on the QS Bar; its settings are under QS Bar Settings > Community.
See [integrations/ryoku/README.md](integrations/ryoku/README.md) for what it
reads, writes, and sends.

---

## 🧪 Testing Standalone

You can test the collectors or launch the popup directly from terminal:

```bash
# Print raw JSON analytics:
python3 backend/usage.py

# Print Waybar-formatted JSON:
python3 backend/ai-usage-cli.py

# Launch the GTK4 popup directly:
python3 gtk-popup/ai-usage-popup.py
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
