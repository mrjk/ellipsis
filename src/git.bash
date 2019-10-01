# git.bash
#
# Assorted git utility functions. These functions all require us to cd into the
# git repo we want to operate on first. These exist mostly for aesthetic
# reasons, i.e., pretty output in the various ellipsis commands and can be used
# by package authors for consistency with them.

load pkg
load msg

# Clone a Git repo.
git.clone() {
    git clone --depth 1 "$@"
}

# Pull git repo.
git.pull() {
    pkg.set_globals "${1:-$PKG_NAME}"
    msg.bold "updating $PKG_NAME"
    git pull
}

# Push git repo.
git.push() {
    pkg.set_globals ${1:-$PKG_NAME}
    msg.bold "pushing $PKG_NAME"
    git push
}

# Print remote branch name
git.remote_branch() {
    git rev-parse --abbrev-ref "@{u}"
}

# Print last commit's sha1 hash.
git.sha1() {
    git rev-parse --short HEAD
}

# Print last commit's relative update time.
git.last_updated() {
    git --no-pager log --pretty="format:%ad" --date=relative -1
}

# Print how far ahead git repo is
git.ahead() {
    git status -sb --porcelain | grep -o '\[.*\]'
}

# Print how far behind git repo is
git.behind() {
    git rev-list "HEAD...$(git.remote_branch)" --count
}

# Return if current repo is behind remote branch
git.is_behind() {
    if [ "$(git.behind)" -eq "0" ]; then
        return 1
    fi
    return 0
}

# Check whether git repo has changes.
git.has_changes() {
    # Refresh index before using it
    git update-index --refresh 2>&1 > /dev/null

    if git diff-index --quiet HEAD --; then
        return 1
    fi
    return 0
}

# Check for untracked files
# ! Only works if the pwd is the root of the repo
git.has_untracked() {
    if [ -z "$(git ls-files -o --exclude-standard)" ]; then
        return 1
    fi
    return 0
}

# Print diffstat for git repo
git.diffstat() {
    git --no-pager diff --stat --color=always
}

# Print status for git repo
git.status() {
    git status -s
}

# Checks if git is configured as we expect.
git.configured() {
    for key in user.name user.email github.user; do
        if [ -z "$(git config --global $key | cat)"  ]; then
            return 1
        fi
    done
    return 0
}

# Adds an include safely.
git.add_include() {
    git config --global --unset-all include.path $1
    if [ -z "$(git config --global include.path)" ]; then
        git config --global --remove-section include &>/dev/null
    fi
    git config --global --add include.path $1
}

# Indicates if an update is needed (not perfect + rather slow)
# Generaly you want to use git.is_behind
git.needs_update() {
    # Update remote references
    git remote update 2>&1 > /dev/null

    if [ -z "$(git status -s -uno)" ]; then
        return 1
    fi
    return 0
}

# Check if there is any git repo
git.is_repo() {
  if [ -d .git ]; then
    return 0
  else
    git rev-parse --git-dir > /dev/null 2>&1 && return 0 || return 1
  fi;
}
