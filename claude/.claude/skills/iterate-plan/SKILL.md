---
name: iterate-plan
description: Pause, reevaluate, and revise an existing implementation plan. Use when something is incorrect, missing, or could be done better in the current plan or implementation. Also use when addressing PR feedback. Can be called at any point -- mid-implementation, after completion, or when the user wants to rethink the approach. If the user says "/iterate-plan & implement" or similar, execute /implement-plan afterward with the updated plan.
---

# Iterate Plan

Pause the current workflow, reevaluate the approach with the user, and produce a revised plan forward.

## When This Gets Called

- Mid-implementation: something isn't working or a better approach was discovered
- After implementation: changes needed based on testing, review, or new requirements
- PR feedback: reviewer comments that require code changes
- User-initiated: "let's rethink this", "this isn't right", "we need to change the approach"

## Workflow

### 1. Load Current State

- Find and read the plan doc (`plan-<TICKET>.md` or `plan*.md`)
- Find and read the progress doc (`progress-<TICKET>.md` or `progress*.md`) if it exists
- Run `jj log` to see the current commit stack
- Run `jj status` to see any in-progress work
- Understand: which phases are done, which are in-progress, which are pending

Present a brief status summary to the user:
```
Current state:
- Plan: ./plan-<TICKET>.md
- Progress: ./progress-<TICKET>.md
- Phases completed: 1-3
- Phase in progress: 4
- Phases pending: 5-6
- Commit stack: [summary from jj log]
```

### 2. Understand the Issue

Ask the user (or parse from args/context):
- **What's wrong?** -- What needs to change and why?
- **Is this PR feedback?** -- If so, get the PR comments (use `/get-pr-feedback` or ask user to provide)
- **Scope** -- Does this affect an existing phase or is it new/additional work?

Research if needed:
- Use `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder` sub-agents to investigate
- Read relevant code to understand the current implementation state
- Understand the implications of the requested change

### 3. Classify the Change

Determine which path to take:

#### Path A: Edit to Existing Phase
The change modifies an existing phase -- either one that has already been implemented (completed/in-progress) or one that is still pending. The change belongs **within that phase**, not as a separate phase.

**A1 -- Edit a pending/unimplemented phase (plan-only change):**
The phase hasn't been implemented yet. This is the simpler case -- just update the plan text. No commits to edit, no conflicts to resolve.

Indicators:
- "Phase 4 should also include X"
- "The approach described in phase 5 won't work, change it to Y"
- Rethinking an upcoming phase before implementation starts

**A2 -- Edit a completed/in-progress phase (plan + commit change):**
The phase has already been committed. The fix belongs **in the same commit** as the original work, requiring `jj edit`.

Indicators:
- "This implementation is wrong, it should do X instead"
- "We missed handling Y in phase 2"
- "The approach in phase 3 needs to change"
- Bug fix in already-committed work

#### Path B: New Phase
The change is **new or additional work** that does not belong in any existing commit. It gets its own phase and its own commit.

Indicators:
- PR feedback (always a new phase -- never edit the reviewed commit)
- "We also need to add X"
- Additional feature or requirement discovered
- Follow-up work that builds on existing phases
- Addressing reviewer comments

**PR feedback is ALWAYS Path B.** Never edit an existing commit to address PR feedback -- it gets a new phase and a new commit.

### 4. Discuss Options with the User

Present the classification and proposed approach:

```
Classification: [Path A1: Edit pending phase (plan-only) | Path A2: Edit completed phase (plan + commit) | Path B: New phase]
Reason: [why this classification]

Proposed approach:
- [What will change in the plan]
- [Which commit(s) are affected, if any]
- [Impact on subsequent phases]
```

Get explicit user agreement before proceeding.

### 5A. Execute Path A -- Edit Existing Phase

**Update the plan doc (both A1 and A2):**
- Add an amendment entry under `## Amendments`:
  ```markdown
  ### [YYYY-MM-DD HH:MM] - <Short Description>
  **Phase affected:** Phase N
  **What changed:** [Description of the change]
  **Why:** [Rationale]
  **Impact:** [Effect on subsequent phases]
  ```
- Update the affected phase's description to reflect the new requirements
- Update success criteria if they changed

#### If A1 (pending/unimplemented phase -- plan-only change):

No commits exist yet, so this is purely a plan doc update:
- The amendment and updated phase description are the only changes needed
- Update the progress doc log:
  ```markdown
  - [YYYY-MM-DD HH:MM] Phase N revised (not yet implemented): <reason>
  ```

**If user requested implementation (`/iterate-plan & implement`):**
- Invoke `/implement-plan` with the updated plan doc path
- Instruct it to start from the revised phase

#### If A2 (completed/in-progress phase -- plan + commit change):

**Update the progress doc:**
- Change the affected phase's status back from `completed` to `amended`
- Add a log entry:
  ```markdown
  - [YYYY-MM-DD HH:MM] Phase N reopened: <reason>
  ```

**Identify the target commit:**
- From the progress doc, find the change-id for the phase being edited
- This is the commit that will be modified via `jj edit`

**If user requested implementation (`/iterate-plan & implement`):**
- Invoke `/implement-plan` with:
  - The updated plan doc path
  - Instruction to start from the amended phase
  - The specific change-id to `jj edit` for the amended phase
  - `/implement-plan` will use `jj edit <change-id>`, make the changes, update the commit message, resolve all conflicts in the stack, then continue with any remaining phases

### 5B. Execute Path B -- New Phase

**Update the plan doc:**
- Add a new phase at the appropriate position (usually at the end)
- If addressing PR feedback, title it clearly:
  ```markdown
  ### Phase N+1: Address PR Feedback
  **Triggered by:** PR review comments
  **Changes required:**
  - [specific change from reviewer comment 1]
  - [specific change from reviewer comment 2]
  **Success criteria:**
  - [criteria]
  ```
- Add an amendment entry documenting why the new phase was added

**Update the progress doc:**
- Add the new phase to the progress table with status `pending`
- Add a log entry:
  ```markdown
  - [YYYY-MM-DD HH:MM] Added Phase N+1: <reason>
  ```

**If user requested implementation (`/iterate-plan & implement`):**
- Invoke `/implement-plan` with:
  - The updated plan doc path
  - Instruction to start from the newly added phase
  - `/implement-plan` will create a new commit via `jj describe` + `jj new` as normal

### 6. Summary

After plan updates are complete, present:

```
Iteration complete:
- Type: [Edit existing phase | New phase]
- Plan updated: ./plan-<TICKET>.md
- Progress updated: ./progress-<TICKET>.md
- [Phase N amended | Phase N+1 added]

Next: [Ready for /implement-plan | Implementation in progress | Waiting for user direction]
```

## Key Principles

- **PR feedback is always a new phase and new commit** -- never rewrite reviewed history
- **Edits to existing work go in the original commit** -- use `jj edit` via `/jj-workflow`
- **Always update both plan and progress docs** -- keep the paper trail current
- **Get user agreement on classification** -- don't assume Path A vs Path B
- **Amendments preserve history** -- the original plan text stays, amendments are appended
- **Resolve all conflicts** -- after editing any commit, the entire stack must be clean (see `/jj-workflow`)
- **If asked to implement, invoke `/implement-plan`** -- this skill handles the planning revision, `/implement-plan` handles execution
