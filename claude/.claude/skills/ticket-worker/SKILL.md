---
name: ticket-worker
description: End-to-end ticket workflow. Takes a Jira ticket number, fetches context, orchestrates /research-codebase, /create-plan, and /implement-plan skills. Use when user provides a ticket number and wants the full research-plan-implement cycle.
---

# Ticket Worker

Orchestrates the full ticket lifecycle: research, plan, implement.

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

Ask the user:

1. **Additional context or research areas** - Anything beyond the ticket to investigate?
2. **Implementation preferences or constraints** - Specific approach, tech choices, things to avoid?
3. **Which repos are involved** - Where does the work happen?

### 4. Route Inputs

Classify user direction into two categories:

**Research-oriented** (feeds to /research-codebase):
- "How does X currently work?"
- "Explore how Y is implemented"
- "Understand the flow of Z"
- General investigation areas

**Plan-oriented** (held for /create-plan):
- "Use approach X for this"
- "Make sure to consider Y constraint"
- "Break it into small PRs"
- Implementation preferences

### 5. Execute /research-codebase

Invoke the research-codebase skill with:
- Ticket context (title, description, acceptance criteria)
- Research-oriented user direction
- Repos to investigate

Output: `research-<TICKET>.md` (e.g., `research-CRED-2174.md`)

**After research completes:** Present a summary of findings to the user and confirm ready to proceed to planning.

### 6. Execute /create-plan

Invoke the create-plan skill with:
- Research document as input context
- Ticket context
- Plan-oriented user direction
- Any follow-up insights from the research phase

Output: `plan-<TICKET>.md` (e.g., `plan-CRED-2174.md`)

**After plan completes:** The plan skill will get user approval on the plan structure before finalizing.

### 7. Execute /implement-plan

Invoke the implement-plan skill with:
- Plan document path
- Ticket ID for progress tracking

Output: `progress-<TICKET>.md` (e.g., `progress-CRED-2174.md`)

The implement-plan skill handles:
- Phase-by-phase execution with verification
- jj commits per phase
- Progress tracking
- Phase gates with user confirmation
- Multi-repo dependency handling
- Plan amendments if needed

### 8. Artifact Summary

On completion (or when blocked), present a summary of all artifacts:

```
Ticket: <TICKET> - <Title>

Artifacts:
- research-<TICKET>.md  - Codebase research findings
- plan-<TICKET>.md      - Implementation plan
- progress-<TICKET>.md  - Implementation progress

Status: [Complete | Blocked at Phase N | In Progress]
```

## Handling Interruptions

If the workflow is interrupted or blocked at any stage:

1. **Save state** - All artifacts are already on disk with ticket-based names
2. **Explain status** - Which phase completed, what's pending
3. **Resume instructions** - User can re-invoke `/ticket-worker <TICKET>` and point to existing artifacts to skip completed phases

## Key Principles

- **User stays in control** - Confirm before transitions between major phases
- **Artifacts are durable** - All docs use ticket-based naming and persist on disk
- **Route inputs intelligently** - Research questions to research, plan constraints to planning
- **Don't skip phases** - Research informs planning, planning informs implementation
- **Surface blockers early** - Multi-repo dependencies, missing context, ambiguous requirements
