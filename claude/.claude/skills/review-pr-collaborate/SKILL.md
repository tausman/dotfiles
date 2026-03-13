---
name: review-pr-collaborate
description: Collaborative PR review workflow. Use when the user wants to review a PR and draft comments interactively before posting them all at once. Helps track which PR/branch is being reviewed, checks out the code using jj review, and batches all comments for submission. Triggers on "review PR", "collaborate on PR review", "let's review this PR", "draft PR comments", or when the user wants to iteratively build up PR review feedback.
---

# Collaborative PR Review

Interactive workflow for reviewing a PR with the user, drafting comments together, and posting them all at once when ready.

## Workflow Overview

1. **Identify the PR** -- determine which PR to review
2. **Check out the code** -- ensure the PR's changes are available locally on a single commit
3. **Review files together** -- walk through changes, discuss, draft comments
4. **Batch post comments** -- when the user gives the go-ahead, post all comments at once

---

## Phase 1: Identify the PR

Accept the PR in any of these formats:
- PR number (e.g., `12345`)
- PR URL (e.g., `https://github.com/owner/repo/pull/123`)
- Branch name (e.g., `someone/feature-branch`)
- "current PR" -- detect from current branch

Determine the PR details:
```bash
# If given a PR number or URL
gh pr view <pr-number-or-url> --json number,headRefName,baseRefName,url,title,body,additions,deletions,changedFiles

# If on a branch, try to detect
gh pr view --json number,headRefName,baseRefName,url,title,body,additions,deletions,changedFiles
```

Extract and store:
- **PR number**
- **Branch name** (headRefName)
- **Base branch** (baseRefName)
- **Repository** (owner/repo)
- **PR URL**

Present a summary to the user:
```
Reviewing PR #<number>: <title>
Branch: <headRefName> -> <baseRefName>
Files changed: <changedFiles> (+<additions>, -<deletions>)
URL: <url>
```

---

## Phase 2: Check Out the Code

### Check if already on the right commit

The user may have already run `jj review <branch>` before invoking this skill. In that case, the current commit won't have the same hash as the PR's head commit -- `jj review` creates a fresh commit with the PR's changes squashed onto the common ancestor with trunk. The key check is whether the **file changes** match, not the commit hash.

To verify, compare the set of changed files in the current commit against the PR's changed files:

```bash
# Get the list of files changed in the current jj commit
jj diff --stat

# Get the list of files changed in the PR from GitHub
gh pr view <pr-number> --json files --jq '.files[].path' | sort

# Compare: if the file lists match (or are a close match), the PR is already checked out
```

You can also do a quick sanity check on diff size:

```bash
# Local additions/deletions
jj diff --stat | tail -1

# PR additions/deletions
gh pr view <pr-number> --json additions,deletions --jq '"\(.additions) additions, \(.deletions) deletions"'
```

If the changed files and diff stats align, the PR changes are already checked out -- skip to Phase 3.

### Use jj review to check out

If the changes are NOT already checked out, use the custom `jj review` alias which:
1. Fetches the remote branch
2. Finds the common ancestor with trunk
3. Creates a new commit with all the PR's changes squashed into one

```bash
jj review <branch-name>
```

This gives a single commit with the full PR diff, ideal for reviewing.

### Verify checkout

After checkout, verify the changes match the PR:
```bash
# Compare file lists
jj diff --stat
gh pr view <pr-number> --json files --jq '.files[].path' | sort
```

Confirm the changed files match what the PR shows.

---

## Phase 3: Collaborative Review

### Get the list of changed files

```bash
jj diff --stat
```

### Review approach

Work through files with the user. For each file or area of interest:

1. **Read the file** at the relevant sections
2. **Show the diff** for that file: `jj diff <file-path>`
3. **Discuss** with the user -- they may have observations, questions, or want to draft a comment
4. **Draft comments** when the user wants to leave feedback

### Tracking comments

Maintain an internal list of all drafted comments. Each comment has:

- **file_path**: The file the comment is on
- **line**: The line number in the new version of the file (RIGHT side)
- **body**: The comment text (MUST end with `\n\n_ai assisted comment_`)
- **comment_url** (optional): If replying to an existing thread, the URL of the comment

Track these as a numbered list and present them to the user periodically:

```
Drafted comments (3):
1. [src/handler.go:42] Can we add an error check on the db.Query return? It looks like a failure here would be silently dropped.
2. [src/handler.go:87] Have we considered using context.WithTimeout here? I have a preference for explicit timeouts on DB calls.
3. [src/config.go:15] We might want to make this default value configurable -- what do you think?
```

### Comment tone

All comments MUST use collaborative, friendly language. The reviewer is a teammate, not a subordinate. Frame feedback as suggestions and shared observations, not commands.

**Critically, match the tone to the reviewer's intent.** Before drafting a comment, understand what the reviewer is trying to communicate:

- **Bug / correctness issue**: The reviewer is confident something is wrong. Use clear, direct language -- but still collaborative. Don't hedge with "what do you think?" when there's a real bug.
  - "Can we add an error check here? It looks like `db.Query` failures would be silently dropped, which could cause data loss."
  - "We should handle the nil case here -- this will panic if `config` is unset."

- **Suggestion / improvement**: The reviewer sees a way to make things better but the current code isn't broken. Frame as a suggestion, invite discussion.
  - "Have we considered using `context.WithTimeout` here? It might be worth adding an explicit timeout on this DB call."
  - "I'd lean toward extracting this into a helper -- what do you think?"

- **Preference / style nit**: The reviewer has a personal preference or minor style opinion. Be explicit that it's a preference, not a requirement.
  - "Nit: I have a preference for early returns here, but this is fine either way."
  - "Minor: we might want to name this `usersByID` for consistency with the rest of the file."

- **Question / clarification**: The reviewer doesn't fully understand something and wants context. Ask genuinely.
  - "Can you help me understand the reasoning behind this approach? I want to make sure I'm not missing context."
  - "Is there a reason we're not reusing `validateInput` here?"

**Always avoid directive language regardless of intent:**
- "Do this" / "Change this to..."
- "You should..." / "You need to..."
- "This is wrong" / "This must be..."
- "Fix this" / "Remove this"

**When drafting from user input**, ask the user to clarify their intent if it's ambiguous. For example:
- User says: "Tell them to add error handling here" -> Ask: "Is this a bug (errors are silently dropped) or a suggestion (would be nice to have)?" Then draft accordingly.
- User says: "This function is too long" -> Ask: "Is this blocking (hard to review/maintain) or a nit (preference for smaller functions)?" Then draft accordingly.

If the user's intent is clear from context, draft directly without asking.

### Comment format

EVERY comment body MUST end with:
```

_ai assisted comment_
```

This is a hard requirement -- append it to every comment before posting.

### User interactions during review

The user may:
- **Add a comment**: "Comment on line X of file Y: ..."
- **Edit a comment**: "Change comment 2 to say ..."
- **Delete a comment**: "Remove comment 3"
- **View all comments**: "Show me all drafted comments"
- **Move to next file**: "Next file" or "Let's look at ..."
- **Ask questions**: "What does this function do?" -- answer from code context
- **Give the go-ahead**: "Post them" / "Submit" / "Send all comments" / "LGTM, post"

---

## Phase 4: Batch Post Comments

When the user gives the go-ahead, post ALL comments at once using the GitHub API.

### For new inline comments (not replies to existing threads)

Use the GitHub PR review API to post all comments as a single review:

```bash
# Build the comments array for the review
# Each comment needs: path, line (or position), body

gh api \
  -X POST \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews" \
  -f event="COMMENT" \
  -f body="" \
  --input <(cat <<'EOF'
{
  "event": "COMMENT",
  "body": "",
  "comments": [
    {
      "path": "src/handler.go",
      "line": 42,
      "side": "RIGHT",
      "body": "Can we add an error check on the db.Query return? It looks like a failure here would be silently dropped.\n\n_ai assisted comment_"
    },
    {
      "path": "src/handler.go",
      "line": 87,
      "side": "RIGHT",
      "body": "Have we considered using context.WithTimeout here? I have a preference for explicit timeouts on DB calls.\n\n_ai assisted comment_"
    }
  ]
}
EOF
)
```

**Important**: The `line` must reference a line within the diff (a line that was added or is context in the diff). Use `side: "RIGHT"` for lines in the new version.

To get the correct commit_id for the review:
```bash
# Get the latest commit SHA on the PR branch
gh pr view <pr_number> --json headRefOid --jq '.headRefOid'
```

Include the `commit_id` in the review payload so comments are anchored to the right commit.

### For replies to existing comment threads

Use the reply-pr-thread script for each reply:

```bash
# For each reply-type comment
reply-pr-thread.sh "<comment-url>" "<body>"
```

Or use the API directly:
```bash
gh api \
  -X POST \
  "repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies" \
  -f body="<body>"
```

### Post-submission report

After posting, report results:

```
Posted <N> comments on PR #<number>:
- <N> new inline comments (via review)
- <N> thread replies
PR: <url>
```

If any comments fail to post, report which ones failed and why.

---

## Error Handling

- **jj review fails**: Check if the branch exists remotely, suggest `jj git fetch`
- **Comment line not in diff**: Warn the user that the line must be within the diff range. Suggest the nearest valid line.
- **API rate limits**: Report and suggest waiting
- **Auth issues**: Suggest `gh auth login`

## Key Principles

- **Batch, don't trickle** -- never post comments one at a time during the review. Collect everything and post when the user says go.
- **Always append footer** -- every comment body ends with `\n\n_ai assisted comment_`
- **Single commit view** -- use `jj review` to get all changes on one commit for easy reviewing
- **User is in control** -- don't post anything without explicit go-ahead
- **Track state clearly** -- always be able to show the user what comments are queued
