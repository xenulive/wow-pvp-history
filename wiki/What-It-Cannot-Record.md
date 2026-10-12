# What it cannot record

The game decides what an addon is allowed to see, especially during a match. These are the limits that
come from the game rather than from a setting, so there's nothing to turn on for them.

## Not available at all

- **Who killed whom inside a match, and crowd control breaks.** These would need the game's combat log,
  which addons aren't allowed to use. Each player's total killing blows are saved, from the scoreboard.
- **Interrupts.** The game's damage meter only counts a cast stopped by an interrupt spell, not one
  stopped by a stun or a fear, so a player who stops casts with crowd control would read zero. The addon
  doesn't save them rather than show that zero. Dispels are saved, in the **DISP** column of a
  [match's window](Match-History-Window#one-match-in-its-own-window).
- **World PvP with War Mode off.** The open world has no PvP to count without it. See
  [World PvP](World-PvP).

## Saved, with less detail

- **Matches you leave early** don't have a list of players, because the game only reveals it when a
  match finishes. The format is saved where the addon could read it before you left. See
  [Duels and unfinished matches](Duels-and-Unfinished-Matches).
- **Solo Shuffle round winners** aren't shown on the scoreboard, so the addon works them out. A few rounds
  can't be settled. See [Solo Shuffle](Solo-Shuffle).
- **Duels** are only saved when the game prints the result in chat.
- **World PvP kills** are counted from the game's own honorable kill count, which says how many and not
  who. See [World PvP](World-PvP).

## Saved, but not tested

- **Who you killed in World PvP.** The addon tries to name the player you landed the killing blow on,
  but whether the game lets it read who they were hasn't been checked yet.
- **Rated battlegrounds** are recorded like any other battleground, but they're hard to get into, so
  whether they're recorded correctly hasn't been checked.
- **Rated 3v3 arena** is recorded the same way as rated 2v2, but the addon hasn't yet seen one, so
  whether it's filed under **Arena (3v3)** rather than the plain **Arena** hasn't been checked. An
  unrated 3v3 skirmish is recorded and has been checked.
