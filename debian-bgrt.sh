#!/usr/bin/env bash
# ==============================================================================
# debian-bgrt.sh
# 
# Configure Debian with Fedora's BGRT Plymouth boot theme + Papirus Debian logo,
# with full apply and revert (rollback) capabilities.
#
# Repository: https://github.com/Antux912012/debian-bgrt-plymouth
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/var/lib/plymouth-debian-bgrt"
STATE_FILE="${STATE_DIR}/state.env"
BACKUP_DIR="${STATE_DIR}/backup"
ASSETS_DIR="${SCRIPT_DIR}/assets"

SPINNER_THEME_DIR="/usr/share/plymouth/themes/spinner"
BGRT_THEME_DIR="/usr/share/plymouth/themes/bgrt"

# ------------------------------------------------------------------------------
# Terminal styling
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    RED="\033[1;31m"
    BLUE="\033[1;34m"
    CYAN="\033[1;36m"
    RESET="\033[0m"
else
    BOLD=""
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    CYAN=""
    RESET=""
fi

log_info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()    { echo -e "${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }

# ------------------------------------------------------------------------------
# Usage & Help
# ------------------------------------------------------------------------------
show_help() {
    echo -e "${BOLD}Usage:${RESET}
  sudo $0 apply [variant]    Apply the Fedora-style BGRT theme & watermark
  sudo $0 revert             Revert all changes and restore original Debian theme
  $0 status                  Display current theme, watermark, and BGRT status
  $0 help                    Show this help message

${BOLD}Watermark Variants (for apply):${RESET}
  ${GREEN}text${RESET}   (Default) Fedora style: circular Papirus badge + white 'debian' text
  ${GREEN}badge${RESET}  Minimalist: circular Papirus Debian badge alone (64x64)
  ${GREEN}swirl${RESET}  Standalone Debian swirl alone in Papirus #f9548f color

${BOLD}Examples:${RESET}
  sudo $0 apply
  sudo $0 apply badge
  sudo $0 revert
  $0 status"
}

# ------------------------------------------------------------------------------
# Permission check
# ------------------------------------------------------------------------------
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This action requires root privileges."
        echo "Please run: sudo $0 $1" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Check system dependencies
# ------------------------------------------------------------------------------
check_system_deps() {
    local missing=()
    for cmd in plymouth update-initramfs; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ! -x /usr/sbin/plymouth-set-default-theme ]; then
        missing+=("plymouth-set-default-theme")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required Plymouth utilities: ${missing[*]}"
        log_error "Install them via: sudo apt install plymouth plymouth-themes"
        exit 1
    fi

    if [ ! -d "$BGRT_THEME_DIR" ] || [ ! -d "$SPINNER_THEME_DIR" ]; then
        log_error "Plymouth 'bgrt' or 'spinner' theme directory is missing."
        log_error "Install themes via: sudo apt install plymouth-themes"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Status command
# ------------------------------------------------------------------------------
do_status() {
    echo -e "${BOLD}=== Plymouth Debian BGRT Status ===${RESET}"

    # Current Plymouth Theme
    local cur_theme
    cur_theme="$(/usr/sbin/plymouth-set-default-theme 2>/dev/null || echo "Unknown")"
    echo -e "Current Active Theme:  ${BOLD}${cur_theme}${RESET}"

    # State file status
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
        echo -e "Theme State:           ${GREEN}Managed by debian-bgrt.sh${RESET}"
        echo -e "Original Theme:        ${BOLD}${ORIGINAL_THEME}${RESET}"
        echo -e "Applied Variant:       ${BOLD}${APPLIED_VARIANT}${RESET}"
        echo -e "Applied Date:          ${APPLIED_DATE}"
    else
        echo -e "Theme State:           ${YELLOW}Stock / Unmanaged${RESET}"
    fi

    # Watermark files
    echo -n "Spinner Watermark:     "
    if [ -f "${SPINNER_THEME_DIR}/watermark.png" ]; then
        echo -e "${GREEN}Present${RESET} (${SPINNER_THEME_DIR}/watermark.png)"
    else
        echo -e "${YELLOW}None${RESET}"
    fi

    echo -n "BGRT Watermark:        "
    if [ -f "${BGRT_THEME_DIR}/watermark.png" ]; then
        echo -e "${GREEN}Present${RESET} (${BGRT_THEME_DIR}/watermark.png)"
    else
        echo -e "${YELLOW}None${RESET}"
    fi

    # UEFI ACPI BGRT Firmware status
    echo -n "UEFI BGRT OEM Support: "
    if [ -d /sys/firmware/acpi/bgrt ]; then
        local status=0
        [ -f /sys/firmware/acpi/bgrt/status ] && status="$(cat /sys/firmware/acpi/bgrt/status 2>/dev/null || echo 0)"
        if [ "$status" = "1" ]; then
            echo -e "${GREEN}Active & Valid${RESET} (OEM logo will display during boot)"
        else
            echo -e "${YELLOW}Detected but status=$status${RESET}"
        fi
    else
        echo -e "${YELLOW}Not detected (Legacy BIOS or non-BGRT UEFI)${RESET}"
    fi
}

# ------------------------------------------------------------------------------
# Apply command
# ------------------------------------------------------------------------------
do_apply() {
    require_root "apply"
    check_system_deps

    local variant="${1:-text}"
    local watermark_src=""
    local variant_desc=""

    case "$variant" in
        badge|icon)
            variant="badge"
            watermark_src="${ASSETS_DIR}/watermark-badge.png"
            variant_desc="Circular Papirus Debian badge alone (64x64)"
            ;;
        swirl)
            variant="swirl"
            watermark_src="${ASSETS_DIR}/watermark-swirl.png"
            variant_desc="Standalone Debian swirl alone in Papirus #f9548f"
            ;;
        text|fedora|*)
            variant="text"
            watermark_src="${ASSETS_DIR}/watermark-badge-with-text.png"
            variant_desc="Fedora style: Papirus badge + white 'debian' text"
            ;;
    esac

    if [ ! -f "$watermark_src" ]; then
        log_error "Watermark asset not found: $watermark_src"
        log_error "Please run scripts/generate-assets.py first or ensure assets/ contains PNG files."
        exit 1
    fi

    log_step "Applying Plymouth BGRT Theme with Papirus Debian Logo ($variant_desc)..."

    # Step 1: Backup current state if not already recorded
    mkdir -p "$STATE_DIR" "$BACKUP_DIR"

    if [ ! -f "$STATE_FILE" ]; then
        local current_theme
        current_theme="$(/usr/sbin/plymouth-set-default-theme 2>/dev/null || echo "")"
        if [ -z "$current_theme" ] || [ "$current_theme" = "bgrt" ]; then
            # If already bgrt or empty, fallback to debian alternative default
            current_theme="ceratopsian"
        fi

        log_info "Saving original theme state (${current_theme})..."
        cat <<EOF > "$STATE_FILE"
ORIGINAL_THEME="${current_theme}"
APPLIED_VARIANT="${variant}"
APPLIED_DATE="$(date --iso-8601=seconds)"
HAD_WATERMARK_SPINNER=0
HAD_WATERMARK_BGRT=0
EOF

        # Backup any existing watermarks
        if [ -f "${SPINNER_THEME_DIR}/watermark.png" ]; then
            cp -p "${SPINNER_THEME_DIR}/watermark.png" "${BACKUP_DIR}/spinner-watermark.png"
            sed -i 's/HAD_WATERMARK_SPINNER=0/HAD_WATERMARK_SPINNER=1/' "$STATE_FILE"
        fi

        if [ -f "${BGRT_THEME_DIR}/watermark.png" ]; then
            cp -p "${BGRT_THEME_DIR}/watermark.png" "${BACKUP_DIR}/bgrt-watermark.png"
            sed -i 's/HAD_WATERMARK_BGRT=0/HAD_WATERMARK_BGRT=1/' "$STATE_FILE"
        fi
    else
        log_info "Existing backup state found; updating applied variant to '${variant}'..."
        sed -i "s/^APPLIED_VARIANT=.*/APPLIED_VARIANT=\"${variant}\"/" "$STATE_FILE"
        sed -i "s/^APPLIED_DATE=.*/APPLIED_DATE=\"$(date --iso-8601=seconds)\"/" "$STATE_FILE"
    fi

    # Step 2: Install watermark image
    log_step "Installing watermark image to Plymouth themes..."
    cp -v "$watermark_src" "${SPINNER_THEME_DIR}/watermark.png"
    cp -v "$watermark_src" "${BGRT_THEME_DIR}/watermark.png"
    chmod 644 "${SPINNER_THEME_DIR}/watermark.png" "${BGRT_THEME_DIR}/watermark.png"

    # Step 3: Set default theme to bgrt
    log_step "Setting default theme to 'bgrt'..."
    /usr/sbin/plymouth-set-default-theme bgrt

    # Step 4: Rebuild initramfs
    log_step "Rebuilding initramfs for all installed kernels (this may take a few moments)..."
    update-initramfs -u -k all

    echo ""
    log_ok "${BOLD}Success! Fedora-style BGRT theme is now active on Debian.${RESET}"
    echo -e "On your next boot you will see:"
    echo -e "  1. Computer manufacturer logo (UEFI BGRT splash)"
    echo -e "  2. Plymouth spinner animation below the OEM logo"
    echo -e "  3. Centered bottom Debian logo (${variant_desc})"
    echo ""
    echo -e "To revert at any time, run: ${BOLD}sudo $0 revert${RESET}"
}

# ------------------------------------------------------------------------------
# Revert command
# ------------------------------------------------------------------------------
do_revert() {
    require_root "revert"
    check_system_deps

    log_step "Reverting Plymouth BGRT theme and restoring original Debian configuration..."

    local target_theme="ceratopsian"
    local had_spinner_wm=0
    local had_bgrt_wm=0

    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
        target_theme="${ORIGINAL_THEME:-ceratopsian}"
        had_spinner_wm="${HAD_WATERMARK_SPINNER:-0}"
        had_bgrt_wm="${HAD_WATERMARK_BGRT:-0}"
        log_info "Restoring previous theme: ${BOLD}${target_theme}${RESET}..."
    else
        log_warn "No state file found at ${STATE_FILE}. Falling back to Debian default '${target_theme}'."
    fi

    # Step 1: Restore or remove watermark files
    if [ "$had_spinner_wm" -eq 1 ] && [ -f "${BACKUP_DIR}/spinner-watermark.png" ]; then
        log_info "Restoring original spinner watermark..."
        cp -v "${BACKUP_DIR}/spinner-watermark.png" "${SPINNER_THEME_DIR}/watermark.png"
    else
        if [ -f "${SPINNER_THEME_DIR}/watermark.png" ]; then
            log_info "Removing spinner watermark..."
            rm -f "${SPINNER_THEME_DIR}/watermark.png"
        fi
    fi

    if [ "$had_bgrt_wm" -eq 1 ] && [ -f "${BACKUP_DIR}/bgrt-watermark.png" ]; then
        log_info "Restoring original bgrt watermark..."
        cp -v "${BACKUP_DIR}/bgrt-watermark.png" "${BGRT_THEME_DIR}/watermark.png"
    else
        if [ -f "${BGRT_THEME_DIR}/watermark.png" ]; then
            log_info "Removing bgrt watermark..."
            rm -f "${BGRT_THEME_DIR}/watermark.png"
        fi
    fi

    # Step 2: Switch theme back to original
    log_step "Setting Plymouth default theme back to '${target_theme}'..."
    /usr/sbin/plymouth-set-default-theme "$target_theme"

    # Step 3: Rebuild initramfs
    log_step "Rebuilding initramfs for all installed kernels..."
    update-initramfs -u -k all

    # Step 4: Remove state file
    if [ -f "$STATE_FILE" ]; then
        rm -rf "$STATE_DIR"
        log_info "Removed state and backup directory (${STATE_DIR})."
    fi

    echo ""
    log_ok "${BOLD}Successfully reverted!${RESET} System restored to '${target_theme}' theme."
}

# ------------------------------------------------------------------------------
# Main entrypoint
# ------------------------------------------------------------------------------
EXEC_NAME="$(basename "$0")"
if [ "$EXEC_NAME" = "install.sh" ]; then
    if [ $# -eq 0 ]; then
        set -- "apply"
    elif [ "$1" != "apply" ] && [ "$1" != "revert" ] && [ "$1" != "status" ] && [ "$1" != "help" ] && [ "$1" != "-h" ] && [ "$1" != "--help" ]; then
        set -- "apply" "$@"
    fi
elif [ "$EXEC_NAME" = "uninstall.sh" ]; then
    set -- "revert"
fi

case "${1:-}" in
    apply|install)
        shift
        do_apply "$@"
        ;;
    revert|restore|uninstall)
        do_revert
        ;;
    status)
        do_status
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
