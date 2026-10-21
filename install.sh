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

OS="$(uname -s)"
IS_WINDOWS=false
case "${OS}" in
    Linux)
        IS_WINDOWS=false
        ;;
    MINGW*|MSYS*|CYGWIN*)
        IS_WINDOWS=true
        ;;
    *)
        error "Unsupported operating system: ${OS}."
        ;;
esac

# Sudo check
SUDO=""
if [ "$IS_WINDOWS" = "false" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
        else
            error "This script requires root privileges. Please run as root or install sudo."
        fi
    fi
    INSTALL_DIR="/usr/local/bin"
    SHARE_DIR="/usr/local/share/nano"
else
    # For Windows Git Bash / MSYS2, install into /usr/bin or existing nano directory
    if command -v nano >/dev/null 2>&1; then
        INSTALL_DIR="$(dirname "$(which nano)")"
    else
        INSTALL_DIR="/usr/bin"
    fi
    SHARE_DIR="/usr/share/nano"
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
        TARGET_ARCH="amd64"
        ;;
esac

install_from_binary() {
    TMP_DIR="$(mktemp -d)"
    if [ "$IS_WINDOWS" = "true" ]; then
        info "Detected Windows (Git Bash). Attempting to download prebuilt binary for ${TARGET_ARCH}..."
        ARCHIVE="nano-windows-${TARGET_ARCH}.zip"
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${ARCHIVE}"
        
        if ! curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}" 2>/dev/null; then
            # Fallback to amd64 if arm64 not found (since x64 runs seamlessly on ARM64 Windows via Prism)
            ARCHIVE="nano-windows-amd64.zip"
            DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${ARCHIVE}"
            if ! curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}" 2>/dev/null; then
                warn "Could not download prebuilt release from ${DOWNLOAD_URL}"
                rm -rf "${TMP_DIR}"
                return 1
            fi
        fi

        info "Extracting and installing files..."
        if command -v unzip >/dev/null 2>&1; then
            unzip -q -o "${TMP_DIR}/${ARCHIVE}" -d "${TMP_DIR}"
        else
            tar -xf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"
        fi

        mkdir -p "${INSTALL_DIR}"
        if ! cp -f "${TMP_DIR}/bin/nano.exe" "${INSTALL_DIR}/nano.exe" 2>/dev/null; then
            error "Permission denied writing to ${INSTALL_DIR}/nano.exe. Please right-click Git Bash and select 'Run as administrator' to install."
        fi
        chmod 755 "${INSTALL_DIR}/nano.exe"

        if [ -d "${TMP_DIR}/share" ]; then
            mkdir -p "/usr/share"
            cp -rf "${TMP_DIR}/share/"* "/usr/share/" 2>/dev/null || true
        fi

        rm -rf "${TMP_DIR}"
        return 0
    else
        info "Attempting to download prebuilt static binary for ${TARGET_ARCH}..."
        ARCHIVE="nano-linux-${TARGET_ARCH}.tar.gz"
        DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${ARCHIVE}"

        if ! curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}" 2>/dev/null; then
            warn "Could not download prebuilt release from ${DOWNLOAD_URL}"
            rm -rf "${TMP_DIR}"
            return 1
        fi

        info "Extracting and installing files..."
        tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"
        
        $SUDO mkdir -p "${INSTALL_DIR}"
        $SUDO cp -f "${TMP_DIR}/bin/nano" "${INSTALL_DIR}/nano"
        $SUDO chmod 755 "${INSTALL_DIR}/nano"

        if [ -d "${TMP_DIR}/share" ]; then
            $SUDO mkdir -p "/usr/local/share"
            $SUDO cp -rf "${TMP_DIR}/share/"* "/usr/local/share/"
        fi

        rm -rf "${TMP_DIR}"
        return 0
    fi
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

# Ensure /usr/local/bin/nano takes precedence on Linux
if [ "$IS_WINDOWS" = "false" ]; then
    if [ -f "/usr/bin/nano" ] && [ ! -L "/usr/bin/nano" ]; then
        # If /usr/bin/nano exists and is a regular file, replace it with a symlink to /usr/local/bin/nano
        # so system commands/cron that call /usr/bin/nano will also use the custom nano
        $SUDO ln -sf "${INSTALL_DIR}/nano" /usr/bin/nano
    fi
    NANO_BIN="${INSTALL_DIR}/nano"
else
    NANO_BIN="${INSTALL_DIR}/nano.exe"
fi

# Verify
NANO_VER="$("${NANO_BIN}" --version | head -n 1)"
success "Installation complete! ${NANO_VER}"
info "Custom features enabled by default:"
info "  - Alt + ↑ / ↓ : Copy current line up / down"
info "  - Alt + Shift + ↑ / ↓ : Move current line up / down"
info "  - Auto-indentation on Enter enabled by default"
info "  - Syntax highlighting enabled by default"
