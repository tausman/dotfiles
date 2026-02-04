# Git aliases
alias gs='git status'
alias gc='git checkout'
alias gwr='git worktree remove'
alias gfo='git fetch origin'
alias gpo='git pull origin'
alias gr='git rebase -i --update-refs'

# Git worktree add with tausman/ prefix
unalias gwa 2>/dev/null
gwa() {
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local branch_name="tausman/$1"
    if git worktree list --porcelain | grep -q "branch refs/heads/$branch_name"; then
        echo "Error: branch '$branch_name' is already checked out by another worktree"
        return 1
    elif git show-ref --verify --quiet refs/heads/"$branch_name"; then
        git worktree add ~/worktrees/"$repo_name"/"$1" "$branch_name"
    else
        git worktree add ~/worktrees/"$repo_name"/"$1" -b "$branch_name"
    fi
}

# Interactive rebase with fzf commit selection
gri() {
    local commit=$(git log --oneline --decorate | awk '{printf "%-10s %s\n", (NR==1 ? "HEAD" : "HEAD~"NR-1), $0}' | fzf | awk '{print $2}')
    if [[ -n "$commit" ]]; then
        git rebase -i --update-refs "$commit"^
    fi
}

# Checkout commit with fzf selection
gcc() {
    local commit=$(git log --oneline --decorate | awk '{printf "%-10s %s\n", (NR==1 ? "HEAD" : "HEAD~"NR-1), $0}' | fzf | awk '{print $2}')
    if [[ -n "$commit" ]]; then
        git checkout "$commit"
    fi
}

# Checkout branch with fzf selection
unalias gcb 2>/dev/null
gcb() {
    local branch=$(git branch -a --format='%(refname:short)' | fzf)
    if [[ -n "$branch" ]]; then
        git checkout "$branch"
    fi
}
