#!/usr/bin/env bash
set -e

# ==============================================================================
# One-line installer for customized GNU nano
# Supports: Ubuntu, Debian, Alpine, CentOS/RHEL/Fedora, Arch Linux, etc.
# Architectures: x86_64 (amd64), aarch64 (arm64)
# ==============================================================================

REPO_OWNER="LDQONJ"
REPO_NAME="nano"
DEFAULT_BRANCH="main"

GITHUB_REPO="${REPO_OWNER}/${REPO_NAME}"
INSTALL_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/nano"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; exit 1; }

# Sudo check
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        error "This script requires root privileges. Please run as root or install sudo."
    fi
fi

# Detect Architecture
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64|amd64)
        TARGET_ARCH="amd64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="arm64"
        ;;
    *)
        TARGET_ARCH=""
        ;;
esac

OS="$(uname -s)"
if [ "${OS}" != "Linux" ]; then
    error "Only Linux is supported at this moment (got: ${OS})."
fi

install_from_binary() {
    info "Attempting to download prebuilt static binary for ${TARGET_ARCH}..."
    TMP_DIR="$(mktemp -d)"
    TARBALL="nano-linux-${TARGET_ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${TARBALL}"

    if ! curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${TARBALL}" 2>/dev/null; then
        warn "Could not download prebuilt release from ${DOWNLOAD_URL}"
        rm -rf "${TMP_DIR}"
        return 1
    fi

    info "Extracting and installing files..."
    tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"
    
    $SUDO mkdir -p "${INSTALL_DIR}"
    $SUDO cp -f "${TMP_DIR}/bin/nano" "${INSTALL_DIR}/nano"
    $SUDO chmod 755 "${INSTALL_DIR}/nano"

    if [ -d "${TMP_DIR}/share/nano" ]; then
        $SUDO mkdir -p "${SHARE_DIR}"
        $SUDO cp -rf "${TMP_DIR}/share/nano/"* "${SHARE_DIR}/"
    fi

    rm -rf "${TMP_DIR}"
    return 0
}

install_from_source() {
    info "Compiling and installing from source..."
    
    # Check package manager and install dependencies
    if command -v apt-get >/dev/null 2>&1; then
        info "Detected Debian/Ubuntu. Installing build dependencies..."
        $SUDO apt-get update -qq
        $SUDO apt-get install -y -qq git build-essential autoconf automake autopoint pkg-config gettext libncurses-dev texinfo curl
    elif command -v apk >/dev/null 2>&1; then
        info "Detected Alpine Linux. Installing build dependencies..."
        $SUDO apk update
        $SUDO apk add git alpine-sdk autoconf automake gettext-dev ncurses-dev texinfo curl python3 coreutils linux-headers
    elif command -v dnf >/dev/null 2>&1; then
        info "Detected Fedora/RHEL/CentOS (dnf). Installing build dependencies..."
        $SUDO dnf install -y git gcc make autoconf automake gettext-devel ncurses-devel texinfo curl
    elif command -v pacman >/dev/null 2>&1; then
        info "Detected Arch Linux. Installing build dependencies..."
        $SUDO pacman -Sy --noconfirm git base-devel gettext ncurses texinfo curl
    else
        warn "Unknown package manager. Please ensure git, gcc, autoconf, automake, gettext, and ncurses-dev are installed."
    fi

    BUILD_DIR="$(mktemp -d)"
    info "Cloning source code from https://github.com/${GITHUB_REPO}.git..."
    git clone --depth 1 "https://github.com/${GITHUB_REPO}.git" "${BUILD_DIR}/nano"
    cd "${BUILD_DIR}/nano"

    info "Configuring and building..."
    ./autogen.sh
    ./configure --prefix=/usr/local
    make -j$(nproc)
    $SUDO make install

    cd /
    rm -rf "${BUILD_DIR}"
}

# Main flow
if [ -n "${TARGET_ARCH}" ] && install_from_binary; then
    success "Installed customized nano from prebuilt release!"
else
    warn "Falling back to compiling from source..."
    install_from_source
    success "Successfully built and installed customized nano from source!"
fi

# Ensure /usr/local/bin/nano takes precedence
if [ -f "/usr/bin/nano" ] && [ ! -L "/usr/bin/nano" ]; then
    # If /usr/bin/nano exists and is a regular file, replace it with a symlink to /usr/local/bin/nano
    # so system commands/cron that call /usr/bin/nano will also use the custom nano
    $SUDO ln -sf "${INSTALL_DIR}/nano" /usr/bin/nano
fi

# Verify
NANO_VER="$("${INSTALL_DIR}/nano" --version | head -n 1)"
success "Installation complete! ${NANO_VER}"
info "Custom features enabled by default:"
info "  - Alt + ↑ / ↓ : Copy current line up / down"
info "  - Alt + Shift + ↑ / ↓ : Move current line up / down"
info "  - Auto-indentation on Enter enabled by default"
info "  - Syntax highlighting enabled by default"
