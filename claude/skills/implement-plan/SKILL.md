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
- Verify prerequisites: `git status`, `git log -1`, pre-flight checks
- Note any assumptions or prerequisites mentioned in the plan

### 2. Create Worktrees for all the repos involved in this plan

#### If plan has not started to be implemented yet:
- Create a worktree from the base repository like so:
`repo_name`: name of the base repository (ie: `dd-go`, `dd-source`, `dogweb`, etc.)
`directory-name`: jira ticket prefixed short description of work being done (ie: `cred-2161-audit-trail-pat-support`)
```bash
git worktree add ~/worktrees/<repo_name>/<directory-name> -b tausman/<directory-name>
```

#### If plan has already started to be implemented:
- Find the necessary worktrees in the expected directories by searching for the jira ticket
- If you cannot find the directories STOP and ask before proceeding further.

***important***: All of your work will be done in these worktrees -- not in the main repository

### 3. Execute Each Phase

For each phase:

**Implement:**
- Make changes according to plan specification
- Reference specific file:line numbers from plan
- Follow existing code patterns
- Update the plan as a phase is being completed
- Ensure all prior & new tests are passing before making a commit
- Make a single commit for the phase with a descriptive message


Example commit message:
```
Phase 1: Add configuration validation layer

- Implement ConfigValidator class (config/validator.ts)
- Add unit tests for validation rules
- Ref: ./2025-12-23-config-refactor.md
```

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

### 4. Phase Gate

After success criteria met:

```
✓ Phase [N]: [Phase Name]

Implemented:
- [specific changes made]
- [files modified]

Verification Results:
- Automated checks: All passing
- Manual verification: Complete

Commits: [hash(es)]

Proceed to Phase [N+1]? (waiting for confirmation)
```

**Wait for explicit user confirmation before proceeding.**
**Ensure the phase is marked as complete in the plan**

### 5. Final Verification

After all phases:

1. **Run full validation suite** - All automated checks one more time
2. **End-to-end testing** - Verify complete feature works
3. **Document completion**:

```
✅ Implementation Complete: [Feature Name]

Plan: ./[filename]

Phases Executed:
- Phase 1: [Name] ✓ [commit hash]
- Phase 2: [Name] ✓ [commit hash]

Success Criteria Verified:
- Automated: All passing
- Manual: All verified

Files modified: [count]
Commits: [count] | Branch: [name]

Next Steps:
- [Follow-up items]
```

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

