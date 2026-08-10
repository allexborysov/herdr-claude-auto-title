# herdr-claude-auto-title

Auto-generated session titles for [Herdr](https://herdr.dev) panes running Claude Code. Your first message in a session is summarized into a short kebab-case slug and shown in Herdr's agents sidebar:

```
agents

○ api · auth-refactor
  claude
● web · csv-export
  claude
```

## How it works

Herdr only renders display metadata pushed into it; this hook adds the generator on the Claude Code side:

```
Claude Code UserPromptSubmit hook (first prompt of the session)
  → ask Haiku for a 2-word kebab slug (one call per session, cached)
  → herdr pane report-metadata --source user:claude-title --title "<slug>"
  → Herdr sidebar renders it via the `pane` token
```

The hook runs detached, so Claude Code never waits on the LLM call. Later prompts hit a cache guard and exit in a few milliseconds. Outside Herdr it is a no-op. Titles are display-only; Herdr's state detection is untouched.

## Install

1. Copy the script:

   ```sh
   mkdir -p ~/.claude/hooks
   curl -fsSL https://raw.githubusercontent.com/allexborysov/herdr-claude-auto-title/master/herdr-auto-title.sh \
     -o ~/.claude/hooks/herdr-auto-title.sh
   chmod +x ~/.claude/hooks/herdr-auto-title.sh
   ```

2. Register it in `~/.claude/settings.json` (merge into your `hooks` block):

   ```json
   "UserPromptSubmit": [
     { "hooks": [{ "type": "command", "command": "~/.claude/hooks/herdr-auto-title.sh" }] }
   ]
   ```

3. Add the `pane` token to Herdr's sidebar rows (`~/.config/herdr/config.toml`):

   ```toml
   [ui.sidebar.agents]
   rows = [
     ["state_icon", "workspace", "pane"],
     ["agent"],
   ]
   ```

4. Restart Herdr and start a Claude Code session in a pane — the title appears a few seconds after your first message.

## License

MIT
