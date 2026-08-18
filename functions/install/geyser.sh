#!/bin/bash
# functions/install/geyser.sh
# Installs GeyserMC + Floodgate for Java Edition servers so Bedrock clients can connect.
#
# Correct setup order (verified against GeyserMC docs):
#   1. Download Geyser-Spigot.jar + floodgate-spigot.jar → plugins/
#   2. Pre-write plugins/Geyser-Spigot/config.yml (port, auth-type: floodgate)
#   3. Start server once in background → Floodgate generates key.pem
#   4. Wait, monitor logs, copy key.pem → plugins/Geyser-Spigot/
#   5. Kill background server → caller restarts normally (Geyser now fully configured)

# Versions of Minecraft that Geyser 2.x supports as backend (Java server)
# Geyser supports 1.16+ Java servers
GEYSER_MIN_SUPPORTED_MAJOR=1
GEYSER_MIN_SUPPORTED_MINOR=16

# ─────────────────────────────────────────────
# Helper: parse a version like "1.21.4" into
# major (1), minor (21), patch (4)
# ─────────────────────────────────────────────
function _geyser_parse_version {
    local ver="$1"
    GEYSER_VER_MAJOR=$(echo "$ver" | cut -d. -f1)
    GEYSER_VER_MINOR=$(echo "$ver" | cut -d. -f2)
    GEYSER_VER_PATCH=$(echo "$ver" | cut -d. -f3)
    GEYSER_VER_MAJOR=${GEYSER_VER_MAJOR:-0}
    GEYSER_VER_MINOR=${GEYSER_VER_MINOR:-0}
    GEYSER_VER_PATCH=${GEYSER_VER_PATCH:-0}
}

# ─────────────────────────────────────────────
# Check if a given MC version is Geyser-compatible
# Returns 0 (true) if supported, 1 if not
# ─────────────────────────────────────────────
function geyser_version_supported {
    local ver="$1"

    # Handle 26.x / future naming (e.g. "26.1", "26.2") — always supported
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

# ─────────────────────────────────────────────
# Ask the user if they want Geyser support
# Sets GEYSER_ENABLED=1 if yes
# ─────────────────────────────────────────────
function ask_geyser {
    local mc_version="$1"

    # Skip silently if version not supported
    if ! geyser_version_supported "$mc_version"; then
        printout warn "GeyserMC is not supported for Minecraft $mc_version (requires 1.16+). Skipping."
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
    echo -e "\e[38;5;250m  Floodgate allows Bedrock players to skip Java login.\e[0m"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[33m  ⚠  This will briefly start your server in the background\e[0m"
    echo -e "\e[33m     to generate encryption keys, then restart it.\e[0m"
    echo -e "\e[1;36m \e[0m"
    echo -e "\e[36m\e[1mEnable GeyserMC + Floodgate? \e[33m(y/n):\e[0m"
    read -p "$(echo -e '\e[33mYour choice:\e[0m') " geyser_choice
    geyser_choice=$(echo "$geyser_choice" | tr '[:upper:]' '[:lower:]')

    if [[ "$geyser_choice" == y* ]]; then
        GEYSER_ENABLED=1
        printout success "Geyser + Floodgate will be installed after the server jar is ready."
    else
        GEYSER_ENABLED=0
        printout info "Skipping Geyser installation."
    fi
    echo -e "\e[1;36m \e[0m"
}

# ─────────────────────────────────────────────
# Main Geyser installer
# Call AFTER server.jar is in place and eula.txt is accepted
# ─────────────────────────────────────────────
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

    # ── Step 1: Download Geyser-Spigot ───────────────────────────────────────
    printout info "[ 1/5 ] ⬇  Downloading Geyser-Spigot.jar..."
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

    # ── Step 2: Download Floodgate-Spigot ────────────────────────────────────
    printout info "[ 2/5 ] ⬇  Downloading floodgate-spigot.jar..."
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

    # ── Step 3: Write pre-configured Geyser config ───────────────────────────
    printout info "[ 3/5 ] ⚙  Writing Geyser config (port: $SERVER_PORT, auth-type: floodgate)..."
    _write_geyser_config "$geyser_dir/config.yml"
    printout success "Geyser config written"

    # ── Step 4: First-boot in background to generate Floodgate key.pem ───────
    printout info "[ 4/5 ] 🔑  Starting server briefly in background to generate Floodgate keys..."
    printout info "        This may take up to 60 seconds. Please wait..."
    echo -e "\e[1;36m \e[0m"

    # Make sure eula is already accepted before background start
    if [ ! -f "eula.txt" ]; then
        echo "eula=true" > eula.txt
    fi

    source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null || true

    # Start Java server in background, redirect its output to a log
    local bg_log="$HOME/system/geyser-keygen.log"
    mkdir -p "$HOME/system"
    java -Dterminal.jline=false -Dterminal.ansi=true \
        -Xms128M -Xmx512M \
        -jar server.jar nogui > "$bg_log" 2>&1 &
    local BG_PID=$!

    # Show a spinner while waiting for key.pem
    local waited=0
    local max_wait=90   # seconds before we give up
    local key_found=0
    local spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_i=0

    while [ $waited -lt $max_wait ]; do
        local spin="${spinner_chars[$spin_i]}"
        spin_i=$(( (spin_i + 1) % 10 ))

        # Show latest status from the background log
        local last_line
        last_line=$(tail -n1 "$bg_log" 2>/dev/null | \
            sed 's/\x1B\[[0-9;]*[mK]//g' | \
            cut -c1-70 || true)

        printf "\r\e[33m  %s  %s\e[0m\e[K" "$spin" "$last_line"

        # Check if key.pem has appeared
        if [ -f "$floodgate_dir/key.pem" ]; then
            key_found=1
            break
        fi

        sleep 1
        waited=$((waited + 1))
    done

    printf "\r\e[K"   # clear spinner line

    # Stop the background server gracefully
    if kill -0 $BG_PID 2>/dev/null; then
        printout info "        Sending stop signal to background server..."
        # Try graceful stop via stdin first
        kill -SIGTERM $BG_PID 2>/dev/null || true
        # Wait up to 15s for it to die
        local stop_wait=0
        while kill -0 $BG_PID 2>/dev/null && [ $stop_wait -lt 15 ]; do
            sleep 1
            stop_wait=$((stop_wait + 1))
        done
        # Force kill if still running
        kill -9 $BG_PID 2>/dev/null || true
        wait $BG_PID 2>/dev/null || true
    fi

    if [ $key_found -eq 0 ]; then
        printout warn "Floodgate key.pem was not generated within ${max_wait}s."
        printout warn "Geyser will be installed but key linking will happen on next restart."
        printout info "You can manually copy plugins/floodgate/key.pem → plugins/Geyser-Spigot/key.pem"
    else
        # ── Step 5: Copy key.pem ─────────────────────────────────────────────
        printout info "[ 5/5 ] 🔐  Linking Floodgate key.pem → Geyser-Spigot..."
        cp "$floodgate_dir/key.pem" "$geyser_dir/key.pem"
        printout success "key.pem copied. Geyser is now fully configured!"
    fi

    echo -e "\e[1;36m \e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    printout success "✅ GeyserMC + Floodgate installation complete!"
    echo -e "\e[38;5;250m  Bedrock players can now connect on port \e[92m$SERVER_PORT\e[38;5;250m (UDP)\e[0m"
    echo -e "\e[38;5;250m  Java players still connect on port \e[92m$SERVER_PORT\e[38;5;250m (TCP)\e[0m"
    echo -e "\e[38;2;195;144;230m\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;36m \e[0m"

    printout info "Restarting server with GeyserMC active..."
    sleep 2
}

# ─────────────────────────────────────────────
# On every subsequent boot: check if Floodgate
# generated a new key.pem and copy it to Geyser
# (handles the fallback case from above)
# ─────────────────────────────────────────────
function geyser_sync_keys {
    local floodgate_key="$HOME/plugins/floodgate/key.pem"
    local geyser_key="$HOME/plugins/Geyser-Spigot/key.pem"

    # Only act if Geyser is installed but key not yet synced
    if [ -f "$HOME/plugins/Geyser-Spigot.jar" ] && \
       [ -f "$floodgate_key" ] && \
       [ ! -f "$geyser_key" ]; then
        printout info "🔐 Syncing Floodgate key.pem → Geyser-Spigot (first time)..."
        mkdir -p "$HOME/plugins/Geyser-Spigot"
        cp "$floodgate_key" "$geyser_key"
        printout success "Keys synced. Bedrock connections are now fully encrypted."
    fi
}

# ─────────────────────────────────────────────
# Write a pre-configured Geyser config.yml
# All critical fields for Pterodactyl / Azion
# ─────────────────────────────────────────────
function _write_geyser_config {
    local config_path="$1"
    cat > "$config_path" << GEYSER_EOF
# Geyser-Spigot configuration — pre-configured by aether-azion
# Full reference: https://wiki.geysermc.org/geyser/understanding-the-config/

bedrock:
  # Bind to all interfaces (required for Pterodactyl containers)
  address: 0.0.0.0
  # UDP port Bedrock clients will connect to.
  # On Pterodactyl with a single allocation, UDP and TCP share the same port
  # number but are completely separate protocols — this is safe and correct.
  port: ${SERVER_PORT}
  # Do NOT enable clone-remote-port when setting the port explicitly above
  clone-remote-port: false
  motd1: "GeyserMC"
  motd2: "Powered by aether-azion"
  # Display name shown in the Bedrock server list
  server-name: "Geyser"
  compression-level: 6
  enable-proxy-protocol: false

java:
  # The Java server Geyser bridges to (loopback — same container)
  address: 127.0.0.1
  port: ${SERVER_PORT}

# floodgate: allows Bedrock players to join without a Java account
auth-type: floodgate

# Recommended for shared / free-tier hosting
cache-images: 0
allow-third-party-capes: true
allow-third-party-ears: false
show-cooldown: title
show-credits: true
emote-offhand-workaround: "no-emotes"

# Forward player IPs correctly inside the container
use-adapters: true

metrics:
  enabled: false
  uuid: default
GEYSER_EOF
}
