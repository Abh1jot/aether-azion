#!/bin/bash
# aether-azion (fork of lonersoft/aether)
# Optimised for Minecraft free hosting on Azion Cloud
# Licensed under the MIT License
# Repo: https://github.com/Abh1jot/aether-azion

ARCH=$([[ "$(uname -m)" == "x86_64" ]] && printf "amd64" || printf "arm64")

# Get script directory — /functions lives here (baked into Docker image)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Self-update: pull latest scripts from GitHub on every boot ─────────────
# This means any push to https://github.com/Abh1jot/aether-azion takes effect
# on the next server restart without rebuilding the Docker image.
_AETHER_REPO="Abh1jot/aether-azion"
_UPDATE_TMP="/tmp/aether-update-$$"
echo -e "\e[38;5;250m[aether-azion] Checking for script updates...\e[0m"
if git clone --depth=1 --quiet \
       "https://github.com/${_AETHER_REPO}.git" "$_UPDATE_TMP" 2>/dev/null; then
    cp -r "$_UPDATE_TMP/functions/." "$SCRIPT_DIR/functions/"
    rm -rf "$_UPDATE_TMP"
    echo -e "\e[38;5;250m[aether-azion] Scripts up to date.\e[0m"
fi
# ──────────────────────────────────────────────────────────────────────────────

# Source all functions (sorted for deterministic load order)
for file in $(find "$SCRIPT_DIR/functions" -name "*.sh" -type f | sort); do
    source "$file"
done

####################################
#          Main Script             #
####################################
function main {
    # ── NEW: detect pre-existing Paper/Vanilla/Bedrock/proxy installs ──
    # This runs BEFORE check_config so migrated servers boot straight away.
    check_existing_install

    # Normal config-based routing (server already ran aether before)
    check_config

    # First-time setup wizard
    while true; do
        clear
        display
        mkdir -p system
        if [[ "$ENABLE_RULES" == "1" ]]; then
            rules
        fi
        echo -e "\e[36m🎮  Select the server type:\e[0m"
        echo -e "\e[32m1\e[0m) Minecraft: Java Edition\e[0m"
        echo -e "\e[32m2\e[0m) Minecraft: Bedrock Edition\e[0m"
        echo -e "\e[32m3\e[0m) Minecraft Proxies\e[0m"
        echo -e "\e[31m4\e[0m) Exit"
        read -p "$(echo -e '\e[33mYour choice:\e[0m') " type

        case $type in
        1)
            minecraft_menu
            ;;
        2)
            bedrock_menu
            ;;
        3)
            proxy_menu
            ;;
        4)
            exit 0
            ;;
        stop)
            exit 0
            ;;
        *)
            printout error "Invalid choice. Please try again."
            sleep 2
            ;;
        esac
    done
}

main
