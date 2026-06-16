---
name: jj-workflow
description: Jujutsu (jj) version control workflows. Use when making commits, editing previous commits, managing commit stacks, or resolving conflicts. Covers creating new commits, amending work, editing history, and keeping a clean linear stack of consecutive commits.
---

# jj Workflow

Standard jj operations for managing commits during implementation work.

## Core Concepts

- The **working copy** is always a commit. Changes you make are automatically tracked.
- `jj describe` sets the message on the current working-copy commit.
- `jj new` creates a new empty commit on top of the current one, making the previous commit "finished."
- Commits form a **stack** -- a linear chain where each builds on the previous.

## Creating New Commits

### Finishing the current commit and starting fresh

```bash
# Set the commit message for your current work
jj describe -m "Phase 1: Add validation layer

- Implement ConfigValidator class
- Add unit tests for validation rules"

# Start a new working-copy commit on top
jj new
```

This is the standard "commit and move on" flow. After `jj new`, the previous commit is finalized and you have a clean working copy.

### Checking state

```bash
# See what's changed in the working copy
jj status
jj diff

# See the commit stack
jj log

# See the full diff of a specific commit
jj show <change-id>
```

## Editing Previous Commits

Use `jj edit` to go back and modify an earlier commit in your stack. This is useful when you discover a fix, improvement, or missing piece that belongs in an earlier phase.

### Basic edit flow

```bash
# Find the commit you want to edit
jj log

# Move the working copy to that commit
jj edit <change-id>

# Make your changes (files are restored to that commit's state)
# ... edit files ...

# Changes are automatically absorbed into that commit
# When done, return to the top of your stack
jj new <latest-change-id>
```

### Squashing changes into a parent

If you've made follow-up fixes that belong in a previous commit:

```bash
# Squash the current commit into its parent
jj squash

# Or squash specific files into the parent
jj squash --interactive
```

## Resolving Conflicts

When editing earlier commits, later commits in the stack may conflict. **Always resolve all conflicts before moving on.**

### Check for conflicts

```bash
# After editing a prior commit, check the log for conflict markers
jj log
# Conflicted commits show "conflict" in the log output
```

### Resolve conflicts

```bash
# Move to the conflicted commit
jj edit <conflicted-change-id>

# View the conflicts
jj status

# Open conflicting files -- they contain conflict markers
# Fix all conflict markers in each file

# Verify the conflicts are resolved
jj status
# Should show no more conflicts

# If there are downstream conflicts, continue resolving
jj log
```

### Important: resolve the entire stack

After editing a commit, check **every** descendant commit for conflicts. Walk down the stack and fix each one:

```bash
jj log  # identify any conflicted descendants
jj edit <next-conflicted-change-id>
# fix conflicts
# repeat until the full stack is clean
```

**Never leave the stack in a conflicted state.** The implementation cannot continue with conflicts in the history.

## Keeping a Clean Linear Stack

When doing a stream of work where each piece builds on the previous (e.g., implementation phases), commits should be **consecutive** in a linear stack:

```
@  (working copy - current phase)
○  Phase 3: API endpoints
○  Phase 2: Business logic
○  Phase 1: Data model
○  main
```

### Rules

- **Each phase is one commit** -- use `jj describe` + `jj new` to advance
- **Phases build on each other** -- each commit's parent is the previous phase
- **Editing earlier phases is fine** -- use `jj edit`, but always resolve all conflicts in the full stack afterward
- **Don't leave gaps** -- if you need to insert work between phases, use `jj new --before <change-id>` to insert a commit, then resolve any conflicts

### Inserting a commit between existing ones

```bash
# Insert a new commit before a specific commit
jj new --before <change-id>

# Make your changes, describe the commit
jj describe -m "Phase 1.5: Missing migration step"

# Check for and resolve any conflicts in descendants
jj log
```

## Bookmark & Push

```bash
# Create or move a bookmark (branch) to the current commit
jj bookmark set <name> -r <change-id>

# Push to remote
jj git push --bookmark <name>
```

Bookmark naming convention: `tausman/<ticket-short-description>`
