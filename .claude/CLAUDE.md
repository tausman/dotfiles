# User-level Claude Code Configuration

## User
- Name: Tausman
- Git branch prefix: tausman/

## Preferences
- No emojis unless explicitly requested
- Concise responses
- Use vim keybindings conventions when relevant

## Dotfiles
- Located at ~/dotfiles
- Aliases are in ~/.aliases.zsh (symlinked from ~/dotfiles/aliases.zsh)
- Tmux config at ~/.tmux.conf
- Neovim config at ~/.config/nvim (symlinked from ~/dotfiles/nvim)

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
