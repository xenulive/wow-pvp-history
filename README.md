# WoW PvP History

[![publish](https://github.com/xenulive/wow-pvp-history/actions/workflows/publish.yml/badge.svg)](https://github.com/xenulive/wow-pvp-history/actions/workflows/publish.yml)

**A World of Warcraft addon that remembers your PvP matches, and everyone in them.**

The scoreboard disappears the moment you leave a match. PvP History keeps it: every arena, Solo Shuffle,
battleground, Blitz, duel and World PvP fight is saved with its full roster, so you can look back at how
a match went, how your rating moved, and who you've played with and against.

Everything stays in the game's own addon files on your computer. It needs no account, website or
companion app.

[Download the latest release](https://github.com/xenulive/wow-pvp-history/releases) or get it
[on CurseForge](https://www.curseforge.com/wow/addons/wow-pvp-history), read
[the guide](https://github.com/xenulive/wow-pvp-history/wiki), visit
[the website](https://pvphistory.xenu.live), or
[report a problem](https://github.com/xenulive/wow-pvp-history/issues).

![The match history window](https://raw.githubusercontent.com/wiki/xenulive/wow-pvp-history/images/history-window.png)

## What it does

- Every match goes into one searchable list, grouped into play sessions, with result, map, opponents,
  length and rating change. Open any match in its own window to see the whole scoreboard.
- Your current rating and tier for each bracket, your win rate, and a rating graph over the season or
  any time range you pick.
- Solo Shuffle round by round: who was on your team each round, who won it, and how each player's
  results changed your rating.
- The team comps and specs you struggle against, taken from your own games.
- **Ask** answers four questions from your own games: what beats you, your best teammate spec, the comp
  you do worst against, and the map you lose on most.
- Everyone you've met, with your own notes, tags and a rep from **Strong** to **Bad**. Your notes show
  up on tooltips, in the group finder, and as a banner at the start of a match when someone you know is
  in it.
- Duel results, and your kills and deaths in the open world with War Mode on.
- Automatic backups on logout, export and import to move your history between computers or characters,
  and CSV export for spreadsheets.

<p align="center">
  <img src="https://raw.githubusercontent.com/wiki/xenulive/wow-pvp-history/images/shuffle-rounds.png" alt="A Solo Shuffle match, round by round" width="720">
</p>

## Install

1. Download the zip from the newest [release](https://github.com/xenulive/wow-pvp-history/releases).
2. Close the game.
3. Unzip it into `World of Warcraft\_retail_\Interface\AddOns`, so a `WowPvpHistory` folder sits there.
4. Log in. Recording starts on its own; there's nothing to set up.

To check it worked, click **AddOns** on the character select screen: **WoW PvP History** should be in
the list. If it isn't, look for `WowPvpHistory.toc` one folder too deep, such as
`AddOns\WowPvpHistory-<version>\WowPvpHistory`, and move the inner `WowPvpHistory` folder up into
`AddOns`. [Getting started](https://github.com/xenulive/wow-pvp-history/wiki/Getting-Started) walks
through it step by step.

Every release is also on CurseForge as the same zip, on the
[WoW PvP History](https://www.curseforge.com/wow/addons/wow-pvp-history) page: install it from there
with the CurseForge app to keep it up to date. A release candidate shows on CurseForge as a beta file.

Built for Retail WoW. Releases marked **Pre-release** are release candidates.

**Updating:** exit the game, delete the old `WowPvpHistory` folder, and unzip the new one in its place.
Your history isn't stored in that folder, so it's kept.

## Use

After a match, open your history any of these ways:

- type `/pvph`
- click the minimap button, or pick it from the addon menu beside the minimap
- bind a key under **Key Bindings**, in the **AddOns** section, under **PvP History**

The commands you'll use most:

| Command | What it does |
| --- | --- |
| `/pvph` | Opens the match history window |
| `/pvph show last` | Opens your newest match |
| `/pvph notes` | Opens the players window |
| `/pvph note <name> <text>` | Writes a note on a player |
| `/pvph options` | Opens the settings |
| `/pvph backup` | Backs up your history now |
| `/pvph status` | Shows the version and what's stored |
| `/pvph window reset` | Puts every window back on screen at its normal size |
| `/pvph help` | Lists every command |

The full list is on the [Commands](https://github.com/xenulive/wow-pvp-history/wiki/Commands) page.

## Documentation

The [wiki](https://github.com/xenulive/wow-pvp-history/wiki) covers every window and setting:

- [Getting started](https://github.com/xenulive/wow-pvp-history/wiki/Getting-Started), from installing
  it to your first saved match
- [Questions](https://github.com/xenulive/wow-pvp-history/wiki/Questions), short answers to what people
  ask most
- [Match history window](https://github.com/xenulive/wow-pvp-history/wiki/Match-History-Window)
- [Summary and rating graph](https://github.com/xenulive/wow-pvp-history/wiki/Summary-and-Rating-Graph)
- [Solo Shuffle](https://github.com/xenulive/wow-pvp-history/wiki/Solo-Shuffle)
- [Compositions](https://github.com/xenulive/wow-pvp-history/wiki/Compositions) and
  [Specs](https://github.com/xenulive/wow-pvp-history/wiki/Specs)
- [Ask](https://github.com/xenulive/wow-pvp-history/wiki/Ask)
- [Players and notes](https://github.com/xenulive/wow-pvp-history/wiki/Players-and-Notes)
- [Alerts](https://github.com/xenulive/wow-pvp-history/wiki/Alerts)
- [Duels and unfinished matches](https://github.com/xenulive/wow-pvp-history/wiki/Duels-and-Unfinished-Matches)
- [World PvP](https://github.com/xenulive/wow-pvp-history/wiki/World-PvP)
- [Settings and storage](https://github.com/xenulive/wow-pvp-history/wiki/Settings-and-Storage)
- [Commands](https://github.com/xenulive/wow-pvp-history/wiki/Commands)
- [Troubleshooting](https://github.com/xenulive/wow-pvp-history/wiki/Troubleshooting)
- [Words used here](https://github.com/xenulive/wow-pvp-history/wiki/Words-Used-Here), for MMR, comp,
  spec and the rest

## Limits

Blizzard decides what addons can see during a match. Who killed whom inside a match and crowd-control
breaks need the combat log, which addons can't use. Interrupts aren't saved, because the game's meter
misses casts stopped by crowd control; dispels are. Matches you leave early are saved without a roster,
and Solo Shuffle round winners are worked out rather than read, since the scoreboard doesn't show them.

Details are on [What it cannot record](https://github.com/xenulive/wow-pvp-history/wiki/What-It-Cannot-Record).

## Your data

Your history lives in the game's `WTF` folder, not in the addon:

- `WTF\Account\<account>\SavedVariables\WowPvpHistory.lua` holds matches, players, notes and settings,
  shared by all characters on the account.
- `WTF\Account\<account>\<realm>\<character>\SavedVariables\WowPvpHistory.lua` holds that character's
  backups and debug log.

Nothing is sent anywhere. An export contains the names of everyone you've played with, so keep exported
text private.

## Problems and feedback

Check [Troubleshooting](https://github.com/xenulive/wow-pvp-history/wiki/Troubleshooting) first. If that
doesn't help, [open an issue](https://github.com/xenulive/wow-pvp-history/issues) with your version
(`/pvph status`), the last error (`/pvph error`) and, if you can, the
[debug log](https://github.com/xenulive/wow-pvp-history/wiki/Debug-Log): turn it on with
`/pvph debug on`, repeat what went wrong, then copy it out with `/pvph debug export`.

## License

[MIT](LICENSE), copyright 2026 Xenu-Sentinels ([xenu.live](https://xenu.live)).

The bundled Barlow Semi Condensed and IBM Plex Mono fonts are under the
[SIL Open Font License](WowPvpHistory/fonts/OFL.txt).

World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or
endorsed by Blizzard.
