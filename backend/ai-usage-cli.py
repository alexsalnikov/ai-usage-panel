#!/usr/bin/env python3
"""AI Usage for waybar: prints {text, tooltip}; `toggle` flips Claude/Grok.

Data comes from the GNOME AI Usage extension's usage.py (same logs, same
Claude limits call). The result is reused for a minute so a click that only
flips the view doesn't fetch again.
"""
import html
import json
import os
import sys
import time
from datetime import date, datetime
from pathlib import Path

EXT = Path.home() / '.local/share/gnome-shell/extensions/ai-usage@local'
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'ai-usage-waybar'
TAB_FILE = RUNTIME / 'tab'
DATA_FILE = RUNTIME / 'data.json'
REUSE_SECONDS = 60

FILL, TRACK, MUTED, TEXT = '#a9b1f6', '#2f334d', '#737aa2', '#c0caf5'


def tokens(n):
    for size, unit in ((1e9, 'B'), (1e6, 'M'), (1e3, 'K')):
        if n >= size:
            return f'{n / size:.1f}{unit}'
    return str(n)


def bar(fraction, width):
    filled = round(width * max(0.0, min(1.0, fraction)))
    return (f'<span color="{FILL}">{"━" * filled}</span>'
            f'<span color="{TRACK}">{"━" * (width - filled)}</span>')


def resets_in(iso):
    if not iso:
        return ''
    mins = max(0, round((datetime.fromisoformat(iso).timestamp() - time.time()) / 60))
    d, h, m = mins // 1440, mins % 1440 // 60, mins % 60
    return f'Resets in {d}d {h}h' if d else f'Resets in {h}h {m}m' if h else f'Resets in {m}m'


def heading(text):
    return f'<span color="{MUTED}"><b>{html.escape(text)}</b></span>'


def load():
    try:
        if time.time() - DATA_FILE.stat().st_mtime < REUSE_SECONDS:
            return json.loads(DATA_FILE.read_text())
    except (OSError, ValueError):
        pass
    search_paths = [
        Path(__file__).resolve().parent,
        Path(__file__).resolve().parent / 'backend',
        Path.home() / '.local/share/gnome-shell/extensions/ai-usage@local',
        Path.home() / '.config/waybar/scripts',
    ]
    for p in search_paths:
        if (p / 'usage.py').exists() and str(p) not in sys.path:
            sys.path.insert(0, str(p))
            break
    import io
    import contextlib
    import usage
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        usage.main()
    DATA_FILE.write_text(buf.getvalue())
    return json.loads(buf.getvalue())


TABS = {'claude': 'Claude', 'grok': 'Grok', 'antigravity': 'Antigravity'}


def next_tab(tab):
    ids = list(TABS)
    return ids[(ids.index(tab) + 1) % len(ids)] if tab in ids else ids[0]


def tooltip(data, tab):
    svc = data[tab]
    other = TABS[next_tab(tab)]
    lines = [f'<b>{TABS[tab].upper()}</b>'
             f'   <span color="{MUTED}">click for {other}</span>', '']

    if tab == 'claude':
        plan = f' · {svc["plan"].upper()}' if svc.get('plan') else ''
        lines.append(heading(f'LIMITS{plan}'))
        if svc.get('error'):
            lines.append(f'<span color="{MUTED}">{html.escape(svc["error"])}</span>')
        for lim in svc.get('limits', []):
            pct = f'{round(lim["percent"])}%'
            lines.append(f'{lim["label"]:<{36 - len(pct)}}{pct}')
            lines.append(bar(lim['percent'] / 100, 36))
            lines.append(f'<span color="{MUTED}">{resets_in(lim.get("resets_at"))}</span>')
        lines.append('')

    lines.append(heading('TOKENS BY DAY'))
    days = svc['days']
    top = max([1] + [d['tokens'] for d in days])
    for i, d in enumerate(days):
        today = i == len(days) - 1
        name = 'Today' if today else date.fromisoformat(d['date']).strftime('%a')
        row = f'{name:<6}{bar(d["tokens"] / top, 20)} {tokens(d["tokens"]):>7}'
        lines.append(f'<b>{row}</b>' if today else row)
    lines.append('')

    lines.append(heading('TOKENS BY MODEL · 30 DAYS'))
    models = svc['models'] or [{'name': 'No usage yet', 'tokens': 0}]
    top = max([1] + [m['tokens'] for m in models])
    for m in models:
        lines.append(f'{html.escape(m["name"]):<12}{bar(m["tokens"] / top, 16)} {tokens(m["tokens"]):>7}')
    return '\n'.join(lines)


def main():
    RUNTIME.mkdir(parents=True, exist_ok=True)
    tab = TAB_FILE.read_text().strip() if TAB_FILE.exists() else 'claude'
    if sys.argv[1:] == ['toggle']:
        TAB_FILE.write_text(next_tab(tab))
        return

    data = load()
    session = next((l for l in data['claude'].get('limits', []) if l['label'] == 'Session'), None)
    text = f'AI {round(session["percent"])}%' if session else 'AI'
    print(json.dumps({'text': text, 'tooltip': tooltip(data, tab if tab in data else 'claude')}))


if __name__ == '__main__':
    main()
