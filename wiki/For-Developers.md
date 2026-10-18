# For developers

This page is for working on the addon or testing it. You never need anything here to use the addon.

## Layout and speed

`/pvph region`, `/pvph faults`, `/pvph debug fault`, `/pvph window rect` and `/pvph perf` report on the
window's layout and on how much of each frame the addon takes.

| Command | What it does |
| --- | --- |
| `/pvph repaint full` or `lean` | Whether switching between views skips work it doesn't need. `lean` is the normal way; bare prints how long the last switch took |

## Driving the windows by typing

These do by typing what you'd normally do with the mouse, so a test script can drive the windows. The
ones that change a setting hold it only until you log out or reload.

| Command | What it does |
| --- | --- |
| `/pvph window menu <id\|last> [open\|note\|roster\|print\|result <win\|loss\|draw>]` | Opens the [right-click menu](Match-History-Window#the-right-click-menu) on a match in the list, or runs one of its entries |
| `/pvph window hover [<id\|last>]` | Shows the [`Shift` tooltip](Match-History-Window#the-tooltip) on a match in the list. Bare, hides it |
| `/pvph window dropdown [character\|scope\|result\|spec]` | Opens that dropdown's list: the character, the time range, the result or the spec. Bare, closes it |
| `/pvph window tile [rate\|matches\|mmr\|length\|last]` | Shows the hover on one of the figure cards, which **Stats** draws in place of the strip only where the strip could not be read. Elsewhere it says the card isn't drawn. Bare, hides it |
| `/pvph window grip [hover]` | Shows the history window's resize corner as it looks with the pointer over it. Bare, puts it back |
| `/pvph window round [n]` | Shows the hover over round `n` in your newest match window's [round table](Solo-Shuffle#the-round-table). Bare, hides it |
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
| `/pvph debug fixture healer` | Makes the made-up Solo Shuffles from a healer's point of view. `damage` is the usual one |
| `/pvph debug fixture samespec` | Puts two players on the same spec in the made-up Solo Shuffles |
| `/pvph debug fixture unrated` | Adds only made-up matches that move no rating |
| `/pvph debug announce <id\|last>` | In the sandbox, shows the names at the start of that match |
| `/pvph debug tooltip [name]` | In the sandbox, shows that player's tooltip lines. Bare, hides them |
| `/pvph debug group <name> [name ...]` | In the sandbox, prints the group alert as if those players had joined |
| `/pvph debug gates <id\|last>` | In the sandbox, prints the line for your side at the start of that match |

Outside the sandbox, `/pvph debug fixture` works only while the [debug log](Debug-Log) is on, and adds
the made-up matches to your own history.
