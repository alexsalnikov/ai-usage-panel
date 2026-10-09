import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// AI Usage: Claude plan limits and Claude/Grok tokens, from usage.py. The
// script runs every ten minutes, and on opening the panel if the data is more
// than a minute old; the reset countdowns re-render every minute in between.

const FETCH_SECONDS = 600;
const RENDER_SECONDS = 60;
const STALE_ON_OPEN_MS = 60 * 1000;

// Widths the bars are drawn against; keep in step with stylesheet.css.
const LIMIT_BAR_WIDTH = 400;
const DAY_BAR_WIDTH = 250;
const MODEL_ROW_WIDTH = 400;

const SERVICES = [
    {id: 'claude', label: 'Claude'},
    {id: 'grok', label: 'Grok'},
];

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function formatTokens(n) {
    if (n >= 1e9)
        return `${(n / 1e9).toFixed(1)}B`;
    if (n >= 1e6)
        return `${(n / 1e6).toFixed(1)}M`;
    if (n >= 1e3)
        return `${(n / 1e3).toFixed(1)}K`;
    return String(n);
}

function formatResetsIn(iso) {
    if (!iso)
        return '';
    const mins = Math.max(0, Math.round((Date.parse(iso) - Date.now()) / 60000));
    const d = Math.floor(mins / 1440);
    const h = Math.floor((mins % 1440) / 60);
    const m = mins % 60;
    if (d > 0)
        return `Resets in ${d}d ${h}h`;
    if (h > 0)
        return `Resets in ${h}h ${m}m`;
    return `Resets in ${m}m`;
}

function label(text, styleClass, props = {}) {
    return new St.Label({text, style_class: styleClass, ...props});
}

function bar(width, fraction, styleClass = 'ai-bar') {
    const track = new St.Widget({style_class: `${styleClass}-track`, width});
    const fill = new St.Widget({
        style_class: `${styleClass}-fill`,
        width: Math.round(width * Math.min(1, Math.max(0, fraction))),
    });
    track.add_child(fill);
    return track;
}

const AiUsageIndicator = GObject.registerClass(
class AiUsageIndicator extends PanelMenu.Button {
    _init(scriptPath) {
        super._init(0.5, 'AI Usage');
        this._scriptPath = scriptPath;
        this._data = null;
        this._fetchedAt = 0;
        this._tab = 'claude';
        this._cancellable = new Gio.Cancellable();

        this._label = label('AI', 'ai-usage-bar-label', {y_align: Clutter.ActorAlign.CENTER});
        this.add_child(this._label);

        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        this._panel = new St.BoxLayout({
            style_class: 'ai-panel',
            orientation: Clutter.Orientation.VERTICAL,
            x_expand: true,
        });
        item.add_child(this._panel);
        this.menu.addMenuItem(item);
        this.menu.box.add_style_class_name('ai-menu');

        this.menu.connect('open-state-changed', (_menu, open) => {
            if (!open)
                return;
            if (Date.now() - this._fetchedAt > STALE_ON_OPEN_MS)
                this.fetch();
            this.render();
        });

        this.render();
    }

    fetch() {
        if (this._fetching)
            return;
        this._fetching = true;
        let proc;
        try {
            proc = Gio.Subprocess.new(['python3', this._scriptPath],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
        } catch (e) {
            this._fetching = false;
            console.error(`ai-usage: ${e.message}`);
            return;
        }
        proc.communicate_utf8_async(null, this._cancellable, (p, res) => {
            this._fetching = false;
            try {
                const [, stdout] = p.communicate_utf8_finish(res);
                if (p.get_successful() && stdout) {
                    this._data = JSON.parse(stdout);
                    this._fetchedAt = Date.now();
                }
            } catch (e) {
                if (!e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    console.error(`ai-usage: ${e.message}`);
                return;
            }
            this.render();
        });
    }

    render() {
        const session = this._data?.claude?.limits?.find(l => l.label === 'Session');
        this._label.text = session ? `AI ${Math.round(session.percent)}%` : 'AI';

        if (!this.menu.isOpen && this._panel.get_n_children() > 0)
            return;
        this._panel.destroy_all_children();
        this._panel.add_child(this._buildTabs());

        if (!this._data) {
            this._panel.add_child(label('Loading…', 'ai-muted'));
            return;
        }
        const svc = this._data[this._tab];
        if (this._tab === 'claude')
            this._buildLimits(svc);
        else
            this._panel.add_child(label('Plan limits for Grok are only shown on grok.com', 'ai-muted'));

        this._panel.add_child(new St.Widget({style_class: 'ai-separator'}));
        this._buildDays(svc.days);
        this._panel.add_child(new St.Widget({style_class: 'ai-separator'}));
        this._buildModels(svc.models);
    }

    _buildTabs() {
        const row = new St.BoxLayout({style_class: 'ai-tabs'});
        for (const {id, label: text} of SERVICES) {
            const button = new St.Button({
                label: text,
                style_class: 'ai-tab',
                can_focus: true,
                x_expand: true,
            });
            if (id === this._tab)
                button.add_style_pseudo_class('checked');
            button.connect('clicked', () => {
                this._tab = id;
                // Rebuild after the click finishes: render() destroys this button.
                GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                    this.render();
                    return GLib.SOURCE_REMOVE;
                });
            });
            row.add_child(button);
        }
        return row;
    }

    _buildLimits(svc) {
        const plan = svc.plan ? ` · ${svc.plan.toUpperCase()}` : '';
        this._panel.add_child(label(`LIMITS${plan}`, 'ai-heading'));
        if (svc.error) {
            this._panel.add_child(label(svc.error, 'ai-muted'));
            return;
        }
        for (const l of svc.limits ?? []) {
            const box = new St.BoxLayout({style_class: 'ai-limit', orientation: Clutter.Orientation.VERTICAL});
            const top = new St.BoxLayout();
            top.add_child(label(l.label, 'ai-limit-name', {x_expand: true}));
            top.add_child(label(`${Math.round(l.percent)}%`, 'ai-limit-pct'));
            box.add_child(top);
            box.add_child(bar(LIMIT_BAR_WIDTH, l.percent / 100, 'ai-limit-bar'));
            box.add_child(label(formatResetsIn(l.resets_at), 'ai-muted'));
            this._panel.add_child(box);
        }
    }

    _buildDays(days) {
        this._panel.add_child(label('TOKENS BY DAY', 'ai-heading'));
        const max = Math.max(1, ...days.map(d => d.tokens));
        days.forEach((d, i) => {
            const today = i === days.length - 1;
            const row = new St.BoxLayout({style_class: today ? 'ai-day ai-today' : 'ai-day'});
            const name = today ? 'Today' : WEEKDAYS[new Date(`${d.date}T12:00:00`).getDay()];
            row.add_child(label(name, 'ai-day-name', {y_align: Clutter.ActorAlign.CENTER}));
            const b = bar(DAY_BAR_WIDTH, d.tokens / max, today ? 'ai-day-bar-today' : 'ai-day-bar');
            b.y_align = Clutter.ActorAlign.CENTER;
            row.add_child(b);
            row.add_child(label(formatTokens(d.tokens), 'ai-day-value', {
                x_expand: true,
                x_align: Clutter.ActorAlign.END,
                y_align: Clutter.ActorAlign.CENTER,
            }));
            this._panel.add_child(row);
        });
    }

    _buildModels(models) {
        this._panel.add_child(label('TOKENS BY MODEL · 30 DAYS', 'ai-heading'));
        if (!models.length) {
            this._panel.add_child(label('No usage yet', 'ai-muted'));
            return;
        }
        const max = Math.max(1, ...models.map(m => m.tokens));
        for (const m of models) {
            const row = new St.Widget({
                style_class: 'ai-model',
                layout_manager: new Clutter.BinLayout(),
                width: MODEL_ROW_WIDTH,
            });
            row.add_child(new St.Widget({
                style_class: 'ai-model-fill',
                width: Math.round(MODEL_ROW_WIDTH * m.tokens / max),
                x_align: Clutter.ActorAlign.START,
                y_expand: true,
                y_align: Clutter.ActorAlign.FILL,
            }));
            const text = new St.BoxLayout({style_class: 'ai-model-text', x_expand: true});
            text.add_child(label(m.name, 'ai-model-name', {x_expand: true}));
            text.add_child(label(formatTokens(m.tokens), 'ai-model-value'));
            row.add_child(text);
            this._panel.add_child(row);
        }
    }

    destroy() {
        this._cancellable.cancel();
        super.destroy();
    }
});

export default class AiUsageExtension extends Extension {
    enable() {
        this._indicator = new AiUsageIndicator(`${this.path}/usage.py`);
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');
        this._indicator.fetch();

        this._fetchId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, FETCH_SECONDS, () => {
            this._indicator.fetch();
            return GLib.SOURCE_CONTINUE;
        });
        this._renderId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, RENDER_SECONDS, () => {
            this._indicator.render();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        for (const id of [this._fetchId, this._renderId]) {
            if (id)
                GLib.source_remove(id);
        }
        this._fetchId = this._renderId = 0;
        this._indicator?.destroy();
        this._indicator = null;
    }
}
