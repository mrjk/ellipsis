# pkg.bash
#
# Ellipsis package interface. Encapsulates various useful functions for working
# with packages.

load fs
load git
load hooks
load log
load path
load utils

# Split name/branch to use
pkg.split_name() {
    echo "${1//@/ }"
}

# Strip prefix from package the name.
pkg.name_stripped() {
    sed -e "s/^${ELLIPSIS_PREFIX}//" <<< "$1"
}

# Convert package name to path.
pkg.path_from_name() {
    echo "$ELLIPSIS_PACKAGES/$1"
}

# Convert package path to name, stripping any leading dots.
pkg.name_from_path() {
    path=${1%/}
    if [[ "$path" =~ $ELLIPSIS_PACKAGES ]]; then
        echo "${path#$ELLIPSIS_PACKAGES}"
    else
        echo "$path"
        #sed -e "s/^\.//" <<< "${path##*/}"
    fi
}

# Convert package path to name for links
pkg.name_from_link() {
    path=${1%/}
    if [[ "$path" =~ $ELLIPSIS_PACKAGES ]]; then
        echo "${path#$ELLIPSIS_PACKAGES}"
    else
        sed -e "s/^\.//" <<< "${path##*/}"
    fi
}

# Pull name out as last path component of url
pkg.name_from_url() {
    rev <<< "$1" | cut -d '/' -f 1 | rev
}

# Get user from github-user/name shorthand syntax.
pkg.user_from_shorthand() {
    cut -d '/' -f1 <<< "$1"
}

# Get name from github-user/name shorthand syntax.
pkg.name_from_shorthand() {
    cut -d '/' -f2 <<< "$1"
}

# Set PKG_NAME, PKG_PATH. If $1 looks like a path it's assumed to be
# PKG_PATH and not PKG_NAME, otherwise assume PKG_NAME.
pkg.set_globals() {
    if path.is_path "$1"; then
        PKG_PATH="$1"
        PKG_NAME="$(pkg.name_from_path "$PKG_PATH")"
    else
        PKG_NAME="$1"
        PKG_PATH="$(pkg.path_from_name "$PKG_NAME")"
    fi
}

# Setup the package env (vars/hooks)
pkg.env_up() {
    pkg.set_globals "${1:-"$PKG_PATH"}"

    # Exit if we're asked to operate on an unknown package.
    if [ ! -d "$PKG_PATH" ]; then
        log.fail "Unkown package $PKG_NAME, $(path.relative_to_home "$PKG_PATH") missing!"
        exit 1
    fi

    # Source ellipsis.sh if it exists to setup a package's hooks.
    if [ -f "$PKG_PATH/ellipsis.sh" ]; then
        source "$PKG_PATH/ellipsis.sh"
    fi
}

# List symlinks associated with package.
pkg.list_symlinks() {
    for file in $(fs.list_symlinks); do
        if [[ "$(readlink "$file")" == *packages/$PKG_NAME* ]]; then
            echo "$file"
        fi
    done
}

# Print file -> symlink mapping
pkg.list_symlink_mappings() {
    for file in $(fs.list_symlinks); do
        local link=$(readlink $file)

        if [[ "$link" == *packages/$PKG_NAME* ]]; then
            echo "$(path.relative_to_packages $link) -> $(path.relative_to_home $file)";
        fi
    done
}

# Run command inside PKG_PATH.
pkg.run() {
    local cwd="$(pwd)"

    # change to package dir
    cd "$PKG_PATH"

    # run command
    "$@"

    # keep return value
    local return_code="$?"

    # return after running command
    cd "$cwd"

    return "$return_code"
}

# run hook if it's defined, otherwise use default implementation
pkg.run_hook() {
    # Prevent unknown hooks from running
    if ! utils.cmd_exists hooks.$1; then
        log.fail "Unknown hook!"
        exit 1
    fi

    # Run packages's hook. Additional arguments are passed as arguments to
    # command.
    if utils.cmd_exists "pkg.$1"; then
        pkg.run "pkg.$1" "${@:2}"
    else
        pkg.run "hooks.$1" "${@:2}"
    fi
}

# Clear globals, hooks.
pkg.env_down() {
    pkg._unset_vars
    pkg._unset_hooks
}

# Unset global packages.
pkg._unset_vars() {
    unset PKG_NAME
    unset PKG_PATH
    unset ELLIPSIS_VERSION_DEP
}

# Unset any hooks that might have been defined by package.
pkg._unset_hooks() {
    for hook in ${PKG_HOOKS[@]}; do
        unset -f pkg.$hook
    done
}

# Scan a package URI and determine installation informations
pkg.scan_nice_uri() {

    local input=$1

    local raw=${input%/}
    local mode='auto'
    local remote_user=''
    local remote_pass=''
    local url=''
    local port=''
    local name=''
    local path=''
    local ref=''

    # Extract reference
    ref=$( sed -E 's/.*#([0-9a-zA-Z_-][0-9a-zA-Z_-]*)/\1/' <<< "$raw" )
    if [[ "$ref" == "$raw" ]]; then
      ref=''
    else
      raw=${raw%#$ref}
    fi

    # Detect installation handler
    case $raw in
      ssh://*)
        mode='ssh'
        ;;
      http://*)
        mode='http'
        ;;
      https://*)
        mode='https'
        ;;
      link://*)
        mode='link'
        ;;
    esac

    # Autodetect installation method
    if [ "$mode" == "auto" ]; then
      if [ -d "$raw" ]; then
        mode="link"
      elif [[ "$raw" =~ @ ]]; then
        mode="ssh"
      else
        mode="https"
        raw="https://github.com/$raw"
      fi
    fi

    # Fails if no valid method found
    if [ "$mode" == "auto" ]; then
      log.fail "Unknown method installation for $input"
      return 1
    fi

    # Strip uri handler prefix if present
    raw=${raw#$mode://}

    # Extract other parts of the url
    if [ "$mode" != "link" ]; then

      # Extract remote_creds
      local remote_creds=$( sed -E 's/^([^@]*)@.*/\1/' <<< "$raw" )
      if [[ "$remote_creds" == "$raw" ]]; then
        remote_creds=''
      else
        # If there is any passord with it ?
        if [[ "$remote_creds" =~ : ]]; then
          remote_user=${remote_creds%%:*}
          remote_pass=${remote_creds#*:}
        else
          remote_user=${remote_creds}
          remote_pass=''
        fi
        raw=${raw#$remote_creds@}
      fi

      # Extract domain
      domain=$( sed 's/[:/].*//' <<< "$raw" )
      raw=${raw#$domain}

      # Extract port
      if [[ "$raw" =~ :[0-9][0-9]* ]]; then
        port=$( sed -E 's/:([0-9][0-9]*).*/\1/' <<< "$raw" )
        raw=${raw#:$port}
      fi

      # Extract path and name
      name="$( tr '[:/]' ' ' <<< "$raw" | xargs | tr ' ' / )"
      path="$(pkg.path_from_name "$name")"

      # Rebuild full url and destination path
      case $mode in
        ssh) url="${remote_user:+$remote_user${remote_pass:+:$remote_pass}@}$domain:${port:+$port/}$name" ;;
        http*) url="$mode://${remote_user:+$remote_user${remote_pass:+:$remote_pass}@}$domain${port:+:$port}/$name" ;;
      esac

    else
      url=$raw
      name=$(pkg.name_from_link $raw )
      path="$(pkg.path_from_name "dev/$name")"
    fi

    # Define exported variables
    PKG_MODE=$mode
    PKG_URL=$url
    PKG_NAME=$name
    PKG_PATH=$path

    PKG_USER=$remote_user
    PKG_PASS=$remote_pass

    PKG_DOMAIN=$domain
    PKG_PORT=$port
    PKG_BRANCH=$ref

    #return 

    # Debug output
    cat <<EOF #>/dev/null
DEBUG:
    INPUT: $input
    PKG_MODE=$mode
    PKG_URL=$url
    PKG_NAME=$name
    PKG_CREDS=$remote_user${remote_pass:+ (pass: $remote_pass)}

    PKG_PATH=$path
    PKG_DOMAIN=$domain
    PKG_PORT=$port
    PKG_BRANCH=$ref
EOF

}

# TESTS
#  
#  # Anonymous clone
#  https://github.com/zeekay/dot-vim
#  https://github.com/zeekay/dot-vim.git
#  https://framagit.org/mrjk-basher/home-lang
#  https://framagit.org/mrjk-basher/home-lang.git
#  https://framagit.org:4443/mrjk-basher/home-lang.git
#  https://user:password@framagit.org:4443/mrjk-basher/home-lang.git
#  
#  # Authentified tests
#  git@github.com:zeekay/dot-vim.git
#  git@framagit.org:mrjk-basher/home-lang.git
#  git@framagit.org:/mrjk-basher/home-lang.git
#  git@framagit.org:2222/mrjk-basher/home-lang.git
#  toto@framagit.org:2222/mrjk-basher/home-lang.git
#  

