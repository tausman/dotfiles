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

# jj aliases
je() {
    if [[ $# -gt 0 ]]; then
        jj edit "$@"
    else
        local target=$(_jj_colored_bookmarks | fzf --ansi --header="Bookmarks (esc for commits)")
        target=${target% \*}  # strip current marker
        if [[ -z "$target" ]]; then
            target=$(jj log --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' | fzf | awk '{print $1}')
        fi
        [[ -n "$target" ]] && jj edit "$target"
    fi
}
jn() {
    if [[ $# -gt 0 ]]; then
        jj new "$@"
    else
        local target=$(_jj_colored_bookmarks | fzf --ansi --header="Bookmarks (esc for commits)")
        target=${target% \*}  # strip current marker
        if [[ -z "$target" ]]; then
            target=$(jj log --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' | fzf | awk '{print $1}')
        fi
        [[ -n "$target" ]] && jj new "$target"
    fi
}
alias js='jj status'
alias jd='jj describe'
alias jdm='jj describe -m'
alias jb='jj bookmark'

# Helper: returns colored bookmark list (green=trunk, red=merged into trunk, *=current)
_jj_colored_bookmarks() {
    local bookmarks=$(jj bookmark list 2>/dev/null | grep -v '^ ' | grep -v '(deleted)' | grep -v '^Hint:' | cut -d: -f1 | sort -u)
    local trunk=$(jj log -r 'trunk()' --no-graph -T 'bookmarks' 2>/dev/null | tr -d '*\n' | cut -d'@' -f1)
    local current=$(jj log -r '@' --no-graph -T 'bookmarks' 2>/dev/null | tr -d '*\n' | cut -d'@' -f1)
    for b in ${(f)bookmarks}; do
        local suffix=""
        [[ "$b" == "$current" ]] && suffix=" *"
        if [[ "$b" == "$trunk" ]]; then
            # Green for trunk
            printf '\033[32m%s%s\033[0m\n' "$b" "$suffix"
        elif [[ -n $(jj log -r "$b & ::trunk()" --no-graph -T 'change_id' 2>/dev/null) ]]; then
            # Red for merged into trunk
            printf '\033[31m%s%s\033[0m\n' "$b" "$suffix"
        else
            printf '%s%s\n' "$b" "$suffix"
        fi
    done
}

jbs() {
    local bookmark=$(_jj_colored_bookmarks | fzf --ansi --header="Select bookmark to set")
    bookmark=${bookmark% \*}  # strip current marker
    [[ -n "$bookmark" ]] && jj bookmark set "$bookmark"
}

alias jbc='jj bookmark create'

jbd() {
    local selected=$(_jj_colored_bookmarks | fzf -m --ansi --header="Select bookmarks to delete (TAB to multi-select, red=merged, green=trunk)")
    if [[ -n "$selected" ]]; then
        echo "$selected" | while read -r b; do
            b=${b% \*}  # strip current marker
            jj bookmark delete "$b"
        done
    fi
}
alias jbl='jj bookmark list'
alias jl='jj log'
alias jfetch='jj git fetch'
alias jpull='jj git pull'
alias jpush='jj git push'
alias jpushd='jj git push --deleted'
alias jinit='jj git init --git-repo .'
jpr() {
    local title=$(jj log -r @ --no-graph -T 'description.first_line()')
    local head=$(jj log -r @ -T 'bookmarks' --no-graph | tr -d '*\n')
    local base=$(jj log -r @- -T 'bookmarks' --no-graph | tr -d '*\n')
    gh pr create --title "$title" --head "$head" --base "$base"
}
alias jspi='jj split -i'
alias jr='jj rebase'
alias ju='jj undo'
alias jol='jj op log'
alias jor='jj op restore'
alias ja='jj abandon'
alias jshow='jj show'
alias jdiff='jj diff'
