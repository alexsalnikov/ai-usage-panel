#!/usr/bin/env python3
"""AI Usage popup for waybar under niri: Claude/Grok tabs, limits, tokens.

A second launch closes the open popup (via a pid file), so the bar button
toggles it. niri
floats it top-right (window rule on app-id ai-usage-popup in config.kdl). Data
comes from ai-usage.py's cached load(), so opening it rarely fetches.
"""
import importlib.util
import os
import signal
import sys
from datetime import date, datetime
from pathlib import Path

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402

APP_ID = 'dev.local.AiUsagePopup'
HERE = Path(__file__).resolve().parent
PID_FILE = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'ai-usage-waybar' / 'popup.pid'

backend_path = None
for candidate in [
    HERE / 'ai-usage.py',
    HERE.parent / 'backend' / 'ai-usage-cli.py',
    HERE.parent / 'backend' / 'ai-usage.py',
    Path.home() / '.config/waybar/scripts' / 'ai-usage.py',
]:
    if candidate.exists():
        backend_path = candidate
        break

if not backend_path:
    raise FileNotFoundError("Could not find backend ai-usage-cli.py or ai-usage.py")

spec = importlib.util.spec_from_file_location('ai_usage_waybar', backend_path)
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)

WIDTH = 400

CSS = b"""
window.ai-popup {
    background-color: #1a1b26;
    border: 1px solid #7aa2f7;
    border-radius: 6px;
}
.ai-popup * {
    font-family: "CaskaydiaMono Nerd Font", monospace;
    color: #c0caf5;
}
.ai-panel { padding: 18px 20px; }

.tab {
    padding: 8px 0;
    border: 1px solid #3b4261;
    border-radius: 3px;
    background: #1f2335;
    color: #737aa2;
    font-size: 11pt;
    box-shadow: none;
}
.tab:hover { background: #292e42; color: #c0caf5; }
.tab:checked {
    background: #2f334d;
    border-color: #7aa2f7;
    color: #c0caf5;
    font-weight: bold;
}

.heading {
    font-size: 9.5pt;
    font-weight: bold;
    letter-spacing: 1.5px;
    color: #737aa2;
    margin-top: 6px;
}
.muted { font-size: 10pt; color: #737aa2; }
.limit-name { font-size: 12pt; }
.pct { font-size: 10pt; }
.day-name { font-size: 10.5pt; color: #737aa2; }
.day-value { font-size: 10.5pt; color: #a9b1d6; }
.today .day-name, .today .day-value { font-weight: bold; color: #c0caf5; }
separator { background: #292e42; min-height: 1px; margin: 8px 0; }

progressbar trough {
    min-height: 6px;
    border-radius: 3px;
    background: #2f334d;
    border: none;
}
progressbar progress {
    min-width: 0;
    margin: 0;
    padding: 0;
    min-height: 6px;
    border-radius: 3px;
    background: #a9b1f6;
    border: none;
}
progressbar.day trough, progressbar.day progress { min-height: 5px; }
progressbar.day progress { background: #737aa2; }
.today progressbar.day progress { background: #a9b1f6; }

.model { min-height: 34px; background: #1f2335; }
.model-fill { background: #2f334d; }
.model-name { font-size: 11pt; padding-left: 12px; }
.model-value { font-size: 10.5pt; color: #737aa2; padding-right: 12px; }
"""


def label(text, css=None, **kw):
    lbl = Gtk.Label(label=text, **{'xalign': 0, **kw})
    if css:
        for c in css.split():
            lbl.add_css_class(c)
    return lbl


def progress(fraction, css=None):
    bar = Gtk.ProgressBar(fraction=max(0.0, min(1.0, fraction)), hexpand=True,
                          valign=Gtk.Align.CENTER)
    if css:
        bar.add_css_class(css)
    return bar


class Popup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.win = None
        self.data = None
        self.tab = 'claude'

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        self.win = Gtk.ApplicationWindow(application=self, title='AI Usage',
                                         decorated=False, resizable=False)
        self.win.add_css_class('ai-popup')
        self.win.set_default_size(WIDTH + 40, -1)

        keys = Gtk.EventControllerKey()
        keys.connect('key-pressed', lambda _c, k, *_: k == Gdk.KEY_Escape and self.quit())
        self.win.add_controller(keys)
        # Close when focus moves elsewhere, like a menu, but only once it has
        # actually had focus.
        self.had_focus = False
        self.win.connect('notify::is-active', self.on_active)

        self.panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.panel.add_css_class('ai-panel')
        self.win.set_child(self.panel)

        try:
            self.data = backend.load()
        except Exception as e:  # noqa: BLE001 — show it rather than vanish
            self.data = {'error': str(e)}
        self.render()
        self.win.present()

    def on_active(self, win, _pspec):
        if win.is_active():
            self.had_focus = True
        elif self.had_focus:
            self.quit()

    def render(self):
        while (child := self.panel.get_first_child()):
            self.panel.remove(child)
        self.panel.append(self.tabs())
        if 'error' in self.data and 'claude' not in self.data:
            self.panel.append(label(self.data['error'], 'muted', wrap=True))
            return
        svc = self.data.get(self.tab)
        if svc is None:
            self.panel.append(label('No data yet · reopen in a moment', 'muted', wrap=True))
            return
        if self.tab == 'claude':
            self.limits(svc)
        elif self.tab == 'grok':
            self.panel.append(label('Plan limits for Grok are only shown on grok.com', 'muted', wrap=True))
        else:
            self.panel.append(label('Model quota for Antigravity is only shown inside Antigravity', 'muted', wrap=True))
        self.panel.append(Gtk.Separator())
        self.days(svc['days'])
        self.panel.append(Gtk.Separator())
        self.models(svc['models'])

    def tabs(self):
        row = Gtk.Box(spacing=8, homogeneous=True, margin_bottom=6)
        first = None
        for tab_id, text in backend.TABS.items():
            b = Gtk.ToggleButton(label=text, active=tab_id == self.tab)
            b.add_css_class('tab')
            if first:
                b.set_group(first)
            first = first or b
            b.connect('toggled', self.on_tab, tab_id)
            row.append(b)
        return row

    def on_tab(self, button, tab_id):
        if button.get_active() and tab_id != self.tab:
            self.tab = tab_id
            GLib.idle_add(self.render)

    def limits(self, svc):
        plan = f' · {svc["plan"].upper()}' if svc.get('plan') else ''
        self.panel.append(label(f'LIMITS{plan}', 'heading'))
        if svc.get('error'):
            self.panel.append(label(svc['error'], 'muted', wrap=True))
            return
        for lim in svc.get('limits', []):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_bottom=4)
            top = Gtk.Box()
            top.append(label(lim['label'], 'limit-name', hexpand=True))
            top.append(label(f'{round(lim["percent"])}%', 'pct'))
            box.append(top)
            box.append(progress(lim['percent'] / 100))
            box.append(label(backend.resets_in(lim.get('resets_at')), 'muted'))
            self.panel.append(box)

    def days(self, days):
        self.panel.append(label('TOKENS BY DAY', 'heading'))
        top = max([1] + [d['tokens'] for d in days])
        for i, d in enumerate(days):
            today = i == len(days) - 1
            row = Gtk.Box(spacing=14)
            if today:
                row.add_css_class('today')
            name = 'Today' if today else date.fromisoformat(d['date']).strftime('%a')
            name_lbl = label(name, 'day-name')
            name_lbl.set_size_request(60, -1)
            row.append(name_lbl)
            row.append(progress(d['tokens'] / top, 'day'))
            value = label(backend.tokens(d['tokens']), 'day-value', xalign=1)
            value.set_size_request(70, -1)
            row.append(value)
            self.panel.append(row)

    def models(self, models):
        self.panel.append(label('TOKENS BY MODEL · 30 DAYS', 'heading'))
        if not models:
            self.panel.append(label('No usage yet', 'muted'))
            return
        top = max([1] + [m['tokens'] for m in models])
        for m in models:
            overlay = Gtk.Overlay()
            overlay.add_css_class('model')
            overlay.set_size_request(WIDTH, 34)
            track = Gtk.Box()
            fill = Gtk.Box()
            fill.add_css_class('model-fill')
            fill.set_size_request(round(WIDTH * m['tokens'] / top), 34)
            track.append(fill)
            overlay.set_child(track)
            text = Gtk.Box(valign=Gtk.Align.CENTER)
            text.append(label(m['name'], 'model-name', hexpand=True))
            text.append(label(backend.tokens(m['tokens']), 'model-value'))
            overlay.add_overlay(text)
            self.panel.append(overlay)


def running_pid():
    try:
        pid = int(PID_FILE.read_text())
        if 'ai-usage-popup' in Path(f'/proc/{pid}/cmdline').read_text():
            return pid
    except (OSError, ValueError):
        pass
    return None


if __name__ == '__main__':
    if (pid := running_pid()):     # bar clicked while open: close it
        os.kill(pid, signal.SIGTERM)
        sys.exit(0)
    PID_FILE.parent.mkdir(parents=True, exist_ok=True)
    PID_FILE.write_text(str(os.getpid()))
    app = Popup()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: app.quit() or GLib.SOURCE_REMOVE)
    try:
        sys.exit(app.run([]))
    finally:
        if running_pid() == os.getpid():
            PID_FILE.unlink(missing_ok=True)
