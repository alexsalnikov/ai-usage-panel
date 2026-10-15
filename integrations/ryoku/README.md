# AI Usage

A Ryoku shell plugin (`ai-usage`): the Ryoku port of
[ai-usage-panel](https://github.com/alexsalnikov/ai-usage-panel). The bar shows
Claude's current session limit (or today's tokens across all tools); a click
opens a panel with tabs for Claude, Grok and Antigravity:

- Claude plan limits (session, weekly, per-model weekly) with reset countdowns.
- Tokens by day for the last 7 days.
- Tokens by model for the last 30 days.

## What runs

`bin/ai-usage` (Python 3, standard library only) runs every *Refresh every*
minutes, when the plugin loads, and when you press REFRESH in the panel. It
prints one JSON object that `service/Main.qml` reads.

`bin/ai-usage` is a copy of the repository's `backend/usage.py` (Ryoku plugins
must be self-contained and may not ship symlinks). The only difference is the
cache path, which moves under `ryoku/plugins/ai-usage` as Ryoku requires. Keep
the two in sync when the backend changes.

## What it reads

- `~/.claude/projects/**/*.jsonl` — Claude Code transcripts (token counts).
- `~/.grok/sessions/**/updates.jsonl` — Grok CLI sessions.
- `~/.gemini/antigravity-cli/conversations/*.db` and
  `~/.gemini/antigravity/conversations/*.db` — Antigravity conversation
  databases, opened read-only.
- `~/.claude/.credentials.json` — the OAuth login Claude Code already saved,
  only when *Fetch Claude plan limits* is on.

## Network

With *Fetch Claude plan limits* on, the script calls
`https://api.anthropic.com/api/oauth/usage` (the endpoint Claude Code's `/usage`
uses) with Claude Code's saved access token. The token is sent only to
`api.anthropic.com`, and it is never written anywhere. Turn the setting off and
the plugin makes no network calls at all.

## What it writes

Only a parse cache at `$XDG_CACHE_HOME/ryoku/plugins/ai-usage/files.json`
(per-file token records, keyed by mtime and size, so a refresh only re-reads
logs that grew). Delete it at any time.

## Settings

| key         | type   | default | description                                   |
| ----------- | ------ | ------- | --------------------------------------------- |
| barLabel    | choice | session | Bar label: Claude session % or today's tokens |
| fetchLimits | toggle | true    | Fetch Claude plan limits from api.anthropic.com |
| defaultTab  | choice | claude  | The tab the panel opens on                    |
| intervalMin | int    | 10      | Refresh interval in minutes (1–60)            |

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

It lists under **Community** in QS Bar Settings.

## Author

Alex Salnikov <alex.salnikov.il@gmail.com>: this plugin is community-made (`official` is false).
