# Ask

The lower half of the **Stats** tab answers up to four questions about what you have played, so you
don't have to read the list yourself. Each tab shows only the questions its matches can answer. The
cards stand at the left, and the card you have lit fills the right with the table behind its answer.
**WORST COMP** draws the [composition table](Compositions).

Pick a tab, then click **Stats** under the window. A tab with nothing the questions can rank, such as
**All**, shows its own figures there instead: see [The All tab](Summary-and-Rating-Graph#the-all-tab).
**World PvP** shows **WHERE YOU FIGHT** in their place: see [World PvP](World-PvP#where-you-fight).

![The Stats tab on Solo Shuffle with What beats me lit: the four cards at the left, and the specs you meet with the matches behind the top one at the right](images/specs-view.png)

## What the answers are read over

The line above the cards reads **OVER**, then the kind of match, then how many matches that comes to.

The time range is the same setting as the
[dropdown beside **Graph** and **Details**](Summary-and-Rating-Graph#choosing-a-time-range): change it
in either place and both follow. The [character dropdown](Match-History-Window#showing-one-character)
in the title bar narrows the answers too.

## The four questions

Each question is a card, with an edge down its left side in your win or loss color. The question is its
heading, and the answer is under it: a spec as its icon and its name in its class color, a team
composition as its specs side by side, or a map. Under the answer is your win rate in color with your
record beside it, and the line under them says how many rounds or matches it was taken over. Click a card
to see the whole table behind it on the right.

| Question | What it answers |
| --- | --- |
| **WHAT BEATS ME** | The opponent spec you win least against |
| **BEST TEAMMATE** | The teammate spec you win most with |
| **WORST COMP** | The team composition you do worst against. Its table is the one described under [Compositions](Compositions) |
| **WHERE I LOSE** | The map you lose on most |

Which questions a tab shows:

| Tab | Questions |
| --- | --- |
| Solo Shuffle, the arena tabs and **Skirmish** | All four. On **Skirmish**, **WORST COMP** ranks the teams you meet there |
| The battleground and Blitz tabs | **WHAT BEATS ME**, **BEST TEAMMATE** and **WHERE I LOSE** |
| **Shuffle Brawl** | **WHERE I LOSE** |
| **Other** | All four, though only **WHERE I LOSE** fills: the other three stay empty there |
| **Duel** | **WHAT BEATS ME**, ranking the classes you duel under **THE CLASSES YOU MEET**, and **WHERE I LOSE** |

On Solo Shuffle a spec is counted on each side round by round. On every other tab it's counted once per
match, and the table's count column reads **GAMES**.

### Only rows with enough games are ranked

A row is ranked once it has enough games behind it to mean something:

- a spec, once it's been in **20 rounds**, or on a tab without rounds **20 decided matches**
- a team composition, once you've met it **10 times**, each Solo Shuffle round or arena match counting
  once
- a map, once it's had **8 decided matches**

A line under each table counts the rows that haven't reached it yet, such as `3 specs under 20 rounds`.

**A card only names a row that answers its question.** **WORST COMP**, **WHAT BEATS ME** and **WHERE I
LOSE** name a composition, spec, class or map you've lost to at least as often as you've beaten it, and
**WHAT BEATS ME** and **WHERE I LOSE** also need it to have beaten you at least once. **BEST TEAMMATE**
names a spec you've won more with than lost. **WHERE I LOSE** can name a map even when it's the only one
with enough matches.

**Where nothing qualifies, the card shows a dash.** Rest the pointer on it to see how many rounds or
matches a row needs to be ranked, such as `Comps met in 10 or more rounds are ranked`, and, where rows
are ranked but none fits, a line saying so. The table under it still lists every ranked row.

## The answer table

Each table is headed with what it ranks: **THE SPECS YOU MEET** for **WHAT BEATS ME**, **THE SPECS
BESIDE YOU** for **BEST TEAMMATE**, **THE COMPS YOU MEET** for **WORST COMP**, **WHERE YOU PLAY** for
**WHERE I LOSE**, and **EVERY MAP** on the Maps view.

| Column | What it shows |
| --- | --- |
| **SPEC** or **MAP** | The spec or the map |
| **ROUNDS** or **DECIDED** | How many rounds, or how many matches with a result |
| **W-L** | Your wins and losses, with a bar beside them in your win and loss colors |
| **YOU WON** | Your win rate, in the win color above half and the loss color under it |

**YOU WON** is your own win rate over those games, not that spec's.

**Click a column heading to sort by it**, and click it again to turn the order around. Each question
starts with its answer at the top. A sort lasts until you log out or reload.

## The matches behind a row

Click a row to list the matches it was counted over, under the table, headed **MET IN** (or
**PLAYED ON** for a map): how many there were, then one line per match. Under a spec, the matches have their own headings, **MATCH**,
**WHEN**, **WHERE**, **ROUNDS**, **CHANGE** and **RATING**: the date, the map beside the six round
squares and the rounds you won, such as `4 of 6`, your rating change in color and your rating in its
tier color. Click a match to open its window, and you stay on the
question you asked. Click the row again to close the list. Changing the question, the tab or the time
range closes it too.

## The Maps view

The row of controls on **Stats** keeps one order on every tab: **Graph**, **Specs**, **Maps**,
**Builds**, **Bests** and **Details**, each shown only where the tab offers it.

**Maps** lists every map you've played on the tab in place of
the cards: **MAP**, **DECIDED**, **W-L** and **YOU WON**, best first. A map with fewer than 8 decided
matches sorts after the others, grayed, and a map with no decided match at all has a dash for its rate.
Click a heading to sort by it. While it's showing, **Maps** is the one control lit in that row. Click
**Maps** again to go back to the cards. Your choice is remembered after a reload, and
`/pvph show <tab> stats maps` opens it for the session. On **Duel** and **Other**,
**Maps** shows only where the tab holds two maps or more, and **World PvP** doesn't offer it.

![The Maps view on Solo Shuffle: each map with its decided matches, W-L and win rate, best first, over made-up matches](images/maps-view.png)

## The Builds view

**Builds** lists each talent build you played on the tab in place of the cards, under **YOUR BUILDS**,
or **YOUR BUILDS, BY SPEC** where you played more than one spec there:
**BUILD**, named by its saved loadout and hero tree with your PvP talent icons after it, from the newest
match you played it in, then **MATCHES**, **W-L** and **YOU WON**, the build you played most first.
Where the tab holds more than one of your specs, each build names its spec too. Two builds with the same
loadout name and hero tree are numbered, the second reading such as `Arena 2, Herald of the Sun`. A build
with no saved loadout reads `No loadout name` in gray. Click a build to list the matches you played it in, under
**PLAYED WITH**, and click a match to open its window. Matches saved before the addon kept builds are
counted in one line under the table. Click **Builds** again to go back to the cards, and
`/pvph show <tab> stats builds` opens it for the session. **Duel** and **World PvP** don't offer it.

## The Bests view

**Bests**, beside **Builds**, lists your best match for each spec you played on the tab, under
**YOUR BESTS, BY SPEC**: top **DAMAGE**, top **HEALING**, **PEAK RATING**, **PEAK MMR** and
**FASTEST WIN**. The figure columns sit together beside **SPEC**, each as wide as its longest figure,
and the rating columns show only where the tab has rated matches. Click a figure to open the match it
was set in. Click a spec to list the matches that hold its bests, under **BESTS SET IN**, and click a
match to open its window. Click
**Bests** again to go back to the cards, and `/pvph show <tab> stats bests` opens it for the session.
`/pvph bests` prints the same table in chat, one line per spec, and a format word picks the tab, such as
`/pvph bests shuffle`. **Duel** and **World PvP** don't offer it.

After a match that beats one of your bests for that spec, a line in chat names it, such as
`new best: damage 4.2M`. It waits until you have five earlier matches of that format on that spec.

## When a question has nothing to say

The table is empty and the note under it reads `none yet`. If an answer couldn't be worked out at all,
it shows a dash. `/pvph ask` says in chat why a question has nothing.

## In chat

`/pvph ask` prints the same **OVER** line and one line per question, with its answer or a note that it
has none. Add a format word, such as `/pvph ask shuffle`, to ask about one format without opening the
window. The format words are on the [Commands](Commands) page.
