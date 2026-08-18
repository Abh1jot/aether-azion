> [!NOTE]
> This is a fork of [lonersoft/aether](https://github.com/lonersoft/aether), optimised for **free Minecraft hosting on Azion Cloud**.

# 🥚 aether-azion

A Pterodactyl multi-egg for free Minecraft hosting, built on top of [aether](https://github.com/lonersoft/aether) with targeted improvements for Azion Cloud free-tier nodes.

---

## ✨ What's different from upstream

| Area | Upstream aether | aether-azion (this fork) |
|---|---|---|
| **Existing-install detection** | ❌ none — server wiped on egg change | ✅ Auto-detects Paper / Vanilla / Bedrock / proxy; boots straight in |
| **Docker base** | `ubuntu:latest` (floating) | `ubuntu:24.04` (pinned LTS) |
| **Init process** | plain bash | `tini` — proper SIGTERM → Java process forwarding |
| **toilet dependency** | required | removed — pure-bash banner |
| **Default MAXIMUM_RAM** | 90 % | 80 % (Azion nodes have shared OS overhead) |
| **Default Java** | 25 | 21 (Paper requires 21 minimum) |
| **Default flags** | None | Aikar's Flags (best for Paper on low RAM) |
| **Memory floor** | none | 256 MB minimum enforced |
| **`warning` log level** | broken (typo) | fixed → `warn` |

---

## 🔍 Existing Installation Detection (key feature)

If a server was originally created with the **stock Pterodactyl Paper egg** and the egg is later switched to aether-azion, the first boot will:

1. Scan for `server.jar`, `plugins/`, `server.properties`, `bedrock_server`, proxy configs
2. Read the JAR's MANIFEST.MF to identify the software (Paper, Purpur, Pufferfish, Spigot, Vanilla…)
3. Automatically write `system/multiegg.yml` with the correct type
4. Fix `server-ip` and `server-port` to match Pterodactyl's allocation
5. Boot the server **without touching any world data, plugins, or configs**

> [!IMPORTANT]
> Your worlds and plugins are **never deleted or modified**. Only `server-ip` and `server-port` in `server.properties` are updated.

---

## 🧩 Inherited Features (from upstream aether)

- **Multi-software menu** — Java (Vanilla, Paper, Purpur, Pufferfish), Bedrock, Proxies (BungeeCord, Velocity, Waterfall)
- **Automatic updating** — via MCJars API hash comparison
- **Built-in rules** — first-boot ToS acceptance screen
- **Forced MOTD** — admin-configurable MOTD branding
- **Server optimization** — optional Hibernate plugin injection
- **MCJars API Key** — for tracking and software blocking

---

## ➕ Installation

1. Download `egg-aether-azion.json` from this repo
2. In Pterodactyl → Admin → Nests → Import Egg
3. When creating a new server, select **aether-azion** as the egg

### Migrating an existing Paper server

1. **Do NOT reinstall** the server
2. Switch the egg to aether-azion in the Admin panel
3. Restart — the egg will auto-detect your existing Paper install and boot normally

---

## ⚙️ Egg Variables

| Variable | Default | Description |
|---|---|---|
| `JAVA_VERSION` | `21` | Java version (8/11/17/21/23/24/25) |
| `ADDITIONAL_FLAGS` | `Aikar's Flags` | JVM flag preset |
| `AUTOMATIC_UPDATING` | `0` | Auto-update server jar on boot |
| `MAXIMUM_RAM` | `80` | % of `SERVER_MEMORY` to give to Java |
| `SIMD_OPERATIONS` | `0` | Enable `jdk.incubator.vector` (Java 16–21) |
| `HOSTING_NAME` | `aether-azion` | *(Admin)* Your hosting brand name |
| `DISCORD_LINK` | *(empty)* | *(Admin)* discord.gg invite code |
| `EMAIL` | *(empty)* | *(Admin)* Support email |
| `ENABLE_FORCED_MOTD` | `0` | *(Admin)* Force branding MOTD |
| `OPTIMIZE_SERVER` | `0` | *(Admin)* Install Hibernate plugin |
| `ENABLE_RULES` | `0` | *(Admin)* Show rules on first boot |
| `MCJARS_API_KEY` | *(empty)* | *(Admin)* MCJars API key |

---

## 📜 License

MIT — same as upstream [lonersoft/aether](https://github.com/lonersoft/aether)
