#!/usr/bin/env bash
# ==============================================================================
# Dokploy Local CLI Installer (for all Linux distributions)
# ==============================================================================
#
# CONFIGURATION VARIABLE: Primary Command Word
# Change this variable to customize the default command word:
#   "dok"     -> 'dok start', 'dok stop'
#   "dk"      -> 'dk start', 'dk stop'
#   "dokploy" -> 'dokploy start', 'dokploy stop'
#
# You can also pass it as an argument:
#   ./install.sh dk
#   ./install.sh dok
# Or set CLI_NAME before running:
#   CLI_NAME=dk ./install.sh
# ==============================================================================
CLI_NAME="${CLI_NAME:-dok}"

set -e

# Terminal colors
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  BOLD=""
  DIM=""
  GREEN=""
  YELLOW=""
  RED=""
  CYAN=""
  NC=""
fi

SRC_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)"
SOURCE_BIN="$SRC_DIR/dok"

# GitHub repository details for remote curl installation:
GITHUB_REPO="${GITHUB_REPO:-showayebDev/dokploy-local-cli}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_RAW_URL="${GITHUB_RAW_BASE:-https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH}"

# Target installation directory
if [ "$(id -u)" -eq 0 ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dokploy-cli"
CONFIG_FILE="$CONFIG_DIR/config"

# Common aliases so both 'dok' and 'dk' work out of the box
DEFAULT_ALIASES=("dok" "dk" "dokploy")

# ------------------------------------------------------------------------------
# Uninstall Routine
# ------------------------------------------------------------------------------
uninstall() {
  echo -e "${YELLOW}Uninstalling Dokploy Local CLI...${NC}"

  # Remove binaries and symlinks
  for name in "${DEFAULT_ALIASES[@]}" "$CLI_NAME"; do
    if [ -f "$INSTALL_DIR/$name" ] || [ -L "$INSTALL_DIR/$name" ]; then
      echo -e "  Removing: $INSTALL_DIR/$name"
      rm -f "$INSTALL_DIR/$name"
    fi
  done

  # Remove completions from shell configuration files
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
      sed -i '/# >>> dokploy-cli autocompletion >>>/,/# <<< dokploy-cli autocompletion <<</d' "$rc" 2>/dev/null || true
    fi
  done

  # Remove config
  if [ -d "$CONFIG_DIR" ]; then
    echo -e "  Removing configuration: $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
  fi

  echo -e "${GREEN}✔${NC} Dokploy Local CLI has been completely uninstalled."
  exit 0
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
INTERACTIVE=true
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall|-u)
      uninstall
      ;;
    --install-dokploy)
      INSTALL_DOKPLOY=true
      INTERACTIVE=false
      ;;
    --name|-n)
      shift
      CLI_NAME="$1"
      INTERACTIVE=false
      ;;
    -y|--yes|--non-interactive)
      INTERACTIVE=false
      ;;
    -h|--help)
      cat << EOF
Dokploy CLI Installer

Usage:
  ./install.sh [options] [command_name]

Options:
  --install-dokploy         Install Dokploy locally and disable boot auto-startup
  --name <name>, -n <name>  Set primary command name (e.g. dok, dk)
  --uninstall, -u           Remove Dokploy CLI and shell completions
  -y, --yes                 Non-interactive mode (use defaults)

Examples:
  ./install.sh                   # Interactive menu (or default 'dok')
  ./install.sh dk                # Install with 'dk' as primary command
  ./install.sh --install-dokploy # Install CLI and install Dokploy with auto-boot disabled
  ./install.sh --uninstall      # Remove Dokploy CLI and shell completions
EOF
      exit 0
      ;;
    *)
      if [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        CLI_NAME="$1"
        INTERACTIVE=false
      fi
      ;;
  esac
  shift
done

# If running in interactive terminal without explicit name argument, prompt user
if [ "$INTERACTIVE" = true ] && [ -t 0 ] && [ -t 1 ]; then
  echo -e "${BOLD}Dokploy Local CLI Installation${NC}"
  echo -e "Choose your preferred primary command word / prefix:\n"
  echo -e "  ${BOLD}1)${NC} ${CYAN}dok${NC}      (e.g., dok start, dok stop, dok status)  ${GREEN}[Recommended]${NC}"
  echo -e "  ${BOLD}2)${NC} ${CYAN}dk${NC}       (e.g., dk start, dk stop, dk status)    ${GREEN}[Ultra-short]${NC}"
  echo -e "  ${BOLD}3)${NC} ${CYAN}dokploy${NC}  (e.g., dokploy start, dokploy stop)"
  echo -e "  ${BOLD}4)${NC} Custom word"
  echo ""
  read -r -p "Enter choice [1-4] (default: 1): " choice

  case "$choice" in
    2) CLI_NAME="dk" ;;
    3) CLI_NAME="dokploy" ;;
    4)
      read -r -p "Enter your custom command word (e.g. 'dp'): " custom_word
      if [ -n "$custom_word" ]; then
        CLI_NAME="$custom_word"
      fi
      ;;
    *) CLI_NAME="dok" ;;
  esac
fi

echo -e "\n${BOLD}==> Installing Dokploy CLI as '${CYAN}${CLI_NAME}${NC}'...${NC}"

# Ensure target directory exists
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_DIR/$CLI_NAME"

# Check if running locally or remotely via curl
if [ -f "$SOURCE_BIN" ]; then
  echo -e "  Installing from local source: ${CYAN}$SOURCE_BIN${NC}"
  cp -f "$SOURCE_BIN" "$INSTALL_DIR/$CLI_NAME"
else
  echo -e "  Downloading '${CLI_NAME}' binary from GitHub (${CYAN}${GITHUB_REPO}${NC})..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$GITHUB_RAW_URL/dok" -o "$INSTALL_DIR/$CLI_NAME"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$INSTALL_DIR/$CLI_NAME" "$GITHUB_RAW_URL/dok"
  else
    echo -e "${RED}Error:${NC} Neither 'curl' nor 'wget' was found to download the CLI." >&2
    exit 1
  fi
fi

chmod +x "$INSTALL_DIR/$CLI_NAME"

# Create symlinks for common aliases so both 'dok' and 'dk' work seamlessly
echo -e "  Creating convenience aliases..."
for alias_name in "${DEFAULT_ALIASES[@]}"; do
  if [ "$alias_name" != "$CLI_NAME" ]; then
    # Remove previous alias or file to cleanly link
    rm -f "$INSTALL_DIR/$alias_name"
    ln -sf "$INSTALL_DIR/$CLI_NAME" "$INSTALL_DIR/$alias_name"
    echo -e "    ${GREEN}->${NC} Alias '${CYAN}$alias_name${NC}' linked to '$CLI_NAME'"
  fi
done

# Save configuration
mkdir -p "$CONFIG_DIR"
cat << EOF > "$CONFIG_FILE"
# Dokploy Local CLI Configuration
CLI_NAME="$CLI_NAME"
DOKPLOY_PORT=3000
DOKPLOY_NETWORK="dokploy-network"
STATE_DIR="$HOME/.cache/dokploy"
EOF
echo -e "  Configuration saved to: ${CYAN}$CONFIG_FILE${NC}"

# ------------------------------------------------------------------------------
# PATH Verification & Export
# ------------------------------------------------------------------------------
add_to_path_if_needed() {
  local target_file="$1"
  if [ -f "$target_file" ]; then
    if ! grep -q "$INSTALL_DIR" "$target_file" 2>/dev/null; then
      echo -e "  Adding $INSTALL_DIR to PATH in: $target_file"
      cat << EOF >> "$target_file"

# Dokploy Local CLI PATH
export PATH="$INSTALL_DIR:\$PATH"
EOF
    fi
  fi
}

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo -e "  ${YELLOW}!${NC} $INSTALL_DIR is not currently in your PATH."
    add_to_path_if_needed "$HOME/.bashrc"
    add_to_path_if_needed "$HOME/.zshrc"
    add_to_path_if_needed "$HOME/.profile"
    ;;
esac

# ------------------------------------------------------------------------------
# Shell Auto-Completion Setup
# ------------------------------------------------------------------------------
setup_completion() {
  local shell_rc="$1"
  local shell_type="$2"

  if [ -f "$shell_rc" ]; then
    # Clean previous block if present
    sed -i '/# >>> dokploy-cli autocompletion >>>/,/# <<< dokploy-cli autocompletion <<</d' "$shell_rc" 2>/dev/null || true

    echo -e "  Configuring tab completion in: ${CYAN}$shell_rc${NC}"
    cat << EOF >> "$shell_rc"

# >>> dokploy-cli autocompletion >>>
if command -v $CLI_NAME >/dev/null 2>&1; then
  eval "\$($CLI_NAME completion $shell_type)"
elif command -v dok >/dev/null 2>&1; then
  eval "\$(dok completion $shell_type)"
elif command -v dk >/dev/null 2>&1; then
  eval "\$(dk completion $shell_type)"
fi
# <<< dokploy-cli autocompletion <<<
EOF
  fi
}

setup_completion "$HOME/.bashrc" "bash"
setup_completion "$HOME/.zshrc" "zsh"

# If root, install system-wide completion
if [ "$(id -u)" -eq 0 ]; then
  if [ -d "/etc/bash_completion.d" ]; then
    "$INSTALL_DIR/$CLI_NAME" completion bash > /etc/bash_completion.d/dokploy
    echo -e "  Installed system-wide bash completion to /etc/bash_completion.d/dokploy"
  fi
fi

# ------------------------------------------------------------------------------
# Finish & Quick Start
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}✔ Installation successful!${NC}\n"
echo -e "You can now run commands using either ${BOLD}${CYAN}${CLI_NAME}${NC} or any alias:"
echo -e "  ${CYAN}${CLI_NAME} start${NC}         # Start Dokploy core + Traefik"
echo -e "  ${CYAN}${CLI_NAME} start --core${NC}  # Start only panel & database"
echo -e "  ${CYAN}${CLI_NAME} status${NC}        # Check running services & URLs"
echo -e "  ${CYAN}${CLI_NAME} logs panel -f${NC} # View live panel logs"
echo -e "  ${CYAN}${CLI_NAME} open${NC}          # Open dashboard in browser"
echo -e "  ${CYAN}${CLI_NAME} stop${NC}          # Stop services & free all memory"
echo ""
echo -e "Both ${BOLD}${CYAN}dok start${NC} and ${BOLD}${CYAN}dk start${NC} are active and ready!"
echo -e "${DIM}To activate tab completion in your current terminal session, run:${NC}"
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/usr/bin/zsh" ] || [ "$SHELL" = "/bin/zsh" ]; then
  echo -e "  ${BOLD}source ~/.zshrc${NC}"
else
  echo -e "  ${BOLD}source ~/.bashrc${NC}"
fi

# ------------------------------------------------------------------------------
# Optional Dokploy Local Setup
# ------------------------------------------------------------------------------
if [ "${INSTALL_DOKPLOY:-false}" = true ]; then
  echo -e "\n${BOLD}======================================================${NC}"
  echo -e "${BOLD} Installing Dokploy for Local Development...${NC}"
  echo -e "${BOLD}======================================================${NC}"
  "$INSTALL_DIR/$CLI_NAME" install-dokploy
fi
