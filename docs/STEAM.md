# Online play over Steam

Two friends can play a match over Steam. Offline play (AI, local two-player,
replays) never needs Steam.

**Status:** the whole online flow is implemented and tested in-process against a
fake Steam that has the same methods, signals and constants as GodotSteam
4.23.1 (`tests/steam_test.gd`). On one account, the real Steam client has
confirmed initialization, lobby creation, lobby data and the lobby search. **A
match between two Steam accounts has not been played yet.** Use the
[test checklist](#test-checklist) below and report the results.

## What is installed

Nothing needs installing. The repository includes
[GodotSteam](https://codeberg.org/godotsteam/godotsteam) **4.23.1** (GDExtension,
Steamworks SDK 1.65, MIT) in `addons/godotsteam/`, with Valve's Steamworks API
libraries for Windows x64, Linux x64 and macOS. Licences are listed in
[CREDITS.md](../CREDITS.md).

You need:

- the Steam desktop client, running and signed in **before** the game starts;
- Godot 4.5.2 (the portable copy in `.tools/godot/` is what `run.ps1` uses).

The game uses Valve's development App ID **480** (Spacewar), so Steam shows you
as "Playing Spacewar". `steam_appid.txt` is not needed: the game passes 480 to
`steamInitEx` itself. Leave GodotSteam's "auto-initialize" project setting off.

Steam is not started:

- in headless runs (tests and CI);
- when you launch with `.\run.ps1 -NoSteam` (or pass `--no-steam` to Godot).

If Steam is missing or fails to start, the Steam dialog explains why and
offline play still works.

## How online play works

- **Host and guest.** The host runs the rules engine and is player 1. The guest
  is player 2. The guest only ever receives its own view: the host's hand, shop,
  deck order, deployment plans and random state stay on the host. The host checks
  every guest command against the legal actions, so a guest cannot make an
  illegal move. Online matches use a fresh random seed from the operating
  system's secure random source, so the guest cannot reconstruct the host's
  hand or deck order from the board it sees. The host itself is trusted, which
  is fine between friends.
- **Lobbies.** A lobby holds two players. It can be **friends-only** (your Steam
  friends can see and join it) or **public** (shown in the lobby browser to
  anyone running this game). Lobby data lists the game tag
  `sanguo_classic_revival`, the protocol number, a content hash, the host's
  name and the lobby status (`waiting`, `playing` or `reconnecting`).
  Rich presence sets `connect` to `+connect_lobby <id>`.
- **Ways to join:**
  - paste the lobby ID (or a `+connect_lobby <id>` or `steam://joinlobby/480/<id>/…` link);
  - accept an overlay invite, or use "Join game" in the friends list, while the game is running;
  - start the game with `+connect_lobby <id>` (`.\run.ps1 +connect_lobby <id>`; Steam passes this itself when the game is launched from a join);
  - pick a public lobby in the browser (Join is only offered for lobbies of the
    same build that are waiting for an opponent).

  While you are in a lobby, Host and Join are disabled and invites are refused
  with "Leave the current lobby first", so a running match is never dropped
  by accident. Starting Versus AI, Local play or a replay leaves the lobby.
- **Handshake.** After joining, the guest sends `hello` with the protocol number
  (9), its content hash and its GodotSteam version, and repeats it every 2
  seconds until the host replies. The content hash is a hash of
  `data/classic_cards.json`, `data/locale/cards.json` and the protocol number,
  with line endings normalized. If anything differs, the host sends `reject`
  and both sides show a "version mismatch" message that lists both versions.
  The guest also checks the lobby data before saying hello. Once accepted, both
  sides show **Connected to <Steam name>**.
- **Messages.** Messages are JSON on channel 71. They are sent with the
  reliable and auto-restart-broken-session flags (8|32), and each is capped at
  256 KB. The host accepts session requests from anyone who is in the lobby,
  even before Steam has reported them as a lobby member, so the first hello is
  never lost. Received views and commands have their whole numbers turned back
  into integers. Packets that are malformed, wrongly typed or nested deeper
  than 32 levels are dropped without logging. Display names come from Steam,
  not from what the other side reports, and are cut to 32 characters.
- **Decks (protocol 9).** Each player brings their own deck. After every
  `welcome`, and whenever they pick another deck (Steam dialog: Change deck,
  or Decks in the match menu), the guest sends `{"kind": "deck", "code":
  "ADC…"}`: its deck as a deck code (Valve's ArtifactDeckCode format, at most
  512 characters) without the deck's name (text the player typed is not
  needed to play; the deck the host plays carries no name even when another
  client puts one in the code). The host accepts it only from the bound guest after the
  handshake, handles at most one per 250 ms (the latest wins), decodes it,
  checks it against the deck rules and answers `{"kind": "deck_result", "ok",
  "code", "args"}`; the guest shows the reason in its language. A new guest's
  first match starts as soon as its deck arrives (or after 3 seconds); a
  missing or illegal deck is replaced by a preset, and the guest is told. A
  deck changed during a match is used from the next match (each screen keeps
  naming the deck being played until then). Neither player's
  view names the other's deck or preset (it shows as "Opponent's deck"); the
  heroes are public, as in Classic. The host's game holds the guest's list,
  like the rest of the authoritative state.
- **Commands.** In the action phase a guest command must match the current
  revision. In the shop and deployment phases both players plan at once, so a
  guest command that is still legal is applied even if the host acted first.
  A command the host cannot apply is answered with a small "not applied"
  notice (shown to the guest) and at most one fresh snapshot per second.
- **Heartbeat.** Each side pings every 5 seconds. The opponent's name plate
  shows signal bars and the ping; hover over it for details. After 20 seconds
  without a reply, the opponent counts as lost.
- **Disconnects.**
  - **Guest leaves, crashes or stops answering.** The host's match pauses and
    shows "waiting for opponent to reconnect" with a timer. The host can choose
    **Keep waiting**, which shrinks the message to a small bar, **Claim victory**
    (available after 30 seconds; it is recorded as the guest conceding) or
    **Leave match**.
  - **The guest's seat belongs to their Steam account.** The same account can
    rejoin the same lobby by ID, browser, invite or command line and gets the
    latest snapshot. Any other account is turned away with "seat taken", and
    the host stops listening to it. While the seat is reserved the lobby allows
    a third member, so a stranger in the free slot cannot lock the guest out,
    and the lobby browser shows it as "Waiting for a player to rejoin" without
    a Join button.
  - **Host leaves.** The guest sees "The host left" and goes back to the menu.
    The host only being unreachable shows the guest a waiting screen with Keep
    waiting and Leave instead.
  - **Steam shuts down, or your connection to Steam drops.** Online play ends
    with a message and you return to the menu. A guest can rejoin the host's
    lobby with the same account once Steam is back.
  - **A new match on the host** (Play again) restarts the guest's screen. Only
    the host can start a new match or save the replay.
- **Concede.** **Menu → Concede** works for either player in any phase, online
  and offline. It is an engine command, so it appears in the log and replays.

## Testing with two accounts

You need two Steam accounts on two computers (a PC and a laptop is fine), each
running the **same build**: the same git commit, with no local changes to
`data/`. For a friends-only lobby the two accounts must be Steam friends. A
public lobby or the ID works without that.

1. On both machines, start Steam and sign in. Then start the game with
   `.\run.ps1` from the project folder. You can also open the project in Godot
   and press F5, but the Steam overlay often doesn't attach to an editor-launched
   game, so use `run.ps1` to test invites.
2. Both: open **Online (Steam)** from the main menu. The dialog should say
   *Steam connected* and show `GodotSteam 4.23.1 · protocol 9 · content xxxxxxxx`.
   The content value must be the same on both machines.
3. Host: choose **Host friends-only lobby** or **Host public lobby**.
4. Guest: join in one of these ways:
   - **By ID:** the host presses **Copy lobby ID** and sends it (by chat, for
     example). The guest pastes it and presses **Join lobby**.
   - **By invite:** the host presses **Invite Steam friends** and picks the
     guest. The guest, **with this game already running**, accepts the invite
     from the Steam overlay (Shift+Tab) or the friends list.
   - **From the friends list:** the guest right-clicks the host in the Steam
     friends list and chooses **Join game** (game already running).
   - **By browser** (public lobbies only): the guest presses **Refresh** under
     *Public lobbies* and joins the host's row.
5. The match starts on both screens as soon as the guest's deck has reached
   the host (right after the handshake). The host plays the deck it last
   chose; the guest plays its own deck (Steam dialog: **Your deck** /
   **Change deck**, chosen before or after joining).

### App 480 caveats

- **An invite accepted while the game is closed starts Valve's Spacewar, not
  this game.** Steam launches App 480's own program. The friend must have this
  game running already, or join by ID or the browser instead. The same applies
  to "Join game" in the friends list. A dedicated App ID fixes this for a
  release.
- Many developers share App 480. The lobby browser only shows lobbies whose
  game tag matches, so other developers' lobbies don't appear.
- Steam's lobby search may take a few seconds and only returns lobbies that
  have a free seat. It searches worldwide.
- The friends-list status text comes from Spacewar's rich presence strings
  (`#Status_WaitingForMatch`). It is cosmetic.
- Both accounts must be different. One account can't play against itself.

### Troubleshooting

| Symptom | Check |
|---|---|
| "Steam is turned off for this run" | You started with `-NoSteam`/`--no-steam` or headless. Start with `.\run.ps1`. |
| "Steam is not running or you are not signed in" | Start Steam and sign in first, then restart the game. |
| "Steam could not initialize: …" | Another Steam problem; the detail after the colon comes from Steam. Restart Steam, then the game. |
| "Your Steam client is older …" | Update the Steam client (Steam → Check for Steam Client Updates), then restart the game. |
| "Leave the current lobby first" | You are still in a lobby. Press **Leave lobby** in the Steam dialog, then host or join. |
| "The connection to Steam was lost" | Your internet or Steam connection dropped. Wait until Steam shows you online again, then rejoin the lobby by ID. |
| "The host did not apply that move" | Your move arrived after the board changed. Look at the board again and repeat it. |
| "GodotSteam could not be loaded" | `addons/godotsteam/` is missing, or your platform's folder isn't in the repository (only Windows x64, Linux x64 and macOS are). |
| "Version mismatch …" | The two builds differ. Compare the `content` value in both Steam dialogs, update both to the same commit and discard local changes to `data/`. |
| Invite does nothing | The guest must already be running the game (see the caveats above), and the overlay must be working: launch with `run.ps1`, not the editor, and press Shift+Tab to check. |
| Guest stays on "Contacting the host…" | Both sides need internet access to Steam's relay network. Wait 10 seconds. The hello repeats until the host answers. Check the host is still in the lobby. |
| "Seat taken" | That match belongs to another account. The host must leave and create a new lobby. |
| Ping bars red, or "No reply …" | The connection is poor or lost. Messages restart the session automatically. After 20 seconds the match pauses until the opponent comes back. |

Include both players' dialog version lines, the status messages and the host's
saved replay when reporting a problem.

## Test checklist

Fill in one row per check, on two accounts and two machines. Record the
date, the commit (`git rev-parse --short HEAD`) and the operating system of
each machine.

| # | Check | Steps | Expected | Host result | Guest result | Notes |
|---|---|---|---|---|---|---|
| 1 | Init | Start Steam, `.\run.ps1`, open Online (Steam) | "Steam connected", GodotSteam 4.23.1, same content hash on both | | | |
| 2 | Host | Host friends-only lobby; then repeat with Host public lobby | "Lobby … created", lobby ID shown, Invite/Copy/Leave visible | | | |
| 3 | Join by ID | Copy lobby ID, guest pastes and joins | Both show "Connected to <name>", match starts, guest is player 2 | | | |
| 4 | Join by invite | Host invites, guest (game running) accepts in overlay | Guest's Steam dialog opens by itself and the match starts | | | |
| 5 | Lobby browser | Host a public lobby, guest presses Refresh | Host's row shows host name and "Waiting for an opponent"; Join works | | | |
| 6 | Full match | Play to the end: several lanes, shop (buy, hold), deployment, abilities | Both boards agree; guest never sees host's hand or shop; match ends with victory/defeat | | | |
| 7 | Guest disconnect / rejoin | Mid-match, guest quits the game (or unplugs the network), then restarts and joins the same lobby | Host sees the waiting overlay with a timer; guest returns to the same position and play continues | | | |
| 8 | Other account blocked | While the guest is away, a third account joins the lobby | Third account gets "seat taken"; host keeps waiting | | | |
| 9 | Claim victory | Guest quits; host waits 30 s and claims victory | Host wins; log shows the guest conceded | | | |
| 10 | Host leaves | Mid-match, host leaves (Menu → Steam → Leave lobby, or quits the game) | Guest gets "The host left" and returns to the menu | | | |
| 11 | Concede | Guest concedes in a new match, then the host concedes in another | The other side wins at once; log shows who conceded | | | |
| 12 | Version mismatch | Guest edits one value in `data/classic_cards.json` (then reverts) and joins | Guest sees "Version mismatch" with both hashes and leaves the lobby | | | |
| 13 | Connection display | During a match, hover over the opponent's name plate | Bars and ping in ms; tooltip shows connection quality | | | |
| 14 | Languages | One player in 中文, the other in English | Both play normally; each sees their own language | | | |
| 15 | Friends-list join | Host in a lobby; guest (game running) right-clicks the host in the Steam friends list → Join game | Guest joins and the match starts | | | |
| 16 | Simultaneous shop | In a shop phase both players buy or hold within the same second | Both purchases happen; nobody's click is lost | | | |
| 17 | Rematch | Finish a match; host presses Play again | Guest's result screen closes and the new match shows; guest's Play again / Save replay are disabled | | | |
| 18 | Busy in a lobby | During a match, open Online (Steam) on either side; guest also accepts an invite to another lobby | Host and Join are disabled; the invite is refused with "Leave the current lobby first"; the match continues | | | |
| 19 | Leave for offline | Guest in a lobby picks Versus AI from the main menu | Guest leaves the lobby (host sees the guest left); the AI match is not replaced | | | |
| 20 | Network drop | Guest disables the network adapter for 30 s mid-match, then enables it | Guest gets "connection to Steam was lost" (or waits, if only the peer link dropped); host waits; guest rejoins by ID and continues | | | |
| 21 | Guest's own deck | Guest builds a deck (Decks → New deck), picks it with Change deck, joins | Guest gets "The host accepted your deck"; the guest's heroes are those of its deck, in their rounds; neither end-of-match screen names the other's deck | | | |
| 22 | Illegal guest deck | Guest picks an unfinished deck with Change deck during a match | Guest is told why the host cannot use it (in its language); the next match gives the guest a preset | | | |
| 23 | Deck change mid-match | Guest picks another legal deck (or a preset) with Change deck during a match | The guest's matchup line keeps naming the deck being played until the next match, then names the new one (a preset by its name, not "Custom deck") | | | |

## Files

- `scripts/network/steam_bridge.gd`: lobbies, the browser, join paths,
  handshake, messages, heartbeat and disconnects. All Steam calls go through
  this file.
- `scripts/game/match_controller.gd`: the online match: starting, resuming,
  pausing, claim victory and concede, and the guest's deck (sent, validated,
  answered, hidden from the other player's view).
- `scripts/ui/steam_dialog.gd`, `scripts/ui/reconnect_overlay.gd` and
  `scripts/ui/player_panel.gd`: the lobby dialog, the pause overlay and the
  connection display.
- `tests/steam_test.gd`: the FakeSteam/FakeHub boundary tests, including a
  check of method names, argument counts and constants against the loaded
  GodotSteam.
