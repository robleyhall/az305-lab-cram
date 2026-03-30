#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# AZ-305 Lab — Tool Installer
#
# Detects the OS and installs Azure CLI, Terraform, and jq if missing.
# Prompts before each installation.
###############################################################################

# ── Colours & symbols ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

info()  { echo -e "${CYAN}ℹ${NC}  $1"; }
ok()    { echo -e "${PASS} $1"; }
err()   { echo -e "${FAIL} $1"; }
warn()  { echo -e "${WARN} $1"; }

header() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ── Prompt helper ────────────────────────────────────────────────────────────
confirm() {
    local msg="$1"
    if [[ "${AUTO_YES:-}" == "true" ]]; then
        return 0
    fi
    read -r -p "$(echo -e "${YELLOW}?${NC}") ${msg} [y/N] " answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

###############################################################################
# Detect OS & package manager
###############################################################################
header "Detecting Operating System"

OS="unknown"
PKG=""

if [[ "$(uname -s)" == "Darwin" ]]; then
    OS="macos"
    if command -v brew &>/dev/null; then
        PKG="brew"
        ok "macOS detected — Homebrew available"
    else
        err "macOS detected but Homebrew is not installed"
        info "Install Homebrew first: https://brew.sh"
        exit 1
    fi
elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID}" in
        ubuntu|debian|linuxmint|pop)
            OS="debian"
            PKG="apt"
            ok "${PRETTY_NAME} detected — using apt"
            ;;
        rhel|centos|fedora|rocky|almalinux|ol)
            OS="rhel"
            if command -v dnf &>/dev/null; then
                PKG="dnf"
            elif command -v yum &>/dev/null; then
                PKG="yum"
            fi
            ok "${PRETTY_NAME} detected — using ${PKG}"
            ;;
        *)
            err "Unsupported distribution: ${ID}"
            info "This installer supports macOS (brew), Debian/Ubuntu (apt), and RHEL/Fedora (dnf)."
            exit 1
            ;;
    esac
else
    err "Unable to detect operating system"
    exit 1
fi

###############################################################################
# Install functions
###############################################################################

# ── Azure CLI ────────────────────────────────────────────────────────────────
install_azure_cli() {
    header "Installing Azure CLI"
    case "${OS}" in
        macos)
            brew install azure-cli
            ;;
        debian)
            info "Adding Microsoft package repository …"
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl apt-transport-https lsb-release gnupg
            curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null
            AZ_REPO=$(lsb_release -cs)
            echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${AZ_REPO} main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
            sudo apt-get update -qq
            sudo apt-get install -y -qq azure-cli
            ;;
        rhel)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
            sudo "${PKG}" install -y azure-cli
            ;;
    esac
}

# ── Terraform ────────────────────────────────────────────────────────────────
install_terraform() {
    header "Installing Terraform"
    case "${OS}" in
        macos)
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
            ;;
        debian)
            info "Adding HashiCorp package repository …"
            sudo apt-get update -qq
            sudo apt-get install -y -qq gnupg software-properties-common
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update -qq
            sudo apt-get install -y -qq terraform
            ;;
        rhel)
            sudo "${PKG}" install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo "${PKG}" install -y terraform
            ;;
    esac
}

# ── jq ───────────────────────────────────────────────────────────────────────
install_jq() {
    header "Installing jq"
    case "${OS}" in
        macos)  brew install jq ;;
        debian) sudo apt-get install -y -qq jq ;;
        rhel)   sudo "${PKG}" install -y jq ;;
    esac
}

###############################################################################
# Main installation flow
###############################################################################

INSTALLED=0
SKIPPED=0
FAILED=0

install_if_missing() {
    local cmd="$1"
    local display_name="$2"
    local install_fn="$3"

    header "Checking ${display_name}"

    if command -v "${cmd}" &>/dev/null; then
        ok "${display_name} is already installed"
        return
    fi

    warn "${display_name} is not installed"

    if confirm "Install ${display_name}?"; then
        if ${install_fn}; then
            # Verify the install worked
            if command -v "${cmd}" &>/dev/null; then
                ok "${display_name} installed successfully"
                ((INSTALLED+=1))
            else
                err "${display_name} installation completed but command not found on PATH"
                ((FAILED+=1))
            fi
        else
            err "${display_name} installation failed"
            ((FAILED+=1))
        fi
    else
        info "Skipping ${display_name}"
        ((SKIPPED+=1))
    fi
}

install_if_missing az       "Azure CLI"  install_azure_cli
install_if_missing terraform "Terraform"  install_terraform
install_if_missing jq        "jq"        install_jq

###############################################################################
# Post-install verification
###############################################################################
header "Verification"

verify_tool() {
    local cmd="$1"
    local label="$2"
    if command -v "${cmd}" &>/dev/null; then
        local ver
        case "${cmd}" in
            az)        ver=$(az version --output json 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo "unknown") ;;
            terraform) ver=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown") ;;
            jq)        ver=$(jq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown") ;;
            *)         ver="present" ;;
        esac
        ok "${label} ${ver}"
    else
        err "${label} — not found"
    fi
}

verify_tool az        "Azure CLI"
verify_tool terraform "Terraform"
verify_tool jq        "jq"

###############################################################################
# Summary
###############################################################################
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  Installation Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "  ${PASS} Installed: ${INSTALLED}"
echo -e "  ${WARN} Skipped:   ${SKIPPED}"
echo -e "  ${FAIL} Failed:    ${FAILED}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"

if (( FAILED > 0 )); then
    echo -e "\n${RED}${BOLD}Some installations failed. Check the output above.${NC}"
    exit 1
fi

if ! command -v az &>/dev/null; then
    info "Next step: install Azure CLI, then run: az login"
else
    info "Next step: run az login (if not already logged in)"
fi

info "Then run: ./check-prerequisites.sh to validate everything"
exit 0
