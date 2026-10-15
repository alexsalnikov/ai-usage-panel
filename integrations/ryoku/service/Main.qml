pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml: runs bin/ai-usage on a timer and holds its JSON for the
// glyph and the panel. The script reads the Claude Code, Grok CLI and
// Antigravity logs, and (unless limits are off) asks api.anthropic.com for
// Claude's plan limits with the login Claude Code already saved.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property int intervalMin: settings ? (settings.intervalMin ?? 10) : 10
    readonly property bool fetchLimits: settings ? (settings.fetchLimits ?? true) : true
    readonly property string barLabel: settings ? (settings.barLabel ?? "session") : "session"

    // The last good result; kept when a later run fails.
    property var usage: null
    property string error: ""
    property bool busy: false
    // The panel's open tab: claude, grok, antigravity. View state only.
    property string tab: settings ? (settings.defaultTab ?? "claude") : "claude"

    readonly property var tabs: [
        { id: "claude", label: "Claude" },
        { id: "grok", label: "Grok" },
        { id: "antigravity", label: "Antigravity" }
    ]

    readonly property var session: {
        const lims = svc.usage && svc.usage.claude ? (svc.usage.claude.limits || []) : [];
        return lims.find(l => l.label === "Session") || null;
    }

    readonly property real todayTokens: {
        if (!svc.usage) return 0;
        let n = 0;
        for (const t of svc.tabs) {
            const days = svc.usage[t.id] ? svc.usage[t.id].days : [];
            if (days && days.length) n += days[days.length - 1].tokens;
        }
        return n;
    }

    readonly property string label: {
        if (!svc.usage) return "AI";
        if (svc.barLabel === "tokens") return svc.formatTokens(svc.todayTokens);
        return svc.session ? Math.round(svc.session.percent) + "%" : "AI";
    }

    function formatTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B";
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "K";
        return String(Math.round(n));
    }

    function resetsIn(iso) {
        if (!iso) return "";
        const mins = Math.max(0, Math.round((new Date(iso).getTime() - Date.now()) / 60000));
        const d = Math.floor(mins / 1440), h = Math.floor(mins % 1440 / 60), m = mins % 60;
        if (d) return "Resets in " + d + "d " + h + "h";
        if (h) return "Resets in " + h + "h " + m + "m";
        return "Resets in " + m + "m";
    }

    function refresh() {
        if (!svc.pluginApi || proc.running) return;
        const cmd = [svc.pluginApi.pluginDir + "/bin/ai-usage"];
        if (!svc.fetchLimits) cmd.push("--no-limits");
        proc.command = cmd;
        svc.busy = true;
        proc.running = true;
    }

    onPluginApiChanged: refresh()
    onFetchLimitsChanged: refresh()

    Process {
        id: proc

        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }

        onExited: function(code) {
            svc.busy = false;
            if (code !== 0) {
                svc.error = "ai-usage exited " + code + (err.text ? ": " + err.text.trim().split("\n").pop() : "");
                return;
            }
            try {
                svc.usage = JSON.parse(out.text);
                svc.error = "";
            } catch (e) {
                svc.error = "Could not read usage output";
            }
        }
    }

    Timer {
        interval: Math.max(1, svc.intervalMin) * 60 * 1000
        running: true
        repeat: true
        onTriggered: svc.refresh()
    }
}
