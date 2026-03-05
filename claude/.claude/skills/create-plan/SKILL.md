---
name: create-plan
description: Create detailed implementation plans with thorough research and iteration. Use when starting significant features spanning multiple files, planning refactors affecting architecture, working on multi-phase projects with milestones, establishing success criteria before coding, breaking down complex work, or documenting approach for non-trivial technical decisions.
---

# Create Implementation Plan (Generic)

## Input

- **Research document** (optional): If a research doc exists (e.g., `research-<TICKET>.md` or `YYYY-MM-DD-*.md`), read it fully as foundational context before planning
- **Ticket context** (optional): Ticket ID, description, acceptance criteria
- **User direction** (optional): Implementation preferences, constraints, approach guidance

## Workflow

### 1. Understand the Requirement

- Read all mentioned files completely (no partial reads)
- If a research document was provided, use it as primary context
- Present your informed understanding with specific file:line references
- Ask focused questions only about what research couldn't clarify
- Don't ask questions answerable through code exploration

### 2. Decompose and Plan Research

- Break task into composable research areas
- Identify components, patterns, concepts to investigate
- Use TodoWrite to track subtasks
- Think deeply about underlying patterns and constraints

### 3. Spawn Parallel Sub-Agents

**Codebase Research:**
- `codebase-locator` - Find WHERE files/components live
- `codebase-analyzer` - Understand HOW existing code works
- `codebase-pattern-finder` - Find similar implementations to learn from

**Agent Tips:**
- Start with locator agents to find what exists
- Use analyzer agents on promising findings
- Run multiple agents in parallel
- Tell agents what you're looking for, not how to search

### 4. Wait and Synthesize

Wait for ALL sub-agents, then:
- Compile results, prioritize live codebase as source of truth
- Include file paths and line numbers
- Highlight patterns, connections, architectural decisions
- Answer questions with concrete evidence

### 5. Propose Plan Structure

Present outline for approval:

```
## Overview
[1-2 sentence summary]

## Implementation Phases:
1. [Phase Name] - [What this accomplishes]
2. [Phase Name] - [What this accomplishes]
3. [Phase Name] - [What this accomplishes]
```

Get explicit user buy-in before investing in detailed planning.

### 6. Write the Plan

Save to:
- If a ticket ID is provided: `~/artifacts/<TICKET>/plan-<TICKET>.md` (e.g., `~/artifacts/CRED-2174/plan-CRED-2174.md`)
- Otherwise: `~/artifacts/misc/<short-description>/plan-<short-description>.md`
- Create the directory if it doesn't exist
- User can override the output path explicitly

**Structure:**
- **Overview** - Brief goal description
- **Current State Analysis** - What exists (file:line refs), what's missing, constraints
- **Desired End State** - What "done" looks like
- **Key Discoveries** - Findings with file:line refs
- **What We're NOT Doing** - Out-of-scope items
- **Implementation Approach** - High-level strategy

**Per phase:**
- Overview, changes required (file + specifics), success criteria, confirmation gate
- **Tests to add** - Explicit list of test cases to write for this phase's changes
- All prior tests must be passing before the phase is considered complete

**Test requirement rule:** Every phase that adds or modifies behavior MUST include new or updated tests. The only exceptions are:
1. No existing tests anywhere in the codebase (document this explicitly)
2. Adding tests is genuinely difficult due to external dependencies or infrastructure constraints (document the specific obstacle and propose a workaround or follow-up task)

If an exception applies, call it out explicitly in the phase so it is a conscious decision, not an omission.

**Bookmark boundaries (PR boundaries):**

Phases should be grouped into bookmarks. Each bookmark becomes a separate PR. Mark bookmark boundaries explicitly in the plan:

```markdown
### Phase 1: Add proto definitions
...

### Phase 2: Implement DB layer
...

--- BOOKMARK: tausman/<ticket>-proto-and-db ---

### Phase 3: Add gRPC server
...

### Phase 4: Add authorization
...

--- BOOKMARK: tausman/<ticket>-grpc-server ---
```

**When to create a new bookmark boundary:**
- When a logical unit of work is complete and independently reviewable
- When subsequent phases represent a distinct concern (e.g., moving from data layer to API layer)
- When the work so far is a meaningful, self-contained change

**Bookmark boundary success criteria:**
Every bookmark boundary MUST include these success criteria in the final phase before the boundary:
- All existing tests pass
- All new tests for the phases in this bookmark pass
- Code compiles / type checks / lints cleanly
- The codebase is in a shippable state (no half-finished work)

These are not optional -- they are embedded in the plan as explicit success criteria for the phase that ends at a bookmark boundary.

**End with:**
- **Testing Strategy** - Which test types apply (unit, integration, e2e), where test files live, how to run them
- **References** - Tickets, research, code refs

## Success Criteria Format

**Automated**: Tests, type check, lint, build

**Manual**: Feature works, performance acceptable, edge cases handled

## Key Principles

- File:line references and measurable criteria
- Phases with confirmation gates
- Research before proposing
- Consider backwards compatibility
- No open questions - research or ask first

## Multi-Repo Plans

When the work spans multiple repos, the plan must clearly reflect this:

- **Group phases by repo** - Use repo name as a heading, list that repo's phases underneath
- **Mark cross-repo dependencies** - If a phase in repo B depends on a phase in repo A, state this explicitly (e.g., "depends on repo-a phase 1")
- **Identify shared artifacts** - Proto definitions, config files, shared libraries that bridge repos
- **Sequence for correctness** - Upstream repos (protos, shared libs) before downstream consumers
- **Note which agent handles which repo** - When used with `/ticket-worker`, each repo gets its own agent

Example structure:

```markdown
## Implementation Phases

### repo-a (upstream)
1. Add proto definitions
2. Implement server-side handler

### repo-b (downstream, depends on repo-a phase 1)
3. Generate client stubs from new protos
4. Integrate client into service
```

## Common Implementation Patterns

**Database Changes:**
Schema → Store/Repository methods → Business logic → API endpoints → Client code

**New Features:**
Research patterns → Data model → Backend implementation → API → UI/Frontend

**Refactoring:**
Document current state → Incremental changes → Maintain backwards compatibility → Migration strategy

**API Changes:**
Document current behavior → Deprecation plan → New implementation → Migration guide → Old code removal

## Plan Amendments

When a plan is modified during implementation, append amendments to the plan doc:

```markdown
## Amendments

### [YYYY-MM-DD HH:MM] - <Short Description>
**Phase affected:** Phase N
**What changed:** [Description of the change]
**Why:** [Rationale - what was discovered during implementation]
**Impact:** [How this affects subsequent phases, if at all]
```

This keeps a clear audit trail of plan evolution without losing the original intent.

