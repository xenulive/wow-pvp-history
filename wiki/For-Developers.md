# For developers

This page is for working on the addon or testing it. You never need anything here to use the addon.

## Layout and speed

`/pvph region`, `/pvph faults`, `/pvph debug fault`, `/pvph window rect` and `/pvph perf` report on the
window's layout and on how much of each frame the addon takes.

| Command | What it does |
| --- | --- |
| `/pvph region list` | The History list's edges, and where each element it draws stands |
| `/pvph region band` | Where the History search box, its count and the three filters stand |
| `/pvph faults verbose` | The same check as `/pvph faults`, naming every family it checked even when none fails |
| `/pvph perf trace` | How long one debug log write takes; typed again after a switch, how many writes the switch made |
| `/pvph repaint full` or `lean` | Whether switching between views skips work it doesn't need. `lean` is the normal way; bare prints how long the last switch took |
| `/pvph window rect compare` or `menu` | Where the [Compare window](Match-History-Window#comparing-matches), or the open right-click menu on a match row, sits on screen, in pixels |
| `/pvph compare rows` | Prints each row the Compare window's **Figures** tab draws: every match's value with its difference from the base, `(0)` where it equals the base, and which matches are best, then the rows left out and the `SAME IN ALL` line. With the second tab open it also prints each match's rounds, each spec's row of the lobby table and the **shared with base** line |

## Driving the windows by typing

These do by typing what you'd normally do with the mouse, so a test script can drive the windows. The
ones that change a setting hold it only until you log out or reload.

| Command | What it does |
| --- | --- |
| `/pvph window menu <id\|last\|draw\|typed\|short> [open\|note\|roster\|print\|compare\|talents\|result <win\|loss\|draw>]` | Opens the [right-click menu](Match-History-Window#the-right-click-menu) on a match in the list, or runs one of its entries. `compare` picks the match or takes it out, as the **Compare** entry does |
| `/pvph window menu close` | Closes an open right-click menu, as a click away from it does |
| `/pvph compare box <id\|last [n]>` | Presses a match row's pick box, as a click on it does, a refused one included; `last n` is the `n`th newest row of the newest match's type |
| `/pvph compare add last [n]` | Picks the newest match the list shows for [comparing](Match-History-Window#comparing-matches), after its search and filters, or the `n`th newest |
| `/pvph compare` | Says how many matches are picked, their format, which one is the base, each match number in the window's order, which tab the Compare window shows, and how many picked, empty and faint boxes the list last drew |
| `/pvph compare add <id>` | Picks a match |
| `/pvph compare remove <id>` | Takes a picked match out |
| `/pvph compare clear` | Takes every picked match out |
| `/pvph compare open` | Opens the Compare window. It needs two picked matches |
| `/pvph compare base <id>` | Makes a picked match the base, the leftmost column |
| `/pvph compare tab <figures\|rounds>` | Opens the Compare window's **Figures** tab, or with `rounds` its second tab, **Rounds and lobby** or **Lobby**. A duel or a World PvP outing has no second tab, and the word says so |
| `/pvph compare close` | Closes the Compare window and keeps your picks |
| `/pvph window scroll top` | Scrolls the match list back to the top |
| `/pvph window scroll overview [top\|bottom]` | Moves the All tab's Stats page to its top or its bottom, or with no place prints where it is scrolled to. Off that page it says so and moves nothing |
| `/pvph session [<n> <open\|shut>]` | Lists the sessions in the match list. With a number, counting from the newest, opens or folds that session until you log out or reload |
| `/pvph ask sort <question> <met\|won\|default>` | Sorts one of the Ask tables, as clicking its heading does. The questions are `beats`, `where`, `worth` and `comp` |
| `/pvph ask open [n]` | Opens row `n` of the lit card's table. With no number, closes it |
| `/pvph ask under <on\|off>` | Lists the rows that haven't reached the bar after the ranked ones, until you log out or reload |
| `/pvph ask specs <on\|off>` | Shows the [spec table](Specs) in place of the cards, until you log out or reload. `/pvph ask specs sort` with `spec`, `rounds-against`, `wl-against`, `won-against`, `rounds-with`, `wl-with`, `won-with` or `default` sorts it |
| `/pvph fold <graph\|details> <open\|shut>` | Folds the graph or the **Details** lines until you log out or reload |
| `/pvph overlay preview [format]` | Holds the bar up for this session, on one format if you name it. `preview off` takes it down, and `preview opacity <0-100>` tries a background |
| `/pvph appearance game`, `dark` or `stored` | Tries a window appearance until you log out or reload. `stored` goes back to your setting |
| `/pvph window hover [<id\|last\|left>]` | Shows the [`Shift` tooltip](Match-History-Window#the-tooltip) on a match in the list, or with `left` on the newest match left early. Bare, hides it |
| `/pvph window dropdown [character\|scope\|result\|spec]` | Opens that dropdown's list: the character, the time range, the result or the spec. Bare, closes it |
| `/pvph window tile [rate\|matches\|mmr\|length\|last]` | Shows the hover on one of the figure cards, which **Stats** draws in place of the strip only where the strip could not be read. Elsewhere it says the card isn't drawn. Bare, hides it |
| `/pvph window grip [hover]` | Shows the history window's resize corner as it looks with the pointer over it. Bare, puts it back |
| `/pvph window round [n]` | Shows the hover over round `n`'s card in your newest match window, as on the [Solo Shuffle](Solo-Shuffle#at-the-top) page. Bare, hides it |
| `/pvph window click [players] <name> [shift\|ctrl\|alt\|shift-alt\|ctrl-alt]` | Clicks a player's name in your newest match window, or in the players window with `players`. A modifier [adds the name or spec to the search](Match-History-Window#one-match-in-its-own-window) instead |
| `/pvph options find [words]` | Types into the settings' find box until you log out or reload. Bare, clears it |
| `/pvph options slot <latest\|pinned>` | Chooses which copy the backup card reads, until you log out or reload |
| `/pvph options close` | Closes the window from the settings, as Escape does |
| `/pvph overlay hover <n>` | Shows the tooltip of square `n` on the recent results bar. `hover off` hides it |
| `/pvph announce shape side`, `column` or `stored` | Tries a shape for the names at the start of a match until you log out or reload. `stored` goes back to the one set in the settings |
| `/pvph announce unlock`, `lock` or `lock stored` | Unlocks or locks those names for dragging until you log out or reload. `lock stored` goes back to the setting |

## Test data

The sandbox and the plain fixture are on [Commands](Commands#trying-the-windows-on-made-up-matches).
These shape the made-up matches and show what the alerts would do with them.

| Command | What it does |
| --- | --- |
| `/pvph debug fixture healer` | Makes the made-up Solo Shuffles from a healer's seat, played by the second made-up character in Holy, since the first is a Demonology Warlock. `damage` is the usual one |
| `/pvph debug fixture samespec` | Puts two players on the same spec in the made-up Solo Shuffles |
| `/pvph debug fixture unrated` | Adds only made-up matches that move no rating |
| `/pvph debug fixture winning` | Wins every round of the made-up Solo Shuffles |
| `/pvph debug announce <id\|last>` | In the sandbox, shows the names at the start of that match |
| `/pvph debug tooltip [name]` | In the sandbox, shows that player's tooltip lines. Bare, hides them |
| `/pvph debug group <name> [name ...]` | In the sandbox, prints the group alert as if those players had joined |
| `/pvph debug gates <id\|last>` | In the sandbox, prints the line for your side at the start of that match |

Outside the sandbox, `/pvph debug fixture` works only while the [debug log](Debug-Log) is on, and adds
the made-up matches to your own history.
