---
name: implement-plan
description: Implement technical plans with verification. Use when you have a completed implementation plan ready to execute systematically, executing multi-phase implementations with methodical verification, tracking progress against success criteria, working on complex features with phase-by-phase execution, or implementing features with specific file:line references and testing procedures.
---

# Implement Technical Plan

Execute implementation plans phase by phase with automated verification at each milestone.

## Workflow

### 1. Load the Plan

- Ask for path if not provided
- Read complete plan, extract phases, success criteria, dependencies
- Verify prerequisites: `jj status`, `jj log`, pre-flight checks
- Note any assumptions or prerequisites mentioned in the plan

### 2. Initialize Progress Tracking

- If a ticket ID is associated with the plan, create `progress-<TICKET>.md`
- Otherwise create `progress-<plan-name>.md`
- Track: phase status, notes, issues encountered, blockers

```markdown
# Progress: <Ticket/Feature>

| Phase | Status | Commit | Notes |
|-------|--------|--------|-------|
| 1. <Name> | pending | - | - |
| 2. <Name> | pending | - | - |

## Log
- [YYYY-MM-DD HH:MM] Started implementation
```

### 3. Execute Each Phase

For each phase:

**Implement:**
- Make changes according to plan specification
- Reference specific file:line numbers from plan
- Follow existing code patterns
- Update the plan as a phase is being completed
- Ensure all prior & new tests are passing before committing

**Commit with jj** (see `/jj-workflow` for full reference):
```bash
jj describe -m "Phase N: <descriptive message>

- <specific change 1>
- <specific change 2>
- Ref: ./<plan-file>.md"
```

Then start a fresh working commit:
```bash
jj new
```

**Editing a previous phase's commit:**
If you discover a fix or improvement that belongs in an earlier phase, use `jj edit <change-id>` to go back, make the change, then return to the top of the stack. **Always check `jj log` for conflicts in all descendant commits afterward and resolve every one before continuing.** See `/jj-workflow` for the full edit and conflict resolution flow.

**Verify automatically:**
```bash
[tests command - e.g., npm test, pytest, go test]
[type check command - e.g., tsc --noEmit, mypy]
[lint command - e.g., eslint, ruff, golangci-lint]
[build command - e.g., npm run build, make]
```

**Report results:**
- Which checks passed (summary)
- Which checks failed (full error output)
- Any unexpected failures

**Manual verification:**
- Follow testing steps from plan
- Test each scenario in success criteria
- Verify edge cases and error handling

**Update progress doc:**
- Mark phase status (complete/blocked/issues)
- Record commit change-id
- Note any deviations or discoveries

### 4. Phase Gate

After success criteria met:

```
Phase [N]: [Phase Name] - COMPLETE

Implemented:
- [specific changes made]
- [files modified]

Verification Results:
- Automated checks: All passing
- Manual verification: Complete

Change-id: [jj change-id]

Proceed to Phase [N+1]? (waiting for confirmation)
```

**Wait for explicit user confirmation before proceeding.**
**Ensure the phase is marked as complete in both the plan and progress doc.**

### 5. Handle Multi-Repo Dependencies

If a phase depends on a CI build artifact or deployment from another repo:

1. **Stop implementation** at that phase boundary
2. **Update progress doc** with the blocker:
   ```markdown
   ## Blockers
   - [YYYY-MM-DD HH:MM] Phase N blocked: waiting for <repo> CI to build <artifact>
     - PR/commit: <link>
     - Expected artifact: <description>
     - Resume: once <condition> is met, continue with Phase N
   ```
3. **Explain the blocker** to the user with clear next steps
4. Do NOT attempt to work around the dependency

### 6. Plan Amendment Protocol

If the plan needs changes during implementation:

1. **Stop and explain** what was discovered and why the plan needs to change
2. **Get user approval** for the amendment
3. **Update the plan doc** with an amendment entry:
   ```markdown
   ## Amendments

   ### [YYYY-MM-DD HH:MM] - <Short Description>
   **Phase affected:** Phase N
   **What changed:** [Description]
   **Why:** [What was discovered during implementation]
   **Impact:** [Effect on subsequent phases]
   ```
4. **Update progress doc** to reflect the amended plan
5. Continue implementation with the revised plan

### 7. Final Verification

After all phases:

1. **Run full validation suite** - All automated checks one more time
2. **End-to-end testing** - Verify complete feature works
3. **Update progress doc** with final status
4. **Document completion**:

```
Implementation Complete: [Feature Name]

Plan: ./[filename]
Progress: ./[progress-filename]

Phases Executed:
- Phase 1: [Name] - complete [change-id]
- Phase 2: [Name] - complete [change-id]

Success Criteria Verified:
- Automated: All passing
- Manual: All verified

Files modified: [count]
Commits: [count] | Bookmark: [name]

Next Steps:
- [Follow-up items]
```

5. **Create PR** - Ask the user if they want to open a PR. If yes:
   - **Multiple bookmarks** (phases split across branches): invoke `/create-pr-stack` with the ordered list of bookmarks. Each PR targets the previous bookmark as its base.
   - **Single bookmark**: invoke `/create-pr` for a single draft PR.

## Handling Issues

**Automated checks fail:**
1. Show complete error output
2. Analyze what went wrong
3. Propose solutions or ask for guidance
4. Ask: "Fix this, troubleshoot further, or try different approach?"

**Manual testing reveals problems:**
1. Document the issue clearly
2. Determine if in scope for current phase
3. Fix immediately or note as follow-up

**Plan unclear:**
1. Quote the ambiguous text
2. Propose interpretation
3. Wait for confirmation before proceeding

## Key Principles

- **One phase at a time** - Complete all criteria before advancing
- **Reference plan continuously** - Don't drift; flag deviations
- **Verify automatically first** - Then manual testing
- **Explicit confirmation between phases** - Never auto-advance
- **Document issues immediately** - Don't let problems accumulate
- **Use jj for all VCS operations** - See `/jj-workflow` for complete reference. `jj describe`, `jj new`, `jj status`, `jj diff`, `jj log`
- **Keep a clean linear stack** - Phases are consecutive commits. Editing earlier commits is fine but resolve all conflicts in the full stack before continuing.
- **Track progress** - Keep the progress doc current throughout implementation
