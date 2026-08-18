#!/bin/bash

function port_assign {
    cat <<EOF >server.properties
motd=A Minecraft Server
server-port=$SERVER_PORT
query.port=$SERVER_PORT
EOF
}

function optimize_server {
    if [ ! -d "$HOME/plugins" ]; then
        mkdir -p $HOME/plugins
    fi
    if [ "$OPTIMIZE_SERVER" != "1" ]; then
        return
    fi
    printout info "Optimizing server..."
    curl -o $HOME/plugins/Hibernate.jar https://files.aether.loners.software/files/Hibernate-2.1.0.jar
}

function forced_motd {
    printout info "Updating MOTD, this feature may not work..."
    sed -i "s|^motd=.*|motd=$(printf '%s' "Join $HOSTING_NAME for free server discord.gg/$DISCORD_LINK" | sed 's/[&/\]/\\&/g')|g" server.properties
}

function forced_motd_bedrock {
    printout info "Updating MOTD, this feature may not work..."
    sed -i 's|^server-name=.*|server-name="Join '"$HOSTING_NAME"' for free server discord.gg/'"$DISCORD_LINK"'"|g' server.properties
}

# ─────────────────────────────────────────────────────────────────────────────
# auto_java_for_mc <mc-version>
#
# Maps a Minecraft version string (e.g. "1.21.4", "1.8.8", "26.2") to the
# MINIMUM Java version required by that release and ensures JAVA_VERSION is
# at least that value.
#
# Minecraft ↔ Java minimum requirements:
#   1.8  – 1.16.x  →  Java 11  (8 works but 11 is the stable modern minimum)
#   1.17 – 1.17.1  →  Java 17  (Mojang raised the minimum to Java 16; use 17)
#   1.18 – 1.20.4  →  Java 17  (official minimum)
#   1.20.5+        →  Java 21  (official minimum — Mojang mandate)
#   1.21+          →  Java 21
#   26.x+          →  Java 21  (new versioning scheme, still Java 21 minimum)
#
# If JAVA_VERSION is already set HIGHER than the required minimum we keep it
# (e.g. user chose Java 25 for a 1.21 server — that's fine).
# If JAVA_VERSION is set LOWER than required, we bump it up and warn.
# ─────────────────────────────────────────────────────────────────────────────
function auto_java_for_mc {
    local mc_ver="$1"
    local required

    # Parse version components
    local major minor patch
    major=$(echo "$mc_ver" | cut -d. -f1)
    minor=$(echo "$mc_ver" | cut -d. -f2)
    patch=$(echo "$mc_ver" | cut -d. -f3)
    major=${major:-1}
    minor=${minor:-0}
    patch=${patch:-0}

    # Determine required Java version
    if [ "$major" -ge 26 ] 2>/dev/null; then
        # New Mojang versioning (26.x, 27.x …) — Java 21+
        required=21
    elif [ "$major" -eq 1 ] 2>/dev/null; then
        if [ "$minor" -ge 21 ]; then
            required=21                          # 1.21+
        elif [ "$minor" -eq 20 ]; then
            if [ "$patch" -ge 5 ] 2>/dev/null; then
                required=21                      # 1.20.5, 1.20.6 — Mojang mandate
            else
                required=17                      # 1.20, 1.20.1, 1.20.2, 1.20.4
            fi
        elif [ "$minor" -ge 18 ]; then
            required=17                          # 1.18.x, 1.19.x
        elif [ "$minor" -eq 17 ]; then
            required=17                          # 1.17, 1.17.1 (Mojang min is 16; use 17)
        else
            required=11                          # 1.8 – 1.16.x (Java 8 works but 11 is better)
        fi
    else
        required=21  # Unknown/future versioning — default to 21
    fi

    # If JAVA_VERSION is not set at all, just use the required version
    if [ -z "$JAVA_VERSION" ]; then
        export JAVA_VERSION="$required"
        printout info "☕ Java version auto-set to $JAVA_VERSION for Minecraft $mc_ver"
        return
    fi

    # Compare: bump up if currently set version is too low
    if [ "$JAVA_VERSION" -lt "$required" ] 2>/dev/null; then
        printout warn "⚠  Java $JAVA_VERSION is too old for Minecraft $mc_ver (minimum required: Java $required)"
        printout warn "   Automatically upgrading to Java $required to prevent launch failure."
        export JAVA_VERSION="$required"
    else
        printout info "☕ Java $JAVA_VERSION selected for Minecraft $mc_ver (minimum required: $required) ✓"
    fi
}