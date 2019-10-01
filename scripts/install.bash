#!/usr/bin/env bash
#
# scripts/install.sh
# Installer for ellipsis (http://ellipsis.sh).

# Ensure dependencies are installed.
deps=(bash curl git)

for dep in ${deps[*]}; do
    hash "$dep" 2>/dev/null || { echo >&2 "ellipsis requires $dep to be installed."; exit 1; }
done

# Create temp dir.
tmp_dir="$(mktemp -d "${TMPDIR:-tmp}"-XXXXXX)"

# Build the repo url
proto="${ELLIPSIS_PROTO:-https}"
url="${ELLIPSIS_REPO:-$proto://github.com/ellipsis/ellipsis.git}"

# Clone ellipsis into $tmp_dir.
if ! git clone --depth 1 "$url" "$tmp_dir/ellipsis"; then
    # Clean up
    rm -rf "$tmp_dir"

    # Print error message
    echo >&2 "Installation failed!"
    echo >&2 'Please check $ELLIPSIS_REPO and try again!'
    exit 1
fi

# Save reference to specified ELLIPSIS_PATH (if any) otherwise final
# destination: $HOME/.ellipsis.
FINAL_ELLIPSIS_PATH="${ELLIPSIS_PATH:-$HOME/.ellipsis}"

# Temporarily set ellipsis PATH so we can load other files.
ELLIPSIS_PATH="$tmp_dir/ellipsis"
ELLIPSIS_SRC="$ELLIPSIS_PATH/src"

# Initialize ellipsis.
source "$ELLIPSIS_SRC/init.bash"

# Load modules.
load ellipsis
load fs
load os
load msg
load log

# Load user configuration file
ELLIPSIS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ellipsis.sh"
ELLIPSIS_PATH="${FINAL_ELLIPSIS_PATH%/}"
if [ -f "$ELLIPSIS_CONFIG" ]; then
    . "$ELLIPSIS_CONFIG"
fi

# Set paths to final location
ELLIPSIS_BIN="$ELLIPSIS_PATH/bin"
ELLIPSIS_SRC="$ELLIPSIS_PATH/src"

# Editable vars
ELLIPSIS_HOME="$HOME"
ELLIPSIS_BIN_SHIM="${ELLIPSIS_BIN_SHIM:-$ELLIPSIS_BIN}"
ELLIPSIS_PACKAGES="${ELLIPSIS_PACKAGES:-$ELLIPSIS_PATH/packages}"

# Backup existing ~/.ellipsis if necessary
fs.backup "$ELLIPSIS_PATH"

# Move project into place
if ! ( mkdir -p "${ELLIPSIS_PATH%/*}" && mv "$tmp_dir/ellipsis" "$ELLIPSIS_PATH" ) ; then
    # Clean up
    rm -rf "$tmp_dir"

    # Log error
    log.fail "Installation failed!"
    msg.print 'Please check $ELLIPSIS_PATH and try again!'
    exit 1
fi

# Add ellipsis binary to PATH
ELLIPSIS_BIN_SHIM="${ELLIPSIS_BIN_SHIM:-$ELLIPSIS_BIN}"
if [ "$ELLIPSIS_BIN_SHIM" != "$ELLIPSIS_BIN" ]; then
    mkdir -p "$ELLIPSIS_BIN_SHIM"
    ln -s "$ELLIPSIS_BIN/ellipsis" "$ELLIPSIS_BIN_SHIM/ellipsis"
fi

# Create ellipsis configuration
#fs.backup "$ELLIPSIS_CONFIG"
mkdir -p "${ELLIPSIS_CONFIG%/*}" && cat << EOF >> "$ELLIPSIS_CONFIG"

# Installaion of $(date):
export ELLIPSIS_HOME=$ELLIPSIS_HOME
export ELLIPSIS_BIN_SHIM=$ELLIPSIS_BIN_SHIM
export ELLIPSIS_PACKAGES=$ELLIPSIS_PACKAGES
export ELLIPSIS_PATH=$ELLIPSIS_PATH

EOF

# Clean up (only necessary on cygwin, really).
rm -rf "$tmp_dir"

# Backwards compatibility, originally referred to packages as modules.
PACKAGES="${PACKAGES:-$MODULES}"

if [ "$PACKAGES" ]; then
    msg.print ''
    for pkg in ${PACKAGES[*]}; do
        msg.bold "Installing $pkg"
        ellipsis.install "$pkg"
    done
fi

msg.print "
                                   ~ fin ~
   _    _    _
  /\_\ /\_\ /\_\
  \/_/ \/_/ \/_/                         …because \$HOME is where the <3 is!

Be sure to add '. \$HOME${ELLIPSIS_PATH##$HOME}/init.sh )\"' to your bashrc or zshrc. Also 
a configuration file has been created in '\$HOME${ELLIPSIS_CONFIG##$HOME}'. You can also
directly run ellipsis with this alias: 'alias ellipsis='\$HOME${ELLIPSIS_BIN_SHIM##$HOME}/ellipsis''

Run 'ellipsis install <package>' to install a new package.
Run 'ellipsis search <query>' to search for packages to install.
Run 'ellipsis help' for additional options."

if [ -z "$PACKAGES" ]; then
    msg.print ''
    msg.print 'Check http://docs.ellipsis.sh/pkgindex for available packages!'
fi
