# Commands

Type `/pvph help` or `/pvph commands` in game to list these. `/pvphistory` and `/wowpvphistory` work
the same as `/pvph`. A mistyped command suggests the nearest one.

In the tables, `<id>` is a match number, `<name>` is a player's name, and anything in `[brackets]` is
optional.

## The ones you'll use most

Most players only ever need these. Everything else on this page is optional.

| Command | What it does |
| --- | --- |
| `/pvph` | Opens your match history |
| `/pvph show last` | Opens your newest match |
| `/pvph notes` | Opens the players window, for your notes on people |
| `/pvph options` | Opens the settings |
| `/pvph window reset` | Puts every window back on screen at its normal size |
| `/pvph help` | Lists the commands in game |

## Windows

| Command | What it does |
| --- | --- |
| `/pvph` | Opens the [match history window](Match-History-Window) |
| `/pvph show <id>` | Opens one match in its own window, or closes it if it's already open |
| `/pvph show last [format]` | Opens your newest match in its own window, or your newest of one [format](#format-words) |
| `/pvph show <words>` | Opens the match history window on a tab, a half, a card and a time range, in any order: `all` or a [format word](#format-words); `matches` for **History** or `stats` for **Stats**; `beats`, `where`, `worth` or `comp` to light one of the [Ask](Ask) cards, or `comps`, `specs`, `maps`, `builds`, `bests` or `ask`; `season`, `season<n>` for an earlier season, `alltime`, `180d`, `90d`, `30d`, `7d`, `3d` or `1d`. Your saved tab and range don't change |
| `/pvph notes` | Opens the [players window](Players-and-Notes) |
| `/pvph notes last` | Opens the players window on the players from your latest match |
| `/pvph notes #<id>` | Opens the players window on the players from one match |
| `/pvph window player <name>` | Opens [one player's window](Players-and-Notes#one-player) |
| `/pvph window close` | Closes every match window and player window |
| `/pvph incomplete` | Opens the match history window on the **Other** tab, which holds matches you [left early](Duels-and-Unfinished-Matches) |
| `/pvph scoreboard` | Says which order the match window's roster and the Solo Shuffle table are in |
| `/pvph scoreboard sort <word> [up\|down]` | Sorts the match window's tables, as clicking a heading does, until you log out or reload. The words are `name`, `damage`, `healing`, `kb`, `dispels`, `objective`, `swing` and `wins` |
| `/pvph options` | Opens the [settings](Settings-and-Storage), or closes the window if they are already showing |
| `/pvph options <page>` | Opens them on one page: `general`, `alerts`, `notes`, `recording`, `data` or `diagnostic`. The older words still work: `window` and `minimap` open **General**, `history` opens **Recording**, `storage` opens **Data and backups**, and `all` opens **General** or the page of the word after it |
| `/pvph options client` | Opens the addon's page in the game's own settings |
| `/pvph about` | Opens the window on **About**. `/pvph about copy` also opens the website's copy box |
| `/pvph card [name]` | Shows the [group finder's card](Alerts#in-the-group-finder) for a name. Bare, hides it |

## In chat

| Command | What it does |
| --- | --- |
| `/pvph <id>` | Everything about one match, with both teams' MMR, yours first |
| `/pvph last [format]` | Everything about your newest match, or your newest of one [format](#format-words) |
| `/pvph list [format]` | Your matches, newest first |
| `/pvph summary [format]` | Your win rate, rating, match length and counts |
| `/pvph summary <format> <season>` | The same, for one season |
| `/pvph comps [format] [row]` | The [compositions](Compositions) you've faced, hardest first. Add a row number to see the games behind it |
| `/pvph ask [format]` | The four questions the [Ask](Ask) cards answer, over the time range you picked |
| `/pvph bests [format]` | Your [bests](Ask#the-bests-view) for each spec on a tab: damage, healing, peak rating and MMR, and fastest win |
| `/pvph search <text>` | Narrows the [match list](Match-History-Window#searching-and-filtering) to matches whose players, specs or map carry every comma-separated term. `-` or `!` in front of a term leaves it out. With no text, clears it |
| `/pvph filter result <all\|won\|lost\|even>` | Narrows the match list by result |
| `/pvph filter spec <spec\|all>` | Narrows it to the spec you played. `/pvph filter` alone prints the choices and the count |
| `/pvph filter zone <zone\|all>` | Narrows the [World PvP](World-PvP#the-world-pvp-tab) list and its strip to one zone |
| `/pvph meter [id]` | How many dispels each player cast in your newest match, or in one match, and round by round in a Solo Shuffle |
| `/pvph season` | What the game reports about the season, and its count of your rated matches beside the addon's |
| `/pvph tiers` | Each rated format's tiers and the rating each one starts at |
| `/pvph left` | Matches you left early |
| `/pvph players` | Everyone you've played with and against, most matches first |
| `/pvph player <name>` | One player in full |
| `/pvph status` | The addon's version, how much it holds, and your last match |
| `/pvph size` | How much space your history uses and how much is left |

## Notes, reps and tags

| Command | What it does |
| --- | --- |
| `/pvph note <name> [text]` | Writes a note on a player. Leave out the text to clear it |
| `/pvph rate <name> [+2 \| +1 \| 0 \| -1 \| -2]` | Sets a player's rep, from **Strong** at `+2` to **Bad** at `-2`. `+` is the same as `+1` and `-` the same as `-1`. Leave out the value to clear it |
| `/pvph tag <name> <tag> [tag ...]` | Adds tags to a player |
| `/pvph untag <name> [tag ...]` | Removes tags. Leave out the tags to remove all of them |
| `/pvph tags` | Every tag you've used, most used first, and how many players carry one |
| `/pvph roster <id> tag <tag> [tag ...]` | Tags everyone from one match at once. `untag` and the tags removes them, and `untag confirm` removes every tag |
| `/pvph notes sort <recent\|met\|rep\|player\|with\|against> [up\|down]` | Sorts the players list, as clicking a heading does, until you log out or reload. `up` or `down` sets the direction |
| `/pvph notes rep <bad\|negative\|neutral\|positive\|strong\|none\|off>` | Lists only the players with one rep. `off` lists everyone again |
| `/pvph notes format <format\|all>` | Lists only the players you met in one format |
| `/pvph notes side <with\|against\|all>` | Lists only the players you met on one side |
| `/pvph notes search [text]` | Searches the players list, as its search box does. With no text, clears it |
| `/pvph edit <id>` | Says what can be filled in for a match. Anything you enter is marked as entered by hand |
| `/pvph edit <id> result [win\|loss\|draw]` | Fills in a result the addon couldn't record. Leave out the result to clear it |
| `/pvph edit <id> note [text]` | Writes a note on a match. Leave out the text to clear it |
| `/pvph edit left <n> reason [reason]` or `note [text]` | Sets why you left a match early, or writes a note on it. Leave out the reason to clear it. `<n>` is the number the window shows, `L1`, or `#1` or `1`. The reasons are `disconnect`, `crash`, `client-closed`, `chose-to-leave` and `kicked` |

## Switches

Each of these takes `on` or `off`. Typed alone, a switch turns to the other state unless the table says
otherwise.

| Command | What it switches |
| --- | --- |
| `/pvph alert` | The chat line when your group changes or a match ends |
| `/pvph groupnotes` | Your rep and note on whoever joins your group |
| `/pvph announce` | Names across the screen at the start of a match, and when somebody you know joins your group |
| `/pvph sight` | [Marking somebody you wrote about](Alerts#when-someone-you-wrote-about-appears) when they appear. Bare, says whether it's on and how many are marked |
| `/pvph chatmark` | [The bar before the name](Alerts#in-chat) of somebody you wrote about when they talk in chat. Bare, says whether it's on. `/pvph chatmark sample` prints the colors it draws in |
| `/pvph postgame` | The lines after a match or a duel. A line reporting a fault still prints |
| `/pvph aftermatch` | Opening a match's window once you leave it. Bare, says whether it's on and whether a match is waiting |
| `/pvph closeall` | Closing every match window and player window when you close the main window. `/pvph closeall on` turns it on and `/pvph closeall off` turns it off; bare, says whether it's on and how many match and player windows are open |
| `/pvph overlay` | The [recent results bar](Match-History-Window#the-recent-results-bar). Bare, prints its settings |
| `/pvph finder` | The season record [in the group finder](Alerts#in-the-group-finder). `on` and `off` last until you log out or reload; bare, says what the last look decided |
| `/pvph finder dock`, `undock` or `reset` | `dock` and `undock` fix the season record above the finder or free it to drag, until you log out or reload. `reset` forgets where you dropped it |
| `/pvph tooltip` | Your notes on player tooltips |
| `/pvph menu` | The addon's section in the right-click menu |
| `/pvph duel` | Recording duels. Bare, says whether duels are recorded |
| `/pvph hold` | Holding the leave button while the scoreboard is read. Bare, says whether it's on and for how long it holds |
| `/pvph login` | Naming the addon's version when you log in |
| `/pvph debug` | The [debug log](Debug-Log) |
| `/pvph debug text` | Extra technical detail on a match |

| Command | What it does |
| --- | --- |
| `/pvph announce preview` | Holds a sample up so you can drag it. `preview full` holds a long sample of fifteen |
| `/pvph announce reset` | Puts the names back in their original place |
| `/pvph announce time [50-300]` | How long the names stay up, as a percentage. Bare, says what a full banner lasts |
| `/pvph announce size [75-150]` | How large the names are drawn, as a percentage. Bare, says the size it drew at |
| `/pvph announce opacity [0-100]` | How dark each name's panel is |
| `/pvph overlay count <4-10>`, `opacity <0-100>`, `combat on` or `off` | Settings for the recent results bar |
| `/pvph hold preview saving [seconds]`, `saved` or `off` | Shows the cover that holds the leave button, without a match |
| `/pvph minimap [show\|hide]` | Shows or hides the minimap button. Bare, switches it to the other state. `reset` puts it back in its place, and `where` says where it is, in whole degrees around the minimap's edge such as `243°` |
| `/pvph tab remember` or `all` | Whether the window opens on your last tab or on **All** |
| `/pvph window [reset]` | Each window's size and where it sits. `reset` puts every window back at its normal size and place |
| `/pvph window size [players] <width> [height]` | Sizes the match history window and the players window, which share one size, until you log out or reload. Each figure is a number, `min`, `max`, `authored` or `same`; one figure sizes both |
| `/pvph window size match <width> [height]` | Sizes your newest match window, until you log out or reload. It doesn't change the size the next one opens at |
| `/pvph window size player <width> [height]` | Sizes your newest player window the same way |
| `/pvph window scale [70-150]` | Draws every window at that percentage until you log out or reload, without changing your **Scale** setting. `reset` goes back to your setting, and bare says the scale they draw at |

## Backups and moving your history

| Command | What it does |
| --- | --- |
| `/pvph backup` | Backs up your history now |
| `/pvph restore` | Shows what the backup holds. `confirm` replaces your history with it |
| `/pvph restore pinned` | The copy kept when you last erased everything. `confirm` brings it back |
| `/pvph reset` | Shows what erasing everything would remove. `confirm` does it |
| `/pvph export` | Your whole history as text to copy out of the game |
| `/pvph import` | Paste that text back in |
| `/pvph export csv [format] [since YYYY-MM-DD] [last <n>] [part]` | Your history as a spreadsheet file |
| `/pvph import csv [force]` | Paste a CSV back in. Adds new matches and skips ones you have |
| `/pvph rebuild` | Rebuilds the players list from your saved matches |

## Reporting problems

| Command | What it does |
| --- | --- |
| `/pvph debug show [category] [n]` | Prints the debug log |
| `/pvph debug clear [category]` | Empties the debug log |
| `/pvph debug export` | The debug log as text to copy out |
| `/pvph error` | The last error the addon hit, and when. `clear` forgets it |
| `/pvph window store` | Opens the panel that checks your history, its backup and the players list |

## Trying the windows on made-up matches

`/pvph debug sandbox` sets your history aside for the rest of the session and shows an empty one in its
place, so you can fill it with made-up matches and players and look around. Your own history is
untouched, and a `/reload` or a match starting puts it back. Restoring, importing and erasing are
refused while the sandbox is up.

| Command | What it does |
| --- | --- |
| `/pvph debug sandbox` | Starts the sandbox |
| `/pvph debug fixture [n]` | Adds made-up matches, so you can see the windows before you've played |
| `/pvph debug fixture clear` | Shows what removing them would do. `confirm` removes them and keeps your notes |

## For developers

Commands for working on the addon or testing it are on their own page,
[For developers](For-Developers). You never need them to use the addon.

## Format words

Commands that take a format use these words. A word you have no matches in is refused, and the reply
names the formats you do have.

| Word | Format |
| --- | --- |
| `arena` | Arena, where the team size wasn't recorded |
| `arena2` | Arena (2v2) |
| `arena3` | Arena (3v3) |
| `arena-unrated` | Skirmish |
| `shuffle` | Solo Shuffle |
| `shuffle-unrated` | Shuffle Brawl |
| `blitz` | Battleground Blitz |
| `blitz-unrated` | Blitz Brawl |
| `bg` | Unrated Battleground |
| `rbg` | Rated Battleground |
| `duel` | Duel |
| `world` | World PvP |
| `unknown` | Other |
