#!/bin/bash
# check_existing_install.sh
# Detects pre-existing Minecraft server installations (e.g. a server originally
# set up with the stock Pterodactyl Paper egg) and auto-writes system/multiegg.yml
# so the egg picks it up without needing a full reinstall.
#
# Detection priority order:
#   1. server.jar + plugins/ directory  → most likely Paper/Spigot/Bukkit
#   2. server.jar + server.properties   → generic Java server
#   3. server.jar alone                 → unknown Java server, try to ID by manifest
#   4. bedrock_server binary            → Bedrock vanilla
#   5. BungeeCord/Velocity/Waterfall jars

function check_existing_install {
    # If system config already exists, nothing to do
    if [ -f "system/multiegg.yml" ]; then
        return
    fi

    # ── Bedrock detection ────────────────────────────────────────────────────
    if [ -f "bedrock_server" ]; then
        printout info "╔══════════════════════════════════════════════════╗"
        printout info "║  🔍  Existing Bedrock installation detected!    ║"
        printout info "╚══════════════════════════════════════════════════╝"
        printout info "Skipping setup wizard and resuming your existing server."
        mkdir -p system
        create_config "mc_bedrock_vanilla"
        clear
        display
        launchBedrockVanillaServer
        exit
    fi

    # ── Proxy detection (BungeeCord / Waterfall / Velocity) ─────────────────
    # Look for BungeeCord config or a jar that looks like a proxy
    if [ -f "config.yml" ] && grep -q "listeners:" config.yml 2>/dev/null; then
        _proxy_type="mc_proxy_bungeecord"
        if [ -f "velocity.toml" ]; then
            _proxy_type="mc_proxy_velocity"
        fi
        printout info "╔══════════════════════════════════════════════════╗"
        printout info "║  🔍  Existing proxy installation detected!      ║"
        printout info "╚══════════════════════════════════════════════════╝"
        printout info "Detected proxy type: $_proxy_type"
        printout info "Skipping setup wizard and resuming your existing server."
        mkdir -p system
        create_config "$_proxy_type"
        clear
        display
        launchProxyServer
        exit
    fi

    # ── Java server detection ────────────────────────────────────────────────
    if [ -f "server.jar" ]; then
        _detected_type="mc_java"   # fallback

        # Try to read the JAR manifest to identify the software
        _manifest=""
        if command -v unzip &>/dev/null; then
            _manifest=$(unzip -p server.jar META-INF/MANIFEST.MF 2>/dev/null || true)
        fi

        # Paper / Folia
        if echo "$_manifest" | grep -qi "paper\|folia"; then
            _detected_type="mc_java_paper"
        # Purpur
        elif echo "$_manifest" | grep -qi "purpur"; then
            _detected_type="mc_java_purpur"
        # Pufferfish
        elif echo "$_manifest" | grep -qi "pufferfish"; then
            _detected_type="mc_java_pufferfish"
        # Spigot / CraftBukkit — treat as Paper-compatible
        elif echo "$_manifest" | grep -qi "spigot\|craftbukkit\|bukkit"; then
            _detected_type="mc_java_paper"
        # Vanilla check — no "Main-Class" that matches known forks
        elif [ -f "server.properties" ] && [ ! -d "plugins" ]; then
            _detected_type="mc_java_vanilla"
        # plugins/ directory = almost certainly a Bukkit-fork
        elif [ -d "plugins" ]; then
            _detected_type="mc_java_paper"
        fi

        printout info "╔══════════════════════════════════════════════════╗"
        printout info "║  🔍  Existing Java server installation detected! ║"
        printout info "╚══════════════════════════════════════════════════╝"
        printout info "Detected software type: $_detected_type"
        printout info "Writing system config and resuming your existing server."
        printout info "Your data (worlds, plugins, configs) is UNTOUCHED."

        mkdir -p system
        create_config "$_detected_type"

        # Ensure server.properties has the right port/ip (Pterodactyl requirement)
        if [ -f "server.properties" ]; then
            sed -i "s/^server-ip=.*/server-ip=0.0.0.0/" server.properties 2>/dev/null || true
            sed -i "s/^server-port=.*/server-port=${SERVER_PORT}/" server.properties 2>/dev/null || true
        fi

        clear
        display
        # Sync Geyser keys in case Geyser is already installed
        geyser_sync_keys
        if [ "$_detected_type" = "mc_java_vanilla" ]; then
            launchVanillaServer
        else
            launchJavaServer
        fi
        exit
    fi
}
