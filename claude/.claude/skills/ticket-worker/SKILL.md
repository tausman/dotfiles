---
name: ticket-worker
description: End-to-end ticket workflow. Takes a Jira ticket number, fetches context, orchestrates /research-codebase, /create-plan, /implement-plan, and /create-pr skills. Use when user provides a ticket number and wants the full research-plan-implement-PR cycle.
---

# Ticket Worker

Orchestrates the full ticket lifecycle: research, plan, implement, PR.

## Workflow

### 1. Parse Input

- Extract ticket key from args (e.g., `CRED-2174`, `LOGS-1234`)
- Validate format: `<PROJECT>-<NUMBER>`
- This ticket key is used for all artifact naming throughout the workflow

### 2. Fetch Ticket Context

- Use `mcp__atlassian__getJiraIssue` to fetch ticket details (summary, description, acceptance criteria, comments)
- If MCP tool is unavailable, ask user to paste the ticket context directly
- Extract:
  - **Title/Summary**
  - **Description** and acceptance criteria
  - **Linked tickets** or epics for broader context
  - **Comments** that may contain implementation hints

### 3. Gather User Direction

Only ask if the ticket context is genuinely ambiguous or missing critical information (e.g., no description, unclear which repo). Otherwise, infer from the ticket and proceed.

If you must ask, cover:
1. **Additional context or research areas** - Anything beyond the ticket to investigate?
2. **Implementation preferences or constraints** - Specific approach, tech choices, things to avoid?
3. **Which repos are involved** - Where does the work happen?

The user may have no additional direction -- that's fine. Proceed with what the ticket provides.

### 4. Derive Research Areas

Automatically analyze the ticket context to identify research areas. Do this **regardless** of whether the user provides direction -- even if they do, augment their areas with your own.

**How to derive research areas from the ticket:**

- **Problem domain** - What system, feature, or component does this ticket touch? Research how it currently works at a high level.
- **Affected code areas** - Identify entry points, key modules, or services mentioned or implied by the ticket. Locate them, understand their role.
- **Similar patterns / prior art** - Are there analogous features, migrations, or fixes already done in the codebase? Find examples to learn from.
- **Dependencies and boundaries** - What other systems, APIs, or data flows interact with the affected area? Understand the edges.
- **If a solution direction is known** - Research areas that would inform or validate that approach (e.g., "if we're adding a new RPC, how are existing RPCs structured?"). Do NOT research implementation details -- focus on the shape and patterns.
- **If no solution is known** - This is a pure exploration task. Focus research on deeply understanding the problem space so a solution can emerge during planning.

**Research scope guardrails:**

- Stay **high level** -- understand the problem area, not implementation minutiae
- Focus on **what exists and how it works**, not on how to build the solution
- Look for **pointers and patterns**, not step-by-step implementation paths
- Each research area should be a question or topic, not a task (e.g., "How does the auth token refresh flow work?" not "Implement token refresh")
- Aim for 3-6 research areas. More than that means you're going too deep.

### 5. Route Inputs

Classify all direction (user-provided and self-derived) into two categories:

**Research-oriented** (feeds to /research-codebase):
- Understanding the problem domain and affected systems
- How things currently work
- Similar patterns or prior art in the codebase
- Dependency and boundary exploration
- Areas that inform a potential solution direction

**Plan-oriented** (held for /create-plan):
- "Use approach X for this"
- "Make sure to consider Y constraint"
- "Break it into small PRs"
- Implementation preferences

### 6. Execute /research-codebase

Invoke the research-codebase skill with:
- Ticket context (title, description, acceptance criteria)
- All research areas (user-provided + self-derived)
- Repos to investigate

Output: `~/artifacts/<TICKET>/research-<TICKET>.md` (e.g., `~/artifacts/CRED-2174/research-CRED-2174.md`)

**After research completes:** Proceed directly to planning. Do not pause for confirmation.

### 7. Execute /create-plan

Invoke the create-plan skill with:
- Research document as input context
- Ticket context
- Plan-oriented user direction
- Any follow-up insights from the research phase

Output: `~/artifacts/<TICKET>/plan-<TICKET>.md` (e.g., `~/artifacts/CRED-2174/plan-CRED-2174.md`)

**After plan completes:** Proceed directly to implementation. Do not pause for approval.

### 8. Execute /implement-plan

**Single-repo work:**

Invoke the implement-plan skill with:
- Plan document path
- Ticket ID for progress tracking

**Multi-repo work (agent teams):**

When the plan involves multiple repos, use the Agent tool to spawn a team of sub-agents -- one per repo. Each agent works independently in its own repo:

1. **Spawn one agent per repo** - Each agent receives:
   - The full plan document
   - The subset of phases that apply to its repo
   - The ticket ID for artifact naming
   - Instructions to invoke `/implement-plan` for its phases
2. **Coordinate dependencies** - If repo B depends on repo A's changes (e.g., proto definitions, shared libraries), repo A's agent must complete its relevant phases first. Sequence agent launches accordingly.
3. **Each agent produces its own artifacts** - `progress-<TICKET>.md` in its repo's working directory
4. **Collect results** - After all agents complete, gather progress docs, bookmarks, and any blockers from each repo

Output per repo: `~/artifacts/<TICKET>/progress-<TICKET>-<repo-name>.md` (e.g., `~/artifacts/CRED-2174/progress-CRED-2174-ace.md`)

The implement-plan skill handles:
- Phase-by-phase execution with verification
- jj commits per phase
- Progress tracking
- Multi-repo dependency handling
- Plan amendments if needed

### 9. Create PRs

After implementation completes, create PRs. **All PRs are always created as drafts.**

Determine PR structure from the plan -- the plan marks bookmark boundaries, so each bookmark becomes a PR:

**Single bookmark:** Invoke `/create-pr`.

**Multiple bookmarks (single or multi-repo):** Invoke `/create-pr-stack` with the ordered list of bookmarks per repo.

**Multi-repo:** Each repo gets its own PR stack (via `/create-pr-stack`). After all PRs are created across all repos, update every PR description to include the full cross-repo PR stack (see "Cross-Repo PR Stack" below).

#### Cross-Repo PR Stack

When PRs span multiple repos, the `## PR Stack` section uses subsections grouped by repo:

```markdown
## PR Stack

### repo-name-1
- **#101 CRED-2174 Add proto definitions** (this PR)
- #102 CRED-2174 Add DB layer

### repo-name-2
- #45 CRED-2174 Add gRPC client integration
- #46 CRED-2174 Add cleanup job
```

Rules:
- Every PR across all repos gets this full cross-repo stack section
- Group by repo name, each repo is a `###` subsection
- Within each repo, list PRs in stack order (base to top)
- Bold the current PR and mark with `(this PR)`
- Use full URL for cross-repo PR links (GitHub doesn't auto-link `#num` across repos):
  `[repo-name#45](https://github.com/org/repo-name/pull/45)`
- Within the same repo, `#<number>` shorthand is fine

Update cross-repo stacks with:
```bash
# For each PR in each repo
gh pr edit <number> --repo <org/repo> --body "$(cat <<'EOF'
<updated body with cross-repo PR Stack>
EOF
)"
```

### 10. Artifact Summary

On completion (or when blocked), present a summary of all artifacts:

```
Ticket: <TICKET> - <Title>
Artifacts directory: ~/artifacts/<TICKET>/

Artifacts:
- research-<TICKET>.md           - Codebase research findings
- plan-<TICKET>.md               - Implementation plan
- progress-<TICKET>.md           - Implementation progress (single-repo)
- progress-<TICKET>-<repo>.md   - Implementation progress (per repo if multi-repo)

PRs (all drafts):
- <repo-1>: #101 <title> (<URL>)
- <repo-1>: #102 <title> (<URL>)
- <repo-2>: #45 <title> (<URL>)

Status: [Complete | Blocked at Phase N | In Progress]
```

## Multi-Repo Planning

When multiple repos are identified in step 3, the plan created in step 7 must reflect this:

- **Group phases by repo** - Clearly indicate which repo each phase targets
- **Mark cross-repo dependencies** - If phase 3 in repo B depends on phase 2 in repo A, make this explicit
- **Identify shared artifacts** - Proto definitions, config files, or libraries that bridge repos
- **Sequence for correctness** - Upstream repos (e.g., proto definitions, shared libs) should be implemented before downstream consumers

Example plan structure for multi-repo work:

```markdown
## Implementation Phases

### repo-a (upstream)
1. Add proto definitions
2. Implement server-side handler

### repo-b (downstream, depends on repo-a phase 1)
3. Generate client stubs from new protos
4. Integrate client into service
```

## Handling Interruptions

If the workflow is interrupted or blocked at any stage:

1. **Save state** - All artifacts are already on disk with ticket-based names
2. **Explain status** - Which phase completed, what's pending
3. **Resume instructions** - User can re-invoke `/ticket-worker <TICKET>` and point to existing artifacts to skip completed phases

## Key Principles

- **Run autonomously** - Execute research, plan, and implement back-to-back without pausing for confirmation. Only stop if genuinely blocked (e.g., MCP unavailable, ambiguous requirements with no reasonable default, multi-repo dependency that can't be inferred).
- **Artifacts are durable** - All docs use ticket-based naming and persist on disk
- **Route inputs intelligently** - Research questions to research, plan constraints to planning
- **Don't skip phases** - Research informs planning, planning informs implementation
- **Surface blockers early** - Multi-repo dependencies, missing context, ambiguous requirements
- **PRs are always drafts** - No exceptions, across all repos
- **Agent teams for multi-repo** - Each repo gets its own agent; coordinate via dependency ordering
- **Cross-repo PR stack** - All PRs across all repos are linked in every PR description
