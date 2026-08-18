#!/bin/bash

function postsetup_java {
    if [[ "$AUTOMATIC_UPDATING" == "1" ]]; then
        printout info "Checking for server jar updates... if this takes too long, disable automatic updating in the startup tab"

        # Hash server jar file
        if [ -z "${HASH}" ]; then
            HASH=$(sha256sum server.jar | awk '{print $1}')
        fi

        # Check if hash is set
        if [ -n "${HASH}" ]; then
            API_RESPONSE=$(curl --connect-timeout 4 -s "https://mcjars.app/api/v1/build/$HASH")

            # Check if .success is true
            if [ "$(echo "$API_RESPONSE" | jq -r '.success')" = "true" ]; then
                if [ "$(echo "$API_RESPONSE" | jq -r '.build.id')" != "$(echo "$API_RESPONSE" | jq -r '.latest.id')" ]; then
                    printout info "New build found. Updating server..."

                    BUILD_ID=$(echo "$API_RESPONSE" | jq -r '.latest.id')
                    bash <(curl -s "https://mcjars.app/api/v1/script/$BUILD_ID/bash?echo=false")

                    jar_bytes=$(stat -c%s server.jar 2>/dev/null || stat -f%z server.jar 2>/dev/null)
                    jar_size=$(printf "%.2f MB" $((jar_bytes / 1000000)))
                    printout info "Server has been updated (Size: $jar_size)"
                else
                    printout info "Server is up to date"
                fi
            else
                printout info "Could not check for updates. Skipping update check."
            fi
        else
            printout info "Could not find hash. Skipping update check."
        fi
    fi

    if [ -f "eula.txt" ]; then
        # create server.properties
        touch server.properties
    fi

    if [ -f "server.properties" ]; then
        # set server-ip to 0.0.0.0
        if grep -q "server-ip=" server.properties; then
            sed -i 's/server-ip=.*/server-ip=0.0.0.0/' server.properties
        else
            echo "server-ip=0.0.0.0" >> server.properties
        fi

        # set server-port to SERVER_PORT
        if grep -q "server-port=" server.properties; then
            sed -i "s/server-port=.*/server-port=${SERVER_PORT}/" server.properties
        else
            echo "server-port=${SERVER_PORT}" >> server.properties
        fi

        # set query.enabled to true
        if grep -q "query.enabled=" server.properties; then
            sed -i "s/query.enabled=.*/query.enabled=true/" server.properties
        else
            echo "query.enabled=true" >> server.properties
        fi

        # set query.port to SERVER_PORT
        if grep -q "query.port=" server.properties; then
            sed -i "s/query.port=.*/query.port=${SERVER_PORT}/" server.properties
        else
            echo "query.port=${SERVER_PORT}" >> server.properties
        fi
    fi

    # settings.yml
    if [ -f "settings.yml" ]; then
        if grep -q "ip" settings.yml; then
            sed -i "s/ip: .*/ip: '0.0.0.0'/" settings.yml
        fi
        if grep -q "port" settings.yml; then
            sed -i "s/port: .*/port: ${SERVER_PORT}/" settings.yml
        fi
    fi

    # velocity.toml
    if [ -f "velocity.toml" ]; then
        if grep -q "bind" velocity.toml; then
            sed -i "s/bind = .*/bind = \"0.0.0.0:${SERVER_PORT}\"/" velocity.toml
        else
            echo "bind = \"0.0.0.0:${SERVER_PORT}\"" >> velocity.toml
        fi
    fi

    # config.yml
    if [ -f "config.yml" ]; then
        if grep -q "query_port" config.yml; then
            sed -i "s/query_port: .*/query_port: ${SERVER_PORT}/" config.yml
        else
            echo "query_port: ${SERVER_PORT}" >> config.yml
        fi
        if grep -q "host" config.yml; then
            sed -i "s/host: .*/host: 0.0.0.0:${SERVER_PORT}/" config.yml
        else
            echo "host: 0.0.0.0:${SERVER_PORT}" >> config.yml
        fi
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # ADMIN MOTD ENFORCEMENT
    # If FORCED_MOTD_LINE1 is set by the admin, it is written to server.properties
    # on EVERY boot. This resets any changes users make in the file manager.
    # Supports Minecraft color codes (§ or &) in MOTD_LINE1 / MOTD_LINE2.
    # ─────────────────────────────────────────────────────────────────────────
    if [ -n "$FORCED_MOTD_LINE1" ]; then
        local _motd="$FORCED_MOTD_LINE1"
        if [ -n "$FORCED_MOTD_LINE2" ]; then
            _motd="${FORCED_MOTD_LINE1}\\n${FORCED_MOTD_LINE2}"
        fi
        # Escape special sed chars in the MOTD value
        local _motd_escaped
        _motd_escaped=$(printf '%s' "$_motd" | sed 's/[&\/\\]/\\&/g')
        if [ -f "server.properties" ]; then
            if grep -q "^motd=" server.properties; then
                sed -i "s|^motd=.*|motd=${_motd_escaped}|" server.properties
            else
                echo "motd=${_motd}" >> server.properties
            fi
        fi
        printout info "🔒 Admin MOTD enforced (user changes reset on restart)"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # ADMIN SERVER ICON ENFORCEMENT
    # If SERVER_ICON_URL is set, downloads server-icon.png on every boot.
    # Users cannot permanently change the icon — it re-downloads on restart.
    # Must be a 64x64 PNG. Tip: host on Imgur or GitHub raw.
    # ─────────────────────────────────────────────────────────────────────────
    if [ -n "$SERVER_ICON_URL" ]; then
        printout info "🖼  Downloading admin server icon..."
        if curl -sS -L --max-time 15 -o server-icon.png "$SERVER_ICON_URL" 2>/dev/null; then
            # Lightweight PNG magic-byte check (first 4 bytes: 89 50 4E 47)
            local _png_magic
            _png_magic=$(od -A n -N 4 -t x1 server-icon.png 2>/dev/null | tr -d ' \n')
            if [ "$_png_magic" = "89504e47" ]; then
                printout success "Server icon applied (user changes reset on restart)"
            else
                printout warn "SERVER_ICON_URL did not return a valid PNG — icon not applied."
                rm -f server-icon.png
            fi
        else
            printout warn "Failed to download server icon from \$SERVER_ICON_URL"
        fi
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # JVM FLAGS (container & Azion free-tier optimised)
    # ─────────────────────────────────────────────────────────────────────────
    FLAGS=("-Dterminal.jline=false -Dterminal.ansi=true")

    # Container-awareness: honour Docker memory + CPU limits set by Pterodactyl
    # UseContainerSupport is default-on in Java 11+ but explicit is safer
    FLAGS+=("-XX:+UseContainerSupport")

    # Reduce thread stack size from 512k→256k — saves ~256KB RAM per player
    # thread. Safe for MC as it rarely uses deep recursion.
    FLAGS+=("-Xss256k")

    # String deduplication: G1GC can merge identical String objects in heap.
    # MC servers have lots of repeated chat/NBT strings. Saves ~5–15% heap.
    FLAGS+=("-XX:+UseStringDeduplication")

    # CPU core limiter (admin-set). Prevents Java from spinning up threads for
    # all container vCPUs on shared nodes and wasting scheduler slots.
    if [ -n "$MAX_CPU_CORES" ] && [ "$MAX_CPU_CORES" -gt 0 ] 2>/dev/null; then
        FLAGS+=("-XX:ActiveProcessorCount=${MAX_CPU_CORES}")
        printout info "CPU cores limited to ${MAX_CPU_CORES} (MAX_CPU_CORES)"
    fi

    # SIMD Operations are only for Java 16-21
    if [[ "$SIMD_OPERATIONS" == "1" ]]; then
        if [[ "$JAVA_VERSION" -ge 16 ]] && [[ "$JAVA_VERSION" -le 21 ]]; then
            FLAGS+=("--add-modules=jdk.incubator.vector")
        else
            printout warn "SIMD Operations are only available for Java 16-21, skipping..."
        fi
    fi

    # GC selection
    if [[ "$ADDITIONAL_FLAGS" == "Aikar's Flags" ]]; then
        # Aikar's G1GC flags — best for Paper/Purpur on most server sizes
        FLAGS+=("-XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem \
-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC \
-XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 \
-XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 \
-XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 \
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 \
-XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 \
-XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 \
-Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true")
    elif [[ "$ADDITIONAL_FLAGS" == "Velocity Flags" ]]; then
        FLAGS+=("-XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:MaxInlineLevel=15")
    elif [[ "$ADDITIONAL_FLAGS" == "ZGC (Java 21+)" ]]; then
        # ZGC: ultra-low pause times (<1ms) on Java 21+.
        # Better for servers with >4GB RAM or that need smooth tick rates.
        if [[ "$JAVA_VERSION" -ge 21 ]]; then
            FLAGS+=("-XX:+UnlockExperimentalVMOptions -XX:+UseZGC -XX:+ZGenerational \
-XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled \
-XX:+PerfDisableSharedMem -XX:MaxGCPauseMillis=1")
            printout info "Using ZGC (generational) — ultra-low GC pauses"
        else
            printout warn "ZGC requires Java 21+. Falling back to default JVM GC."
        fi
    fi

    # ── Memory calculation ───────────────────────────────────────────────────
    # On Azion free-tier nodes memory is shared; keep Xms at 25% of Xmx to
    # allow faster cold-start and leave OS headroom.
    SERVER_MEMORY_REAL=$(($SERVER_MEMORY * $MAXIMUM_RAM / 100))
    # Enforce a minimum of 256 MB
    if [ "$SERVER_MEMORY_REAL" -lt 256 ]; then
        SERVER_MEMORY_REAL=256
        printout warn "Calculated max memory below 256 MB — clamped. Consider upgrading your plan."
    fi
}