# Steam development integration

Offline play works without Steam. This optional adapter targets the maintained [GodotSteam](https://codeberg.org/godotsteam/godotsteam) API and [Steam Networking Messages](https://partner.steamgames.com/doc/api/ISteamNetworkingMessages).

**Status:** implemented and tested against a fake Steam boundary. No live two-account session has been verified, and no native GodotSteam binaries are installed in this workspace.

## Install

1. Get a GodotSteam GDExtension release compatible with your Godot version from the project's maintained download instructions. Install its `.gdextension` file and native dependencies as supplied by that release, normally under `addons/godotsteam/`. A GodotSteam engine build exposing the same `Steam` singleton is also supported.
2. Keep the extension's license and dependency notices with any build you distribute. This repository does not bundle the Steamworks SDK or third-party binaries.
3. Start the Steam desktop client and sign in. Launch this project with the compatible editor/engine.
4. Click **Steam**. A successful initialization reports that Steam is connected. If the extension is missing or initialization fails, the game remains available offline.

The adapter calls `steamInitEx(480, false)` and calls `run_callbacks()` explicitly. The App ID is the first argument in the current API. Received Networking Messages use the current `payload` and `identity` dictionary fields; an old extension with different fields needs adaptation. See [current initialization documentation](https://codeberg.org/godotsteam/godotsteam-docs/src/branch/master/docs/tutorials/initializing.md) and [Networking Messages documentation](https://codeberg.org/godotsteam/godotsteam-docs/src/branch/master/docs/tutorials/networking_messages.md).

Valve documents `480` as the [Spacewar example application's App ID](https://partner.steamgames.com/doc/sdk/api/example). This project uses it for development. Plan a dedicated App ID for public distribution.

## Test with a friend

1. Both players use the same project code and content on distinct Steam accounts.
2. Host selects **Steam → Host friends-only lobby**.
3. Reopen **Steam**, then copy the lobby ID and share it with the other player. The host is player 1.
4. Guest selects **Steam**, pastes the lobby ID and selects **Join lobby**. The guest is player 2.
5. Host can also open **Invite Steam friends**. Joining through the overlay invitation is not wired into the game yet; use the lobby ID to complete the join.
6. Host can choose both deck presets from **Decks**. Play a full match including shop and deployment, then save the replay on the host. This version uses the expanded Classic pack and protocol 3; both players need this updated build.

App ID 480 has many unrelated development lobbies. The adapter checks its own game tag and protocol before accepting a guest lobby.

## Authority and privacy

- Lobby capacity is two. The host simulates the complete match.
- Reliable JSON envelopes travel on channel 71. No object deserialization is used.
- Only messages from the bound opponent who is still a lobby member are accepted.
- The guest sends a command and the observation's revision. The host rejects stale revisions and the rules engine rejects all illegal command shapes/targets/resources.
- Guest snapshots contain the guest's hand/shop and public board, counts, deck preset names, structures and log. They exclude the host's hand/shop, both main/item deck orders, unrevealed host deployment plans and RNG state. Purchase logs show gold spent without naming the unrevealed item.
- The host is trusted and can see both hands; this is a friend-play architecture. A future competitive service should move authority to a trusted dedicated server.
- The original opponent is bound to the current lobby match. A different account cannot take over its seat.
- A reconnect to the same still-existing lobby requests the latest host snapshot. There is no automatic rejoin UI, timeout/pause policy or host migration yet.

Commands, state envelopes and privacy boundaries are checked in `tests/run_tests.gd`; actual networking is a separate integration check. Report exact Godot/GodotSteam versions and connection results before describing online play as verified.
