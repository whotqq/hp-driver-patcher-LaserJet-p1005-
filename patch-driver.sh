#!/usr/bin/env bash
# =============================================================================
# patch-driver.sh — macOS Printer Driver Package Patcher
# =============================================================================
# Patches a macOS .pkg installer by neutralising OS version restrictions in
# the Distribution file.  Handles both XML-based and JavaScript-based checks.
#
# Usage:
#   ./scripts/patch-driver.sh /path/to/HewlettPackardPrinterDrivers.pkg
#
# Tip: type the command, then drag the .pkg from Finder into Terminal —
#      macOS will insert the full quoted path for you automatically.
#
# Output:
#   hpfix_work/fixed.pkg
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
DIM='\033[2m'
RST='\033[0m'

info()    { echo -e "${BLU}[INFO]${RST}  $*"; }
success() { echo -e "${GRN}[OK]${RST}    $*"; }
warn()    { echo -e "${YLW}[WARN]${RST}  $*"; }
die()     { echo -e "${RED}[ERROR]${RST} $*" >&2; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${CYN}"
cat <<'BANNER'
  ╔══════════════════════════════════════════════╗
  ║      macOS Printer Driver Package Patcher    ║
  ║      github.com/whotqq/hp-driver-patcher     ║
  ╚══════════════════════════════════════════════╝
BANNER
echo -e "${RST}"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    echo -e "  ${RED}No file provided.${RST}"
    echo
    echo -e "  Usage:  ${GRN}./scripts/patch-driver.sh${RST} ${YLW}<installer.pkg>${RST}"
    echo
    echo -e "  ${DIM}Tip: type the command, then drag the .pkg file from Finder${RST}"
    echo -e "  ${DIM}into this Terminal window — macOS inserts the full path for you.${RST}"
    echo
    echo -e "  Example:"
    echo -e "  ${DIM}./scripts/patch-driver.sh ~/Downloads/HewlettPackardPrinterDrivers.pkg${RST}"
    exit 1
}

# ── Dependency check ──────────────────────────────────────────────────────────
check_dependencies() {
    local missing=0
    for cmd in pkgutil sed diff find; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}[ERROR]${RST} Required command not found: $cmd" >&2
            missing=1
        fi
    done
    [[ $missing -eq 0 ]] || die "Install missing dependencies and retry."
}

check_dependencies

# ── Argument validation ───────────────────────────────────────────────────────
[[ $# -eq 0 ]] && usage
[[ "${1}" == "-h" || "${1}" == "--help" ]] && usage

INPUT_PKG="$1"

[[ -f "$INPUT_PKG" ]]       || die "File not found: '$INPUT_PKG'"
[[ "$INPUT_PKG" == *.pkg ]] || warn "File does not have a .pkg extension — continuing anyway."

# ── Paths ─────────────────────────────────────────────────────────────────────
WORK_DIR="hpfix_work"
EXPAND_DIR="${WORK_DIR}/expanded"
DIST_FILE="${EXPAND_DIR}/Distribution"
OUTPUT_PKG="${WORK_DIR}/fixed.pkg"
PATCHED_VERSION="30.0"

# ── Safety: prevent overwriting a previous run ────────────────────────────────
if [[ -d "$EXPAND_DIR" ]]; then
    warn "Work directory '$EXPAND_DIR' already exists."
    read -r -p "  Remove it and start fresh? [y/N] " confirm
    case "${confirm:-n}" in
        [yY][eE][sS]|[yY]) rm -rf "$EXPAND_DIR" ;;
        *) die "Aborted. Remove '$EXPAND_DIR' manually and retry." ;;
    esac
fi

mkdir -p "$WORK_DIR"

# ── Step 1: Expand the package ────────────────────────────────────────────────
info "Source  : '$INPUT_PKG'"
info "Expanding package..."

pkgutil --expand "$INPUT_PKG" "$EXPAND_DIR" 2>/dev/null \
    || die "pkgutil --expand failed. Is '$INPUT_PKG' a valid flat .pkg?"

success "Package expanded → $EXPAND_DIR"

# ── Step 2: Locate the Distribution file ─────────────────────────────────────
if [[ ! -f "$DIST_FILE" ]]; then
    DIST_FILE=$(find "$EXPAND_DIR" -maxdepth 3 -name "Distribution" -print | head -n 1)
    [[ -n "$DIST_FILE" ]] || die "Distribution file not found inside the expanded package."
    warn "Distribution found at non-standard path: $DIST_FILE"
fi
success "Distribution file located: $DIST_FILE"

# ── Step 3: Backup original Distribution ─────────────────────────────────────
cp "$DIST_FILE" "${DIST_FILE}.bak"
success "Backup saved → ${DIST_FILE}.bak"

# =============================================================================
# PATCH ENGINE
# Tries XML patching first, then JS patching.
# Each function returns 0 if it modified the file, 1 if it changed nothing.
# =============================================================================

# ── Helper: did the file change since backup? ─────────────────────────────────
file_was_modified() { ! diff -q "${DIST_FILE}.bak" "$DIST_FILE" &>/dev/null; }

# snapshot before this patch block (so each engine can check its own delta)
snapshot() { cp "$DIST_FILE" "${DIST_FILE}.snap"; }
snap_was_modified() { ! diff -q "${DIST_FILE}.snap" "$DIST_FILE" &>/dev/null; }

# ── XML Patch ─────────────────────────────────────────────────────────────────
# Targets declarative XML constraints in the Distribution file.
#
#   Handled patterns:
#     <os-version min="10.9" max="12.0"/>
#     <os compare="LessThan"    string="13.0"/>
#     <os compare="GreaterThan" string="11.0"/>
#
apply_xml_patch() {
    info "Scanning for XML-based version restrictions..."

    local matches
    matches=$(
        { grep -oE 'os compare="[^"]+" string="[0-9.]+"' "$DIST_FILE" || true; }
        { grep -oE 'os-version[^/]*/>'                   "$DIST_FILE" || true; }
    )

    if [[ -z "$matches" ]]; then
        info "No XML version restrictions detected."
        return 1
    fi

    echo -e "${YLW}  Found XML restrictions:${RST}"
    echo "$matches" | sed 's/^/    /'

    snapshot
    sed -i.tmp \
        -e 's/\(os-version[^>]*max="\)[^"]*"/\1'"${PATCHED_VERSION}"'"/g' \
        -e 's/\(os-version[^>]*min="\)[^"]*"/\11.0"/g' \
        -e '/compare="LessThan"/{s/\(string="\)[0-9][0-9]*\.[0-9][0-9]*"/\1'"${PATCHED_VERSION}"'"/g;}' \
        -e '/compare="GreaterThan"/{s/\(string="\)[0-9][0-9]*\.[0-9][0-9]*"/\10.0"/g;}' \
        "$DIST_FILE"
    rm -f "${DIST_FILE}.tmp"

    if snap_was_modified; then
        success "[XML patch applied] Version ceilings raised → ${PATCHED_VERSION}"
        return 0
    else
        warn "XML restrictions detected but file was not modified."
        warn "Patterns may use non-standard formatting."
        return 1
    fi
}

# ── JS Patch ──────────────────────────────────────────────────────────────────
# Targets JavaScript logic embedded in <script> blocks inside Distribution.
#
# Strategy A — compareVersions: raise the version ceiling in the comparison.
#   Before: system.compareVersions(system.version.ProductVersion, '15.0') > 0
#   After:  system.compareVersions(system.version.ProductVersion, '30.0') > 0
#   Effect: the condition is now "is macOS > 30.0?" — always false on real hw.
#
# Strategy B — return false in check functions: replace with return true.
#   Scoped to known installer check function signatures to avoid touching
#   unrelated helper functions that might legitimately return false.
#   Covered: InstallationCheck, VolumeCheck, HostCheck, MigrateCheck.
#
# Strategy C — fallback: if neither A nor B matched, replace every
#   'return false' inside any <script> block.  More aggressive but still
#   confined to the Distribution file, which only contains installer logic.
#
apply_js_patch() {
    info "Scanning for JavaScript-based version restrictions..."

    # Quick presence check — bail early if there's no JS at all
    if ! grep -q '<script' "$DIST_FILE" 2>/dev/null; then
        info "No <script> blocks found — JS patch not applicable."
        return 1
    fi

    local js_patched=0

    # ── Strategy A: compareVersions version ceiling ───────────────────────────
    # Matches the second string argument of system.compareVersions().
    # Uses a conservative pattern: only replaces when the call is on one line
    # and the version looks like a dotted number ('X.Y' or 'X.Y.Z').
    snapshot
    sed -i.tmp \
        -e "s/\(system\.compareVersions([^,)]*,[[:space:]]*'\)[0-9][0-9.]*\('\)/\1${PATCHED_VERSION}\2/g" \
        "$DIST_FILE"
    rm -f "${DIST_FILE}.tmp"

    if snap_was_modified; then
        success "[JS patch — Strategy A] compareVersions ceiling → '${PATCHED_VERSION}'"
        js_patched=1
    else
        info "Strategy A: no compareVersions patterns found."
    fi

    # ── Strategy B: return false inside named check functions ─────────────────
    # sed address range /start/,/end/ applies the substitution only between
    # the function header and its closing brace.
    # Covers standard installer check function names used by Apple's installer.
    snapshot
    sed -i.tmp \
        -e '/function[[:space:]]\{1,\}InstallationCheck/,/^[[:space:]]*}/{s/return[[:space:]]\{1,\}false/return true/g;}' \
        -e '/function[[:space:]]\{1,\}VolumeCheck/,/^[[:space:]]*}/{s/return[[:space:]]\{1,\}false/return true/g;}' \
        -e '/function[[:space:]]\{1,\}HostCheck/,/^[[:space:]]*}/{s/return[[:space:]]\{1,\}false/return true/g;}' \
        -e '/function[[:space:]]\{1,\}MigrateCheck/,/^[[:space:]]*}/{s/return[[:space:]]\{1,\}false/return true/g;}' \
        "$DIST_FILE"
    rm -f "${DIST_FILE}.tmp"

    if snap_was_modified; then
        success "[JS patch — Strategy B] 'return false' → 'return true' in check functions"
        js_patched=1
    else
        info "Strategy B: no 'return false' found in check function bodies."
    fi

    # ── Strategy C: fallback — all return false inside any <script> block ─────
    # Only runs if neither A nor B changed anything.
    # Safe because Distribution <script> blocks contain only installer logic.
    if [[ $js_patched -eq 0 ]]; then
        warn "Strategies A and B found nothing — applying fallback (Strategy C)..."
        snapshot
        sed -i.tmp \
            -e '/<script/,/<\/script>/{s/return[[:space:]]\{1,\}false/return true/g;}' \
            "$DIST_FILE"
        rm -f "${DIST_FILE}.tmp"

        if snap_was_modified; then
            success "[JS patch — Strategy C] Fallback: all 'return false' in <script> blocks → 'return true'"
            js_patched=1
        else
            info "Strategy C: no 'return false' found in <script> blocks either."
        fi
    fi

    rm -f "${DIST_FILE}.snap"
    [[ $js_patched -eq 1 ]] && return 0 || return 1
}

# =============================================================================
# Step 4: Run the patch engine
# =============================================================================
echo
info "Running patch engine..."
echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

XML_PATCHED=0
JS_PATCHED=0

apply_xml_patch && XML_PATCHED=1 || true
echo -e "  ${DIM}──────────────────────────────────────────────${RST}"
apply_js_patch  && JS_PATCHED=1  || true
echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

# ── Step 5: Overall result ────────────────────────────────────────────────────
echo
if [[ $XML_PATCHED -eq 0 && $JS_PATCHED -eq 0 ]]; then
    warn "No patches were applied."
    warn "The Distribution file may use an unsupported restriction format."
    warn "Inspect it manually: $DIST_FILE"
    warn "Original backup   : ${DIST_FILE}.bak"
    echo
    # Rebuild anyway so the user gets a .pkg to inspect
else
    if file_was_modified; then
        info "Diff preview (first 50 lines):"
        set +o pipefail
        diff "${DIST_FILE}.bak" "$DIST_FILE" | head -50 | sed 's/^/    /'
        set -o pipefail
    fi
fi

# ── Step 6: Rebuild the package ───────────────────────────────────────────────
echo
info "Rebuilding package..."

pkgutil --flatten "$EXPAND_DIR" "$OUTPUT_PKG" 2>/dev/null \
    || die "pkgutil --flatten failed."

success "Fixed package → ${OUTPUT_PKG}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo
echo -e "${CYN}═══════════════════════════════════════════════════════${RST}"
echo -e "${GRN}  Patching complete!${RST}"
echo
echo -e "  Input  : ${INPUT_PKG}"
echo -e "  Output : $(pwd)/${OUTPUT_PKG}"
echo -e "  Backup : ${DIST_FILE}.bak"
echo

# Patch summary line
if   [[ $XML_PATCHED -eq 1 && $JS_PATCHED -eq 1 ]]; then
    echo -e "  Applied: ${GRN}XML patch${RST} + ${GRN}JS patch${RST}"
elif [[ $XML_PATCHED -eq 1 ]]; then
    echo -e "  Applied: ${GRN}XML patch${RST}"
elif [[ $JS_PATCHED -eq 1 ]]; then
    echo -e "  Applied: ${GRN}JS patch${RST}"
else
    echo -e "  Applied: ${YLW}none — verify manually before installing${RST}"
fi

echo
echo -e "  To install:"
echo -e "  ${YLW}sudo installer -pkg \"${OUTPUT_PKG}\" -target /${RST}"
echo -e "  ${DIM}or double-click ${OUTPUT_PKG} in Finder${RST}"
echo -e "${CYN}═══════════════════════════════════════════════════════${RST}"
echo
warn "For personal use only. Do not redistribute patched packages."
