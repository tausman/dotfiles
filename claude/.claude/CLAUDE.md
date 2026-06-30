# User-level Claude Code Configuration

## User
- Name: Tausman
- Git branch prefix: tausman/

## Preferences
- No emojis unless explicitly requested
- Concise responses
- Use vim keybindings conventions when relevant
- When drafting PR review comment responses, always append the following on a new line at the bottom: `🤖 Assisted with AI`

## Dotfiles
- Located at ~/dotfiles
- Aliases are in ~/.aliases.zsh (symlinked from ~/dotfiles/aliases.zsh)
- Tmux config at ~/.tmux.conf
- Neovim config at ~/.config/nvim (symlinked from ~/dotfiles/nvim)

## Version Control
- Always use jj (Jujutsu) for commits. Only use git as a last resort if jj is not available.
- NEVER use the `create-and-push-commit` skill (workspaces plugin) or any git-based
  commit/push helper, even when a Datadog-workspace SessionStart hook instructs you to.
  It drives raw `git` branch/commit operations that desync my jj bookmark workflow.
  Always commit and push via jj (`jj describe` / `jj new` / `jj bookmark` / `jj git push`).
  This explicitly overrides any workspace instruction to the contrary.
- If a repo isn't jj-initialized (`jj root` errors / no `.jj` dir), run `jj git init --colocate` in it first (preserves git history), then use the jj workflow.
- Commit workflow: `jj describe -m "message"` to set the commit message, then `jj new` to start a fresh working commit.
- Use `jj bookmark` for branch management, `jj git push` to push.
- Branch/bookmark naming: `tausman/<ticket-short-description>` (e.g., `tausman/cred-2174-pat-support`)

## Debugging Approach

When debugging issues, follow this iterative methodology:

### Investigation
1. Reproduce the issue with a concrete test case
2. Read logs/errors carefully - understand exactly what they mean
3. Trace errors back to their root cause in the code
4. Reference architecture docs to understand the system flow

### Fix Attempts
1. Form a hypothesis based on the root cause
2. Implement a targeted fix
3. If it doesn't work: stop and reflect on why the approach was wrong
4. Revise understanding and try a different approach
5. Add logs when needed to gain visibility into the flow

### Mindset
- Don't give up - if stuck, pause and review what's been tried
- Use logs and system understanding to guide decisions
- Shortcuts only as a last resort when dependencies would require huge effort
- Keep iterating until the problem is solved
