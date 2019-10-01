# ellipsis.bash
#
# Core ellipsis interface.

load fs
load git
load pkg
load path
load utils
load log
load msg

# List all installed packages.
ellipsis.list_packages() {
    if ! fs.folder_empty "$ELLIPSIS_PACKAGES"; then
        find "$ELLIPSIS_PACKAGES" -maxdepth 4 \
          -name '.git' -or -name 'ellipsis.sh' -or -type l |
          sed -E "s#$ELLIPSIS_PACKAGES/?##;s#/(.git|ellipsis.sh).*##" |
          LANG=C sort | uniq
    fi
}

# Run commands across all packages.
ellipsis.each() {
    # execute command for ellipsis first
    pkg.env_up "$ELLIPSIS_PATH"
    "$@"
    pkg.env_down

    # loop over packages, excecuting command
    for pkg in $(ellipsis.list_packages); do
        pkg.env_up "$pkg"
        "$@"
        pkg.env_down
    done
}

# Use the ellipsis API from outside ellipsis
ellipsis.api() {
    "$@"
}

# Installs new ellipsis package, using install hook if one exists. If no hook is
# defined, all files are symlinked into ELLIPSIS_HOME using `fs.link_files`.
ellipsis.install() {
    if [ $# -lt 1 ]; then
        log.fail "No package specified for install"
        exit 1
    fi

    for package in "$@"; do

        # Fetch information from URI
        pkg.scan_nice_uri "$package" || return 1

        # Install depending the selected method
        if [ "$PKG_MODE" == "link" ]; then
          mkdir -p "${PKG_PATH%/*}"
          ln -s "$PKG_URL" "$PKG_PATH"
        else
          if [ -z "$PKG_BRANCH" ]; then
              git.clone "$PKG_URL" "$PKG_PATH"
          else
              git.clone "$PKG_URL" "$PKG_PATH" --branch "$PKG_BRANCH"
          fi
        fi

        pkg.env_up "$PKG_PATH"

        # Check for ellipsis version dependency if defined
        if [ -n "$ELLIPSIS_VERSION_DEP" ] &&
            utils.version_compare "$ELLIPSIS_VERSION" -lt "$ELLIPSIS_VERSION_DEP"; then

            log.fail "Package $PKG_NAME needs at least Ellipsis version $ELLIPSIS_VERSION_DEP"
            rm -rf "$PKG_PATH"
            exit 1
        fi

        pkg.run_hook "install"
        if [ "$?" -ne 0 ]; then
            log.fail "Could not install package $PKG_NAME"
            rm -rf "$PKG_PATH"
            exit 1
        fi

        pkg.run_hook "link"
        pkg.env_down
    done
}

# Re-install a package
#
# Calls the reinstall hook
ellipsis.reinstall() {
    if [ $# -ne 1 ]; then
        log.fail "No package specified for re-install"
        exit 1
    fi

    for package in "$@"; do
        if [[ "$1" =~ ^[Ee]llipsis$ ]]; then
            log.fail "Can't reinstall ellipsis in this way"
            continue
        fi

        pkg.env_up "$package"

        if pkg.run git.has_untracked || pkg.run git.has_changes; then
            if ! utils.prompt "Uncommitted files or changes present, continue? [y/n]" "y"; then
                pkg.env_down
                continue
            fi
        fi

        pkg.run_hook "reinstall"

        pkg.env_down
    done
}

# Uninstall package, using uninstall hook if one exists. If no hook is
# defined, all symlinked files in ELLIPSIS_HOME are removed and package is rm -rf'd.
ellipsis.uninstall() {
    if [ $# -ne 1 ]; then
        log.fail "No package specified for uninstall"
        exit 1
    fi

    for package in "$@"; do
        pkg.env_up "$package"

        if pkg.run git.has_untracked || pkg.run git.has_changes; then
            if ! utils.prompt "Uncommitted files or changes present, continue? [y/n]" "y"; then
                pkg.env_down
                continue
            fi
        fi

        pkg.run_hook "unlink"
        pkg.run_hook "uninstall"
        rm -rf "$PKG_PATH"

        pkg.env_down
    done
}

# Re-link unlinked packages.
ellipsis.link() {
    if [ $# -ne 1 ]; then
        log.fail "No package specified to link"
        exit 1
    fi

    pkg.env_up "$1"
    pkg.run_hook "link"
    pkg.env_down
}

# Unlink package, using unlink hooks, using unlink hook if one exists. If no
# hook is defined, all symlinked files in ELLIPSIS_HOME are removed.
ellipsis.unlink() {
    if [ $# -ne 1 ]; then
        log.fail "No package specified to unlink"
        exit 1
    fi

    pkg.env_up "$1"
    pkg.run_hook "unlink"
    pkg.env_down
}

# List installed packages.
ellipsis.installed() {
    if utils.cmd_exists column; then
        ellipsis.each pkg.run_hook "installed" | column -t -s $'\t'
    else
        ellipsis.each pkg.run_hook "installed"
    fi
}

# List(s) package git status.
ellipsis.status() {
    if [ $# -eq 1 ]; then
        pkg.env_up "$1"
        pkg.run_hook "status"
        pkg.env_down
    else
        ellipsis.each pkg.run_hook "status"
    fi
}

# Updates package(s) with git pull.
ellipsis.pull() {
    if [ $# -eq 1 ]; then
        if [[ "$1" =~ ^[Ee]llipsis$ ]]; then
            pkg.env_up "$ELLIPSIS_PATH"
        else
            pkg.env_up "$1"
        fi

        pkg.run_hook "pull"
        pkg.env_down
    else
        ellipsis.each pkg.run_hook "pull"
    fi
}

# Push updated package(s) with git push.
ellipsis.push() {
    if [ $# -eq 1 ]; then
        pkg.env_up "$1"
        pkg.run_hook "push"
        pkg.env_down
    else
        ellipsis.each pkg.run_hook "push"
    fi
}

# Scaffold a new package.
ellipsis.new() {
    # If no-argument is passed, use cwd as package path.
    if [ $# -eq 1 ]; then
        pkg.set_globals "$1"
    else
        pkg.set_globals "$(pwd)"
    fi

    # Create package dir if necessary.
    mkdir -p "$PKG_PATH"

    # If path is not empty, ensure they are serious.
    if ! $(fs.folder_empty "$PKG_PATH"); then
        utils.prompt "destination is not empty, continue? [y/n]" "y" || exit 1
    fi

    # Template variables.
    local _PKG_PATH='$PKG_PATH'
    local _PROMPT='$'
    local _FENCE=\`\`\`

    # Generate ellipsis.sh for package.
    cat > "$PKG_PATH/ellipsis.sh" <<EOF
#!/usr/bin/env bash
#
# $ELLIPSIS_USER/$PKG_NAME ellipsis package

# The following hooks can be defined to customize behavior of your package:
# pkg.install() {
#     fs.link_files $_PKG_PATH
# }

# pkg.push() {
#     git.push
# }

# pkg.pull() {
#     git.pull
# }

# pkg.installed() {
#     git.status
# }
#
# pkg.status() {
#     git.diffstat
# }
EOF

    # Generate README.md for package.
    cat > "$PKG_PATH/README.md" <<EOF
# $ELLIPSIS_USER/$PKG_NAME
Just a bunch of dotfiles.

## Install
Clone and symlink or install with [ellipsis][ellipsis]:

$_FENCE
$_PROMPT ellipsis install $ELLIPSIS_USER/$PKG_NAME
$_FENCE

[ellipsis]: http://ellipsis.sh
EOF

    cd "$PKG_PATH"
    git init
    git add README.md ellipsis.sh
    git commit -m "Initial commit"
    msg.print "new package created at $(path.relative_to_home "$PKG_PATH")"
}

# Edit ellipsis.sh for package, or open ellipsis dir in $EDITOR.
ellipsis.edit() {
    if [ $# -eq 1 ]; then
        # Edit package's ellipsis.sh file.
        pkg.env_up "$1"
        "$EDITOR" "$PKG_PATH/ellipsis.sh"
    else
        # Open ellipsis dir in editor.
        "$EDITOR" "$ELLIPSIS_PATH"
    fi
}

# List all symlinks (slightly optimized over calling pkg.list_symlinks for each
# package.
ellipsis._list_symlink_mappings() {
    for file in $(fs.list_symlinks); do
        local link="$(readlink "$file")"
        local dest="$(path.abs_path $ELLIPSIS_HOME/$(readlink "$file"))"
        if [[ "$dest" == $ELLIPSIS_PACKAGES* ]]; then
            msg.print "$(path.relative_to_packages "$dest") -> $(path.relative_to_home "$file")"
        fi
    done
}

# List all symlinks, or just symlinks for a given package
ellipsis.links() {
    if [ $# -eq 1 ]; then
        pkg.env_up "$1"
        pkg.run_hook "links"
        pkg.env_down
    else
        if utils.cmd_exists column; then
            ellipsis._list_symlink_mappings | sort | column -t
        else
            ellipsis._list_symlink_mappings | sort
        fi
    fi
}

ellipsis._list_broken_symlink_mappings() {
    for file in $(fs.list_broken_symlinks "$ELLIPSIS_HOME"); do
        msg.print "$(path.relative_to_packages $(readlink "$file")) -> $(path.relative_to_home "$file")"
    done
}

# List broken symlinks in ELLIPSIS_HOME
ellipsis.broken() {
    if utils.cmd_exists column; then
        ellipsis._list_broken_symlink_mappings | sort | column -t
    else
        ellipsis._list_broken_symlink_mappings | sort
    fi
}

# List broken symlinks in ELLIPSIS_HOME
ellipsis.clean() {
    for file in $(fs.list_broken_symlinks "$ELLIPSIS_HOME"); do
        rm "$file"
    done
}

# Add file to package
ellipsis.add() {
    if [ $# -lt 2 ]; then
        log.fail "Usage: ellipsis add <package> <(dot)file>"
        exit 1
    fi

    # Detect explicit additions
    if [ $# -eq 2 ]; then
        explicit_add=true
    fi

    for file in "${@:2}"; do
        # Ignore . and ..
        if [ "$file" == '.' -o "$file" == '..' ]; then
            continue
        fi

        # Important to get absolute path of each file as we'll be changing
        # directory when hook is run.
        local file="$(path.abs_path "$file")"
        local file_name="$(basename "$file")"

        # Ignore if file is ellipsis related
        if ellipsis.is_related "$file"; then
            # Can be ignored without message
            continue
        fi

        # Ignore useless files
        if [ -z "$explicit_add" ] && ellipsis.is_useless "$file"; then
            log.info "Ignored $file_name (marked useless)"
            continue
        fi

        # Warn about sensitive files
        if ellipsis.is_sensitive "$file"; then
            log.warn "Attention, $file_name might contain sensitive information!"
        fi

        pkg.env_up "$1"
        pkg.run_hook "add" "$file"
        pkg.env_down
    done
}

# Remove file from package
ellipsis.remove() {
    if [ $# -lt 2 ]; then
        log.fail "Usage: ellipsis remove <package> <(dot)file>"
        exit 1
    fi

    for file in "${@:2}"; do
        # Ignore . and ..
        if [ "$file" == '.' -o "$file" == '..' ]; then
            continue
        fi

        # Important to get absolute path of each file as we'll be changing
        # directory when hook is run.
        local file="$(path.abs_path "$file")"
        local file_name="$(basename "$file")"

        pkg.env_up "$1"
        pkg.run_hook "remove" "$file"
        pkg.env_down
    done
}

# Check if a file is related to ellipsis
ellipsis.is_related() {
    local file="$1"

    # If link, check destination
    if [ -L "$file" ]; then
        file="$(readlink "$file")"
    fi

    case $file in
        $ELLIPSIS_PATH|$ELLIPSIS_PACKAGES/*)
            # File is ellipsis related
            return 0
            ;;
        *)
            # File is ok for this test
            return 1
            ;;
    esac
}

# Check if a file is useless
ellipsis.is_useless() {
    local file="$1"

    case $file in
        $ELLIPSIS_HOME/.cache|$ELLIPSIS_HOME/.zcompdump|$ELLIPSIS_HOME/.ecryptfs \
        |$ELLIPSIS_HOME/.Private|$ELLIPSIS_HOME/*.bak)
            # Matched files are labled "useless"
            return 0
            ;;
        *)
            # File is ok for this test
            return 1
        ;;
    esac
}

#Check if file is in the list of possibly sensitive files
ellipsis.is_sensitive() {
    local file="$1"

    case $file in
        $ELLIPSIS_HOME/.ssh|$ELLIPSIS_HOME/.gitconfig|$ELLIPSIS_HOME/.gemrc \
        |$ELLIPSIS_HOME/.npmrc|$ELLIPSIS_HOME/.pypirc|$ELLIPSIS_HOME/.pgpass \
        |$ELLIPSIS_HOME/.floorc|$ELLIPSIS_HOME/.gist|$ELLIPSIS_HOME/.netrc \
        |$ELLIPSIS_HOME/.git-credential-cache|*history*)
            # Matched files are labled "sensitive"
            return 0
        ;;
        *)
            # File is ok for this test
            return 1
        ;;
    esac
}
