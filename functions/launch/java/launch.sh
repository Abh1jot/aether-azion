#!/bin/bash

function launchJavaServer {
    printout info "Checking if Java is up to date..."
    install_java
    postsetup_java
    optimize_server
    geyser_sync_keys
    if [[ -n "$HOSTING_NAME" && -n "$DISCORD_LINK" && "$ENABLE_FORCED_MOTD" == "1" ]]; then
        forced_motd
    fi
    printout info "To switch software: delete the 'system' folder in File Manager and restart."
    printout info "Starting Minecraft Java Server..."
    printout info "Flags: ${FLAGS[*]}"
    printout info "Memory: -Xms${SERVER_MEMORY_XMS}M  -Xmx${SERVER_MEMORY_REAL}M"

    # exec replaces the shell process — no wrapper overhead.
    # "${FLAGS[@]}" expands each flag as its own argument (correct quoting).
    exec java "${FLAGS[@]}" \
        -Xms${SERVER_MEMORY_XMS}M \
        -Xmx${SERVER_MEMORY_REAL}M \
        -jar server.jar nogui
}

function launchVanillaServer {
    printout info "Checking if Java is up to date..."
    install_java
    postsetup_java
    geyser_sync_keys
    if [[ -n "$HOSTING_NAME" && -n "$DISCORD_LINK" && "$ENABLE_FORCED_MOTD" == "1" ]]; then
        forced_motd
    fi
    printout info "To switch software: delete the 'system' folder in File Manager and restart."
    printout info "Starting Vanilla Server..."
    printout info "Flags: ${FLAGS[*]}"
    printout info "Memory: -Xms${SERVER_MEMORY_XMS}M  -Xmx${SERVER_MEMORY_REAL}M"

    exec java "${FLAGS[@]}" \
        -Xms${SERVER_MEMORY_XMS}M \
        -Xmx${SERVER_MEMORY_REAL}M \
        -jar server.jar nogui
}
