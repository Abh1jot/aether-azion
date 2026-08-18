#!/bin/bash

function postsetup_java {
    # ── Auto-update check ────────────────────────────────────────────────────
    if [[ "$AUTOMATIC_UPDATING" == "1" ]]; then
        printout info "Checking for server jar updates..."
        if [ -z "${HASH}" ]; then
            HASH=$(sha256sum server.jar | awk '{print $1}')
        fi
        if [ -n "${HASH}" ]; then
            API_RESPONSE=$(curl --connect-timeout 4 -s "https://mcjars.app/api/v1/build/$HASH")
            if [ "$(echo "$API_RESPONSE" | jq -r '.success')" = "true" ]; then
                if [ "$(echo "$API_RESPONSE" | jq -r '.build.id')" != "$(echo "$API_RESPONSE" | jq -r '.latest.id')" ]; then
                    printout info "New build found. Updating server..."
                    BUILD_ID=$(echo "$API_RESPONSE" | jq -r '.latest.id')
                    bash <(curl -s "https://mcjars.app/api/v1/script/$BUILD_ID/bash?echo=false")
                    jar_bytes=$(stat -c%s server.jar 2>/dev/null || stat -f%z server.jar 2>/dev/null)
                    printout info "Server updated ($(printf '%.1f MB' $((jar_bytes / 1000000))))"
                else
                    printout info "Server is up to date"
                fi
            else
                printout info "Could not check for updates. Skipping."
            fi
        fi
    fi

    # ── server.properties enforcement ────────────────────────────────────────
    if [ -f "eula.txt" ]; then touch server.properties; fi

    if [ -f "server.properties" ]; then
        # Upsert helper: replace or append a key=value line
        _sp_set() {
            local key="$1" val="$2"
            if grep -q "^${key}=" server.properties; then
                sed -i "s|^${key}=.*|${key}=${val}|" server.properties
            else
                echo "${key}=${val}" >> server.properties
            fi
        }
        _sp_set server-ip   "0.0.0.0"
        _sp_set server-port "${SERVER_PORT}"
        _sp_set query.enabled "true"
        _sp_set query.port  "${SERVER_PORT}"
    fi

    # Proxy / misc config files
    if [ -f "settings.yml" ]; then
        sed -i "s/ip: .*/ip: '0.0.0.0'/"    settings.yml
        sed -i "s/port: .*/port: ${SERVER_PORT}/" settings.yml
    fi
    if [ -f "velocity.toml" ]; then
        grep -q "bind" velocity.toml \
            && sed -i "s/bind = .*/bind = \"0.0.0.0:${SERVER_PORT}\"/" velocity.toml \
            || echo "bind = \"0.0.0.0:${SERVER_PORT}\"" >> velocity.toml
    fi
    if [ -f "config.yml" ]; then
        grep -q "query_port" config.yml \
            && sed -i "s/query_port: .*/query_port: ${SERVER_PORT}/" config.yml \
            || echo "query_port: ${SERVER_PORT}" >> config.yml
        grep -q "^host" config.yml \
            && sed -i "s/host: .*/host: 0.0.0.0:${SERVER_PORT}/" config.yml \
            || echo "host: 0.0.0.0:${SERVER_PORT}" >> config.yml
    fi

    # ── Admin MOTD enforcement ────────────────────────────────────────────────
    # Written every boot → resets any user edits on restart
    if [ -n "$FORCED_MOTD_LINE1" ] && [ -f "server.properties" ]; then
        local _motd="$FORCED_MOTD_LINE1"
        [ -n "$FORCED_MOTD_LINE2" ] && _motd="${FORCED_MOTD_LINE1}\\n${FORCED_MOTD_LINE2}"
        local _escaped; _escaped=$(printf '%s' "$_motd" | sed 's/[&\/\\]/\\&/g')
        grep -q "^motd=" server.properties \
            && sed -i "s|^motd=.*|motd=${_escaped}|" server.properties \
            || echo "motd=${_motd}" >> server.properties
        printout info "🔒 Admin MOTD enforced"
    fi

    # ── Admin server icon enforcement ─────────────────────────────────────────
    # Downloaded every boot → resets any user edits on restart
    if [ -n "$SERVER_ICON_URL" ]; then
        printout info "🖼  Applying admin server icon..."
        if curl -sS -L --max-time 15 -o server-icon.png "$SERVER_ICON_URL" 2>/dev/null; then
            local _magic; _magic=$(od -A n -N 4 -t x1 server-icon.png 2>/dev/null | tr -d ' \n')
            [ "$_magic" = "89504e47" ] \
                && printout success "Server icon applied" \
                || { printout warn "SERVER_ICON_URL is not a valid PNG — skipped"; rm -f server-icon.png; }
        else
            printout warn "Failed to download server icon"
        fi
    fi

    # ── JVM FLAGS ─────────────────────────────────────────────────────────────
    # Each flag is its own array element so expansion is always clean.
    FLAGS=()

    # Terminal / console
    FLAGS+=("-Dterminal.jline=false")
    FLAGS+=("-Dterminal.ansi=true")

    # ── Container awareness ───────────────────────────────────────────────────
    # Tell JVM to respect Docker cgroup memory/CPU limits
    FLAGS+=("-XX:+UseContainerSupport")

    # ── Startup speed ─────────────────────────────────────────────────────────
    # Pre-fault ALL heap pages at JVM start → eliminates on-demand page faults
    # during gameplay which cause GC pauses and TPS drops.
    # Most impactful single flag for startup time + in-game smoothness.
    FLAGS+=("-XX:+AlwaysPreTouch")

    # Use /dev/urandom instead of /dev/random for entropy.
    # /dev/random can BLOCK waiting for entropy → Paper patch application
    # and crypto operations (player logins, Floodgate) are dramatically faster.
    FLAGS+=("-Djava.security.egd=file:/dev/urandom")

    # Consistent encoding across all systems
    FLAGS+=("-Dfile.encoding=UTF-8")

    # Better error messages — Paper team recommends this
    FLAGS+=("-XX:-OmitStackTraceInFastThrow")

    # ── Thread stack size ─────────────────────────────────────────────────────
    # Default is 512k per thread. 384k is safe for Paper + WorldEdit + most plugins.
    FLAGS+=("-Xss384k")

    # ── String deduplication ──────────────────────────────────────────────────
    # Merge identical String objects in heap (chat, NBT, config values).
    # Saves 5–15% heap on typical Paper servers.
    FLAGS+=("-XX:+UseStringDeduplication")

    # ── CPU core limiter (admin-set) ──────────────────────────────────────────
    if [ -n "$MAX_CPU_CORES" ] && [ "$MAX_CPU_CORES" -gt 0 ] 2>/dev/null; then
        FLAGS+=("-XX:ActiveProcessorCount=${MAX_CPU_CORES}")
        printout info "CPU capped at ${MAX_CPU_CORES} core(s)"
    fi

    # ── SIMD (Java 16-21 only) ────────────────────────────────────────────────
    if [[ "$SIMD_OPERATIONS" == "1" ]]; then
        if [[ "$JAVA_VERSION" -ge 16 ]] && [[ "$JAVA_VERSION" -le 21 ]]; then
            FLAGS+=("--add-modules=jdk.incubator.vector")
        else
            printout warn "SIMD requires Java 16-21 — skipping"
        fi
    fi

    # ── GC selection ──────────────────────────────────────────────────────────
    if [[ "$ADDITIONAL_FLAGS" == "Aikar's Flags" ]]; then
        # Aikar's G1GC — tuned for Paper / Spigot servers.
        # Each flag is its own element so word-splitting is never an issue.
        FLAGS+=("-XX:+UseG1GC")
        FLAGS+=("-XX:+ParallelRefProcEnabled")
        FLAGS+=("-XX:MaxGCPauseMillis=200")
        FLAGS+=("-XX:+UnlockExperimentalVMOptions")
        FLAGS+=("-XX:+DisableExplicitGC")
        FLAGS+=("-XX:G1NewSizePercent=30")
        FLAGS+=("-XX:G1MaxNewSizePercent=40")
        FLAGS+=("-XX:G1HeapRegionSize=8M")
        FLAGS+=("-XX:G1ReservePercent=20")
        FLAGS+=("-XX:G1HeapWastePercent=5")
        FLAGS+=("-XX:G1MixedGCCountTarget=4")
        FLAGS+=("-XX:InitiatingHeapOccupancyPercent=15")
        FLAGS+=("-XX:G1MixedGCLiveThresholdPercent=90")
        FLAGS+=("-XX:G1RSetUpdatingPauseTimePercent=5")
        FLAGS+=("-XX:SurvivorRatio=32")
        FLAGS+=("-XX:+PerfDisableSharedMem")
        FLAGS+=("-XX:MaxTenuringThreshold=1")
        FLAGS+=("-Dusing.aikars.flags=https://mcflags.emc.gs")
        FLAGS+=("-Daikars.new.flags=true")

    elif [[ "$ADDITIONAL_FLAGS" == "Velocity Flags" ]]; then
        FLAGS+=("-XX:+UseG1GC")
        FLAGS+=("-XX:+ParallelRefProcEnabled")
        FLAGS+=("-XX:+UnlockExperimentalVMOptions")
        FLAGS+=("-XX:G1HeapRegionSize=4M")
        FLAGS+=("-XX:MaxInlineLevel=15")

    elif [[ "$ADDITIONAL_FLAGS" == "ZGC (Java 21+)" ]]; then
        # Sub-millisecond GC pauses — best for high-RAM servers or tick stability
        if [[ "$JAVA_VERSION" -ge 21 ]]; then
            FLAGS+=("-XX:+UnlockExperimentalVMOptions")
            FLAGS+=("-XX:+UseZGC")
            FLAGS+=("-XX:+ZGenerational")
            FLAGS+=("-XX:+DisableExplicitGC")
            FLAGS+=("-XX:+ParallelRefProcEnabled")
            FLAGS+=("-XX:+PerfDisableSharedMem")
            FLAGS+=("-XX:MaxGCPauseMillis=1")
            printout info "ZGC (generational) active — ultra-low GC pauses"
        else
            printout warn "ZGC requires Java 21+ — falling back to JVM default GC"
        fi
    fi

    # ── Memory ────────────────────────────────────────────────────────────────
    # Xmx: derived from MAXIMUM_RAM % of allocated SERVER_MEMORY
    SERVER_MEMORY_REAL=$(( SERVER_MEMORY * MAXIMUM_RAM / 100 ))
    if [ "$SERVER_MEMORY_REAL" -lt 256 ]; then
        SERVER_MEMORY_REAL=256
        printout warn "Max memory below 256 MB — clamped. Consider upgrading your plan."
    fi

    # Xms: start at 50% of Xmx (min 512 MB).
    # A higher Xms dramatically reduces GC during startup because the JVM
    # doesn't need to grow the heap — crucial on slow free-tier I/O.
    SERVER_MEMORY_XMS=$(( SERVER_MEMORY_REAL / 2 ))
    if [ "$SERVER_MEMORY_XMS" -lt 512 ]; then SERVER_MEMORY_XMS=512; fi
    if [ "$SERVER_MEMORY_XMS" -gt "$SERVER_MEMORY_REAL" ]; then SERVER_MEMORY_XMS="$SERVER_MEMORY_REAL"; fi
}