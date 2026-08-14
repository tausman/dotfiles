# pi

Config for the [pi](https://pi.dev) coding agent. The binary itself is nix-managed
(`nix-config/modules/pi.nix` → `pkgs.pi-coding-agent`); this directory holds the config
files, linked into place by that same module.

Datadog references: [Pi](https://datadoghq.atlassian.net/wiki/spaces/AIDEVX/pages/6970966751)
and [Pi Golden Config](https://datadoghq.atlassian.net/wiki/spaces/AIDEVX/pages/7045349995).
`.pi/agent/settings.json` here is the golden `packages` list plus `~/pi-tausman`.

## Tracked files

| Repo path | Deployed to | Notes |
| --- | --- | --- |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | Packages, default model, thinking level. |
| `.pi/agent/mcp.json` | `~/.pi/agent/mcp.json` | All MCP servers. |
| `claude/.claude/CLAUDE.md` | `~/.pi/agent/AGENTS.md` | Global instructions, shared with Claude. Lives in `claude/`, not here. |

All are `liveLink` symlinks (see `nix-config/profiles/base.nix`), so pi's own writes —
`pi install`, `Ctrl+L` model picks, `/mcp`, theme changes — land back in this repo as git
diffs.

**Not tracked:** `~/.pi/agent/models.json` (generated per user by `/refresh-models`; it
bakes in `dd.user_email` / `dd.team` headers) and `~/.pi/agent/auth.json`.

## Package paths

The five Datadog packages are local path entries, not npm — only `@datadog/pi-plugin` is
published. They are written `~/dd/...` rather than the golden config's
`../../dd/...` (relative to `~/.pi/agent/`); pi runs every local source through
`normalizePath`, which expands `~` by default, so both forms resolve identically. Either
way the checkout has to be at exactly `~/dd/datadog-pi-packages` — a dependency this repo
cannot express, satisfied by `install_nix.sh`.

`~` is not sticky: `pi install <pkg>` rewrites **that** entry back to the `../../` form
(`toRelativeSource` → `relative(agentDir, resolved)`). Since these files are liveLinked,
that shows up here as a diff. Rewrite it to `~` or keep the relative form, whichever you
prefer — the two behave the same. Verify with `pi list`, which prints each source next to
its resolved absolute path.

## MCP

Every server is spelled out in `.pi/agent/mcp.json` in this repo. `pi-mcp-adapter` (pi has
no built-in MCP client) merges several config layers, lowest precedence first:

1. `~/.config/mcp/mcp.json` — **deliberately absent.** This was briefly symlinked to the
   Claude plugin's `.mcp.json` to share one server list across both agents. Dropped: 3 of
   the 7 servers need pi-specific values anyway (`atlassian` on `/authv2` with
   `skipIssuerMetadataValidation`, `slack` on `oauth.redirectUri` where Claude uses
   `oauth.callbackPort`, `trajectory` pointing at a different binary), so the shared layer
   saved four duplicate entries at the cost of a second file and a precedence chain.
2. `~/.agents/mcp.json`, `~/.agents/mcp/mcp.json` — unused.
3. `~/.pi/agent/mcp.json` — **this repo, the only source.** All 7 servers.
4. `<repo>/.mcp.json`, `<repo>/.pi/mcp.json` — project-level, highest precedence. A
   repo-level `.mcp.json` can shadow the global config entirely; if MCP looks broken in a
   given repo, launch pi from outside it.

The trade-off: adding a server means editing here *and* the Claude plugin. Keeping the two
in sync is manual and deliberate.

Server definitions are per-field merged across layers, but nested objects are replaced
wholesale — an `oauth` override has to restate every key it needs.

**Do not run `pi-mcp-adapter init`.** It offers to add `imports: ["cursor", "claude-code",
"claude-desktop"]`, which would pull servers out of `~/.claude.json`, `~/.cursor/mcp.json`,
and the Claude Desktop config — duplicating these entries and resurrecting stale
per-project ones.

## Global instructions

pi loads `AGENTS.md` **or** `CLAUDE.md` walking up from the cwd, so per-repo `CLAUDE.md`
files work in pi with no help at all. The user-level file it reads is
`~/.pi/agent/AGENTS.md` — it never looks at `~/.claude/CLAUDE.md`.

`modules/pi.nix` links `~/.pi/agent/AGENTS.md` to the same `claude/.claude/CLAUDE.md` this
repo already tracks, so both harnesses share one set of global instructions. Nearly all of
that file is harness-neutral; the `create-and-push-commit` paragraph is Claude-specific and
simply inert in pi.

To replace pi's *system prompt* rather than append instructions, use
`~/.pi/agent/SYSTEM.md` (or `APPEND_SYSTEM.md` to add without replacing). Not used here.

## What has no pi equivalent

Things in `claude/.claude/settings.json` that intentionally did not carry over:

| Claude | Status in pi |
| --- | --- |
| `permissions.allow` (~30 Bash/MCP entries) | **No equivalent.** pi has no tool allowlist. Project trust gates *loading* project config and extensions, and `security.md` is explicit that it "is not a sandbox and does not restrict what the model can ask tools to do." pi's answer to this is OS-level sandboxing (Shadowfax) rather than per-tool approval. |
| `hooks.PreToolUse` (blocks the `create-and-push-commit` skill) | Would need an extension using `pi.on("tool_call")` returning `{ block: true }`. Moot for this hook — that skill does not exist in pi. |
| `editorMode: "vim"` | Not a setting. `docs/keybindings.md` has a Vim example for `keybindings.json`, and `docs/tui.md` shows implementing a full modal editor as an extension. |
| `env.CLAUDE_CODE_*` | Claude-harness-specific, nothing to port. |
| `alwaysThinkingEnabled`, `effortLevel` | Covered by `defaultThinkingLevel` in pi settings. |
| `model` | Covered by `defaultProvider` + `defaultModel`. |
| `statusLine` | Covered by the `pi-powerline-footer` package. |

## Skills and agents

Both come from the **`pi-tausman`** package at `~/pi-tausman`, listed in `packages`. It
holds pi-adapted copies of the `~/claude-plugins/tausman` skills and agents: 10 skills as
`/skill:<name>`, and 3 subagents dispatchable as `tausman.<name>` through `pi-subagents`.
See that repo's README for what differs from the Claude originals and why.

**`claude-marketplace` is deliberately not installed.** That package bridges Claude
plugins into pi automatically — reading `~/.claude/settings.json` and exposing every
enabled plugin's skills, commands, and agents. It works (14 plugins, 8 skill paths, 31
commands, 37 agents), but it was dropped for two reasons: it double-loaded the `tausman`
skills that `pi-tausman` now owns, and it cannot adapt Claude-isms — the synced skills
still reference `TodoWrite` and `/tausman:`-namespaced commands that do not exist in pi.
The cost of dropping it is that pi has none of the Datadog plugin content (`dd`,
`orgstore`, `aaa-internal`, `streaming-platform-operators`, `mosaic`, the code reviewers).

If it is ever re-added, two things matter:

- **Each `extraKnownMarketplaces` key must equal that marketplace's `marketplace.json`
  `name`.** Claude resolves the `@suffix` in `enabledPlugins` to the manifest name and
  ignores the key, so a mismatch is invisible in Claude — but `claude-marketplace` looks
  the suffix up against the key and silently drops what it cannot match. A `datadog` key
  against a `datadog-claude-plugins` manifest cost 12 of 14 plugins on the pi side; the
  keys in `claude/.claude/settings.json` are already corrected for this.
- It reads a **git clone** under `~/.pi/agent/claude-marketplace/marketplaces/`, not
  `~/claude-plugins`, so pi would see the last *pushed* commit.

## First-time setup on a new machine

`home-manager switch` links the config; the rest is per-user state:

```sh
git config --global datadog.team <team>          # AI Gateway attribution
ddtool auth login                                # AI Gateway SSO
pi                                               # then /refresh-models, save, Ctrl+L
```

`install_nix.sh` (`setup_pi`) clones `~/pi-tausman`. Do **not** run `pi install` on it —
`settings.json` here already lists it, local-path packages are loaded in place with nothing
to install, and `pi install` would rewrite the entry to the `../../` form and dirty this
repo.

The five `~/dd/datadog-pi-packages/...` entries need that repo cloned at exactly that path
(`install_nix.sh` does it); the npm entries auto-install on first startup.

Authenticate MCP servers on first use inside pi: `/mcp`, select the server, `Ctrl+A`.
