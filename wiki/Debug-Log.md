# Debug log

Besides your match history, the addon keeps a log of what it did and why: each match it recorded, each
change you made, each window it opened, and any error it hit. It's there so that when something goes
wrong, there's a record of what happened.

The log never contains player names, realms, or anything that identifies another player. It's kept in
each character's own saved file, separate from your history.

**Whether the log starts on depends on where you got the addon.** The download from the releases page starts with it off. Once you turn it on or off yourself, your choice stays either way. Once on, it keeps a limited number of entries in each part and drops the oldest, and something that keeps
happening is counted on one entry rather than written again, so it's fine to leave on.

## Turning it on or off

- `/pvph debug on` or `/pvph debug off`
- the **Debug ring** checkbox under **DIAGNOSTIC** in the [settings](Settings-and-Storage)

## Reading it

The log has four parts:

| Part | What it holds |
| --- | --- |
| `capture` | Matches being recorded: when they started and ended, and anything that stopped one being saved |
| `data` | Changes you made: notes, ratings, settings, backups |
| `ui` | Windows opened and commands typed |
| `error` | Anything that went wrong |

- `/pvph debug show` prints recent entries. Add a part name to see only that part, and a number for how
  many, such as `/pvph debug show error 10`.
- `/pvph debug clear` empties the log, or one part of it if you name it.
- `/pvph debug export`, or **Copy** on **The ring** in the settings, gives you the log as text to
  copy.

## Other diagnostic tools

- `/pvph error` shows the last error and when it happened. `/pvph error clear` forgets it.
- `/pvph status` shows the addon's version, what it holds, and your last match.
- **Open** on **Read the state of the store** in the settings opens a small panel checking your history, its
  backup, and the players list. It only appears while the log is on. `/pvph window store` opens the
  same panel.
- **Debug detail on screen** (or `/pvph debug text on`) adds technical details to each match in the
  history window. Turn it off with `/pvph debug text off`.

## Reporting a problem

1. If the log is off, type `/pvph debug on`, then do what caused the problem again. The log only holds
   what happened while it was on.
2. Write down what you were doing and roughly when.
3. Type `/pvph error` and note what it says.
4. Collect the log with `/pvph debug export` and include it in your report.
