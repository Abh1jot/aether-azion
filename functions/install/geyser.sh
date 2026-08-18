#!/bin/bash
# functions/install/geyser.sh
#
# Installs GeyserMC + Floodgate for Java Edition servers so Bedrock clients can connect.
#
# ─── Correct two-boot setup flow ──────────────────────────────────────────────
#
#  INSTALL (happens once, right after server.jar download):
#    [1/3] Download Geyser-Spigot.jar  → plugins/
#    [2/3] Download floodgate-spigot.jar → plugins/
#    [3/3] Write pre-configured plugins/Geyser-Spigot/config.yml
#
#  BOOT 1 (normal server start after install):
#    Server loads → Floodgate generates plugins/floodgate/key.pem automatically
#    geyser_sync_keys() runs on next boot, so user just needs to restart once.
#
#  BOOT 2 (first restart after install):
#    geyser_sync_keys() copies plugins/floodgate/key.pem → plugins/Geyser-Spigot/key.pem
#    Geyser is now fully configured. Bedrock players can connect.
#
# No background server start needed. No timeout risk. Clean and simple.
# ──────────────────────────────────────────────────────────────────────────────

GEYSER_MIN_SUPPORTED_MAJOR=1
GEYSER_MIN_SUPPORTED_MINOR=16

function _geyser_parse_version {
    local ver="$1"
    GEYSER_VER_MAJOR=$(echo "$ver" | cut -d. -f1)
    GEYSER_VER_MINOR=$(echo "$ver" | cut -d. -f2)
    GEYSER_VER_PATCH=$(echo "$ver" | cut -d. -f3)
    GEYSER_VER_MAJOR=${GEYSER_VER_MAJOR:-0}
    GEYSER_VER_MINOR=${GEYSER_VER_MINOR:-0}
    GEYSER_VER_PATCH=${GEYSER_VER_PATCH:-0}
}

function geyser_version_supported {
    local ver="$1"
    # 26.x / future versioning (e.g. "26.1") — always supported
    if echo "$ver" | grep -qE '^[2-9][0-9]+\.'; then
        return 0
    fi
    _geyser_parse_version "$ver"
    if [ "$GEYSER_VER_MAJOR" -gt "$GEYSER_MIN_SUPPORTED_MAJOR" ]; then
        return 0
    elif [ "$GEYSER_VER_MAJOR" -eq "$GEYSER_MIN_SUPPORTED_MAJOR" ] && \
         [ "$GEYSER_VER_MINOR" -ge "$GEYSER_MIN_SUPPORTED_MINOR" ]; then
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# ask_geyser <mc-version>
# Prompt the user to enable GeyserMC + Floodgate.
# Sets GEYSER_ENABLED=1 if yes, 0 if no/unsupported.
# ─────────────────────────────────────────────────────────────────────────────
function ask_geyser {
    local mc_version="$1"

    if ! geyser_version_supported "$mc_version"; then
        printout warn "GeyserMC requires Minecraft 1.16+. Skipping for $mc_version."
        GEYSER_ENABLED=0
        return
    fi

    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m  🌉  GEYSER + FLOODGATE SUPPORT\e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;5;250m  GeyserMC lets Bedrock Edition players (PE, Xbox,\e[0m"
    echo -e "\e[38;5;250m  PS4, Switch, Windows 10/11) join your Java server.\e[0m"
    echo -e "\e[38;5;250m  Floodgate lets Bedrock players skip Java login.\e[0m"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[33m  ℹ  Plugins are installed now. After the first start\e[0m"
    echo -e "\e[33m     Floodgate generates its key — just restart once\e[0m"
    echo -e "\e[33m     and Geyser will be fully active.\e[0m"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[36m\e[1mEnable GeyserMC + Floodgate? \e[33m(y/n):\e[0m"
    read -p "$(echo -e '\e[33mYour choice:\e[0m') " geyser_choice
    geyser_choice=$(echo "$geyser_choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$geyser_choice" == y* ]]; then
        GEYSER_ENABLED=1
        printout success "Geyser + Floodgate will be installed."
    else
        GEYSER_ENABLED=0
        printout info "Skipping Geyser installation."
    fi
    echo -e "\e[1;36m \e[0m"
}

# ─────────────────────────────────────────────────────────────────────────────
# install_geyser
#
# Downloads Geyser-Spigot.jar + floodgate-spigot.jar and writes the pre-configured
# config.yml. Does NOT start any background server.
#
# How the key.pem flow works:
#   • Floodgate generates plugins/floodgate/key.pem on its FIRST server start
#   • geyser_sync_keys() (called every boot in launch.sh) copies it to
#     plugins/Geyser-Spigot/key.pem on the NEXT restart
#   • So: Boot 1 → key generated. Restart → Geyser fully active.
# ─────────────────────────────────────────────────────────────────────────────
function install_geyser {
    local plugins_dir="$HOME/plugins"
    local geyser_dir="$plugins_dir/Geyser-Spigot"
    local floodgate_dir="$plugins_dir/floodgate"
    local geyser_jar="$plugins_dir/Geyser-Spigot.jar"
    local floodgate_jar="$plugins_dir/floodgate-spigot.jar"

    mkdir -p "$geyser_dir" "$floodgate_dir"

    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m  🌉  Installing GeyserMC + Floodgate\e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;36m \e[0m"

    # ── Step 1: Download Geyser-Spigot ────────────────────────────────────────
    printout info "[ 1/3 ] ⬇  Downloading Geyser-Spigot.jar..."
    if ! curl -# -L \
        "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" \
        -o "$geyser_jar"; then
        printout error "Failed to download Geyser-Spigot.jar. Check your internet connection."
        GEYSER_ENABLED=0
        return 1
    fi
    local geyser_size
    geyser_size=$(stat -c%s "$geyser_jar" 2>/dev/null || stat -f%z "$geyser_jar" 2>/dev/null)
    printout success "Geyser-Spigot.jar downloaded ($(printf '%.1f MB' $((geyser_size / 1000000))))"

    # ── Step 2: Download Floodgate-Spigot ─────────────────────────────────────
    printout info "[ 2/3 ] ⬇  Downloading floodgate-spigot.jar..."
    if ! curl -# -L \
        "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" \
        -o "$floodgate_jar"; then
        printout error "Failed to download floodgate-spigot.jar. Check your internet connection."
        GEYSER_ENABLED=0
        return 1
    fi
    local floodgate_size
    floodgate_size=$(stat -c%s "$floodgate_jar" 2>/dev/null || stat -f%z "$floodgate_jar" 2>/dev/null)
    printout success "floodgate-spigot.jar downloaded ($(printf '%.1f MB' $((floodgate_size / 1000000))))"

    # ── Step 3: Write pre-configured Geyser config ────────────────────────────
    printout info "[ 3/3 ] ⚙  Writing Geyser config (port: $SERVER_PORT, auth-type: floodgate)..."
    _write_geyser_config "$geyser_dir/config.yml"
    printout success "Geyser config written"

    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    printout success "✅ GeyserMC + Floodgate plugins installed!"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;5;250m  ┌─ What happens next ──────────────────────────────┐\e[0m"
    echo -e "\e[38;5;250m  │  Boot 1 (starting now):                          │\e[0m"
    echo -e "\e[38;5;250m  │    Floodgate generates its encryption key.pem    │\e[0m"
    echo -e "\e[38;5;250m  │                                                  │\e[0m"
    echo -e "\e[38;5;250m  │  Restart once after the server fully loads:      │\e[0m"
    echo -e "\e[38;5;250m  │    key.pem is auto-copied to Geyser              │\e[0m"
    echo -e "\e[38;5;250m  │    Bedrock players can connect on port \e[92m$SERVER_PORT\e[38;5;250m  │\e[0m"
    echo -e "\e[38;5;250m  └──────────────────────────────────────────────────┘\e[0m"
    echo -e "\e[1;36m \e[0m"
}

# ─────────────────────────────────────────────────────────────────────────────
# geyser_sync_keys
#
# Called on every boot (in launch.sh). Safe no-op if Geyser is not installed.
# Once Floodgate has generated its key.pem on first boot, this copies it to
# Geyser on the next restart so Bedrock auth works.
# ─────────────────────────────────────────────────────────────────────────────
function geyser_sync_keys {
    local floodgate_key="$HOME/plugins/floodgate/key.pem"
    local geyser_key="$HOME/plugins/Geyser-Spigot/key.pem"
    local geyser_jar="$HOME/plugins/Geyser-Spigot.jar"

    # Only act if Geyser is installed, Floodgate has generated a key,
    # and it hasn't been copied yet (or was updated)
    if [ ! -f "$geyser_jar" ]; then
        return  # Geyser not installed — nothing to do
    fi

    if [ ! -f "$floodgate_key" ]; then
        return  # Floodgate hasn't generated the key yet (server hasn't started once)
    fi

    # Copy if Geyser key is missing OR Floodgate key is newer
    if [ ! -f "$geyser_key" ] || [ "$floodgate_key" -nt "$geyser_key" ]; then
        printout info "🔐 Syncing Floodgate key.pem → Geyser-Spigot..."
        mkdir -p "$HOME/plugins/Geyser-Spigot"
        cp "$floodgate_key" "$geyser_key"
        printout success "Keys synced — Bedrock players can now connect on port $SERVER_PORT (UDP)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# _write_geyser_config <path>
# Write a pre-configured Geyser config.yml for Pterodactyl / Azion single-port
# ─────────────────────────────────────────────────────────────────────────────
function _write_geyser_config {
    local config_path="$1"
    cat > "$config_path" << GEYSER_EOF
# Geyser-Spigot configuration — pre-configured by aether-azion
# Reference: https://wiki.geysermc.org/geyser/understanding-the-config/
#
# Minimal config — Geyser uses safe defaults for anything not listed here.
# DO NOT set uuid: under metrics — Geyser auto-generates it on first start.

bedrock:
  address: 0.0.0.0
  # Same port number as Java, different protocol (UDP). Safe on Pterodactyl.
  port: ${SERVER_PORT}
  clone-remote-port: false
  motd1: "Powered by aether-azion"
  motd2: "Java + Bedrock"
  server-name: "GeyserMC"
  compression-level: 6
  enable-proxy-protocol: false

java:
  # Loopback — Geyser and the Java server share the same container
  address: 127.0.0.1
  port: ${SERVER_PORT}

# Bedrock players join without a Java account via Floodgate
auth-type: floodgate

# Extra auth timeout for slower free-tier connections (ms)
pending-authentication-timeout: 120

# Disable telemetry
metrics:
  enabled: false
GEYSER_EOF
}
