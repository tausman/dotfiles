# pi

Config for the [pi](https://pi.dev) coding agent. The binary itself is nix-managed
(`nix-config/modules/pi.nix` → `pkgs.pi-coding-agent`); this directory holds the config
files, linked into place by that same module.

Datadog references: [Pi](https://datadoghq.atlassian.net/wiki/spaces/AIDEVX/pages/6970966751)
and [Pi Golden Config](https://datadoghq.atlassian.net/wiki/spaces/AIDEVX/pages/7045349995).
`.pi/agent/settings.json` here is the golden `packages` list plus `~/pi-tausman`,
with a separate `skills` entry for the shared Credential Management on-call skill.

## Tracked files

| Repo path | Deployed to | Notes |
| --- | --- | --- |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | Packages, shared skill paths, default model, thinking level. |
| `.pi/agent/mcp.json` | `~/.pi/agent/mcp.json` | All MCP servers. |
| `claude/.claude/CLAUDE.md` | `~/.pi/agent/AGENTS.md` | Global instructions, shared with Claude. Lives in `claude/`, not here. |

Home Manager deploys these as `liveLink` symlinks (see
`nix-config/profiles/base.nix`), so writes through those links land back in this repo.
Some tools replace a file rather than writing through its symlink: check `readlink -f`
before assuming a live file matches the repo. In particular, this host's MCP config
is currently a separate file with local overrides; preserve those before a rebuild.

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

Pi 1.4 provides the MCP client. **`pi-mcp-adapter` is not installed**, and the built-in
`mcp` extension remains enabled. Installing the adapter again causes a `/mcp` command
collision and replaces native support.

Native Pi reads:

1. `~/.pi/agent/mcp.json` — user-wide servers, declared in this repo.
2. `<repo>/.pi/mcp.json` — trusted project overrides. A complete server entry replaces
   the user-wide entry. An entry containing only `enabled`, `exposure`, or
   `toolExposure` overrides those fields without replacing the connection.

Native Pi does **not** import the adapter's shared `~/.config/mcp/mcp.json`,
`~/.agents/mcp.json`, root `.mcp.json`, or Claude/Cursor configuration layers.
The Claude plugin's server list remains separately maintained.

Most servers use `exposure: "deferred"`: native `tool_search` discovers tools without
putting every schema in the prompt. Pi connects enabled servers at startup; the old
adapter's `lifecycle` and `directTools` settings are not native controls.

Migration details:

- **Atlassian:** uses the [recommended v2 endpoint](https://support.atlassian.com/atlassian-ai-gateway/docs/get-started-with-the-atlassian-remote-mcp-server/).
  The old `auth: "oauth"` and `skipIssuerMetadataValidation` adapter fields are removed;
  native OAuth discovery keeps issuer validation enabled.
- **Slack:** the registered callback is `http://localhost:3118/callback`, configured
  with native `oauth.callbackUrl` (not the adapter's `redirectUri`).
- **Datadog:** preserves this host's production and staging MCP endpoints. The
  Datadog Pi plugin's `/datadog` sign-in is separate from native MCP sign-in.
- **Orgstore:** the MCP process can start without a database, but SQL calls require
  Postgres or its tunnel at `localhost:5435` for `aaa_authn`.
- **Trajectory:** `trajectory-mcp.cjs` resolves the active installed extension bundle
  from its manifest, with a fallback for older flat installations. No Mac username or
  bundle hash is pinned in the shared config. The Trajectory extension must already
  be installed; this launcher does not install it or change capture/telemetry settings.
- **Google Workspace:** intentionally retains its existing `mcp-remote` configuration
  and authentication. Its separate OAuth scope failure was not addressed by this migration.

Native OAuth credentials live in `~/.pi/agent/mcp-auth.json`, outside this repo. They
are separate from the adapter's credential store: migration requires fresh sign-ins,
and does not copy or delete old credentials. Use `pi mcp login <server>` or
`/mcp login <server>` for Atlassian, Slack, and each Datadog MCP connection.
Over SSH, the native sign-in UI accepts the browser's redirected URL if its loopback
callback cannot reach this machine.

Run `pi mcp list --json` to validate configuration and connect enabled servers. This
also attempts Google Workspace; a failure there does not mean the other servers failed.
Restart Pi after removing the adapter; use `/reload` for subsequent server config changes.

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

## Built-in tools

Pi enables **four** builtins by default — `read`, `bash`, `edit`, `write`. `grep`, `find`,
and `ls` are opt-in. The nixpkgs derivation puts `rg` and `fd` on Pi's PATH, so shell
searches work without enabling additional tools.

Pi 1.4 supports additive `defaultTools` entries in settings, such as
`["+grep", "+find", "+ls"]`, and additive CLI flags such as `--tools +grep`.
Native MCP automatically enables `tool_search` for deferred servers and `codemode`
for codemode servers.

Avoid a shell alias with a plain-name `-t` allowlist: it can hide extension tools such
as `subagent` and `web_search`. Native MCP tools have separate exposure/filtering rules;
see Pi's installed `docs/cli.md` before restricting them.

The `pi-tausman` agents leave `tools` unset on purpose. In `pi-subagents` an explicit list
is a strict allowlist with no additive form, so naming `grep`/`find`/`ls` would cost the
agents every extension tool (`mcp`, `web_search`, `datadog`, `ctx_*`). Omitting it gives
them the four builtins plus all extensions — 29 tools, verified — which is the closest match
to the "All tools" access they have in Claude. They use `bash` + ripgrep for search, exactly
like the parent session does.

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

Personal skills and agents come from the **`pi-tausman`** package at `~/pi-tausman`,
listed in `packages`. It holds pi-adapted copies of the `~/claude-plugins/tausman` skills
and agents: 10 skills as `/skill:<name>`, and 4 subagents dispatchable as
`tausman.<name>` through `pi-subagents`. See that repo's README for what differs from
the Claude originals and why.

### Shared on-call skill

The top-level `skills` array also loads
`~/dd/team-aaa-internal-tools/credential-management/skills/oncall` directly from a
retained checkout of [ddoghq/team-aaa-internal-tools](https://github.com/ddoghq/team-aaa-internal-tools).
This adds `/skill:oncall` without importing the whole team package's other,
potentially Claude-specific skills or copying team content into this repo.
Keep the full skill directory, including `references/`, in that checkout.

After changing the registration or updating the checkout, run `/reload` or restart Pi.
Verify that `/skill:oncall` loads the shared file and includes `catch-up`. A read-only
smoke test is:

```text
/skill:oncall start <existing-weekly-report-url>
/skill:oncall recap
```

The skill uses the existing authorized Datadog HQ, Slack, Atlassian, and GitHub
connections; loading it does not configure tools or grant permissions. Notebook
changes require a preview and explicit approval. See the
[team setup guide](https://datadoghq.atlassian.net/wiki/spaces/AAAAUTHN/pages/7240515945).

This registration follows live checkout contents, including branch switches and
uncommitted edits. Update the checkout explicitly with the jj workflow; `pi update`
does not update local-path skills. Keep skill development in a separate worktree.

### Claude plugin bridge

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

The shared on-call skill separately requires a current checkout of
`ddoghq/team-aaa-internal-tools` at `~/dd/team-aaa-internal-tools`.
`install_nix.sh` (`setup_repos`) provisions it in full and fast modes, but not in
nix-only mode. To clone it separately (requires the `ddoghq.github.com` SSH alias
from `git-config-tool setup`), use:

```sh
jj git clone --colocate git@ddoghq.github.com:ddoghq/team-aaa-internal-tools.git ~/dd/team-aaa-internal-tools
```

If the directory already exists, inspect it and update it without overwriting local
work; older checkouts may still point to `DataDog/team-aaa-internal-tools` and lack the
skill. No additional `pi install` is needed because `settings.json` registers its path.

Authenticate native MCP servers with `/mcp`, select the server and choose Sign in,
or run `pi mcp login <server>` from a terminal. Google Workspace's `mcp-remote`
authentication remains separate.
