#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== AI Usage Panel Installer ==="
echo "Source: $REPO_DIR"

# 1. Install CLI backend & GTK4 popup to ~/.config/waybar/scripts/
echo "==> Installing backend scripts & GTK4 popup..."
mkdir -p ~/.config/waybar/scripts
cp "$REPO_DIR/backend/usage.py" ~/.config/waybar/scripts/usage.py
cp "$REPO_DIR/backend/ai-usage-cli.py" ~/.config/waybar/scripts/ai-usage.py
cp "$REPO_DIR/gtk-popup/ai-usage-popup.py" ~/.config/waybar/scripts/ai-usage-popup.py
chmod +x ~/.config/waybar/scripts/usage.py ~/.config/waybar/scripts/ai-usage.py ~/.config/waybar/scripts/ai-usage-popup.py

# 2. Install Noctalia plugin
echo "==> Installing Noctalia plugin..."
mkdir -p ~/.local/share/noctalia/plugins/desktop-panels
cp "$REPO_DIR/integrations/noctalia/plugin.toml" ~/.local/share/noctalia/plugins/desktop-panels/
cp "$REPO_DIR/integrations/noctalia/ai-usage.luau" ~/.local/share/noctalia/plugins/desktop-panels/

# 3. Install GNOME Shell Extension
echo "==> Installing GNOME Shell extension (ai-usage@local)..."
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions/ai-usage@local"
mkdir -p "$GNOME_EXT_DIR"
cp "$REPO_DIR/integrations/gnome-shell/metadata.json" "$GNOME_EXT_DIR/"
cp "$REPO_DIR/integrations/gnome-shell/extension.js" "$GNOME_EXT_DIR/"
cp "$REPO_DIR/integrations/gnome-shell/stylesheet.css" "$GNOME_EXT_DIR/"
cp "$REPO_DIR/backend/usage.py" "$GNOME_EXT_DIR/"

echo ""
echo "Installation complete!"
echo "- Waybar/Noctalia scripts installed to: ~/.config/waybar/scripts/"
echo "- Noctalia widget installed to: ~/.local/share/noctalia/plugins/desktop-panels/"
echo "- GNOME extension installed to: ~/.local/share/gnome-shell/extensions/ai-usage@local/"
echo ""
echo "Next steps:"
echo "1. If using Noctalia, add [widget.\"ai-usage\"] in ~/.config/noctalia/bar.toml"
echo "2. If using Waybar, see integrations/waybar/config.jsonc.snippet"
echo "3. If using Niri, add window rule from integrations/niri/window-rules.kdl to ~/.config/niri/config.kdl"
echo "4. If using GNOME Shell, enable with: gnome-extensions enable ai-usage@local"
