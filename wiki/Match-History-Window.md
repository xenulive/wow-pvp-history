# Match history window

This is the main window. It lists every match you've finished, grouped into the sessions you played
them in, and clicking one opens a window of its own with everything about that match: the result, the
map, how long it took, your rating change, and everyone who played.

Open it with `/pvph`, the minimap button, the addon menu beside the minimap, or a key binding. To jump
straight to one match, type `/pvph show` and the match number.

![The match history window on the All tab: the format tabs, your rating in each format, the search row and today's session opened under the session list](images/history-window.png)

## The title bar and the foot

The dropdown at the top right shows one character at a time. See below.

The line along the bottom of the window reads the addon's tagline at the left, and its name and version
at the right.

## The tabs under the window

Five tabs hang under the window's bottom edge: **History**, **Players**, **Stats** and **About** at
the left, and **Settings** at the bottom right. The tab you are on is drawn chosen and can't be clicked.

- **History** is the list of your matches, which is most of this page.
- **Players** is the [players window](Players-and-Notes).
- **Stats** holds the figures, the rating graph and the questions the addon answers about what you
  have played. See [Summary and rating graph](Summary-and-Rating-Graph), [Compositions](Compositions),
  [Specs](Specs) and [Ask](Ask).
- **About** is described [below](#about).
- **Settings** is the [settings](Settings-and-Storage). They are a part of this window, so they take
  the size you gave it.

**History** and **Stats** show the same tab, time range and character. **History** and **Players** share
one size and place: drag or resize either and the other follows, and the window opens on **History**.
On **About** and **Settings** the format tabs and the figures are hidden.

`/pvph options` and the **Settings** entry in the minimap button's menu open the settings and, when
they are already showing, close the window. `/pvph about` opens **About**.

## Format tabs

There's a tab for each kind of match you've played, so a tab only appears once you've played that kind.
Each tab shows how many matches it holds.

- **All** is first and shows everything.
- Rated arena and rated Solo Shuffle come next, then their unrated versions, then battlegrounds.
- **Duel** and **World PvP** come after the battlegrounds. See
  [Duels and unfinished matches](Duels-and-Unfinished-Matches) and [World PvP](World-PvP).
- **Other** is last. Matches you left early end up here.

The window opens on whichever tab you used last. Type `/pvph tab all` to have it always open on **All**,
or `/pvph tab remember` to go back.

## Showing one character

If you play PvP on more than one character, the dropdown in the title bar lets you show just one of
them. It narrows everything in the window: the tabs, the figures, the graph, the list and the
compositions. **All Characters** shows everyone.

Each character in the dropdown shows how many matches it has. A character appears by name once you've
logged into it with the addon installed. Until then it's listed as **unresolved**, with its match
count.

A few matches you left early before version 0.2.1 can't be tied to a character, so they only count
toward **All Characters**.

The players window isn't affected by this dropdown.

## Your standing, above the list

A strip across the top of **History** shows where you stand on the tab you are on.

- **On All**, each rated format you've played gets a block: its name, your rating in the colour of
  your PvP tier, the change from your newest session beside it, and the tier's name under it. **WIN
  RATE** stands at the right, with your wins and losses under it. Where the blocks don't all fit, the
  ones you are Unranked in give way first.
- **On a rated tab**, one block shows your rating, its tier and your season high. Beside it, your
  newest 30 matches stand as bars above and below a centre line, then **MATCHES** with your average
  match length, **MMR GAP** with how far your matchmaking rating is from your rating, and at the right
  **WIN RATE**, or **ROUNDS WON** on Solo Shuffle. In a narrow window **MMR GAP** gives way first, then
  **MATCHES**.
- **On Duel and Other**, the strip has its own figures, described on
  [Duels and unfinished matches](Duels-and-Unfinished-Matches).
- **On a tab with no rating**, it shows your record and win rate and a square for each match.

A win rate reads green above 50%, red below and grey at exactly 50%. A drawn match is left out of both
the count and the rate, and named apart, such as `66-47, 3 drawn`.

![The Solo Shuffle tab's History: your rating, tier and season high, your newest matches as bars, MATCHES, MMR GAP and ROUNDS WON, then the list, over made-up matches](images/shuffle-history.png)

## The match list

Under the strip, your matches are grouped into sessions: matches played within an hour of each other
belong to one session. Each session is one line under a fixed row of headings.

- **SESSION** names when it was: `This afternoon`, `Tonight`, `Yesterday evening`, `Last night`, or an
  older day with its part, such as `Thu 1 Oct, evening`.
- **TIME** is when it started and ended. In a narrow window it moves under the session's name.
- **On All**, a column for each rated format you played shows your closing rating in its tier colour
  and the session's change. A dot means you didn't play that format in the session.
- **On a format tab**, **RATING** shows the same for that format, and **ROUNDS** on Solo Shuffle or
  **RECORD** elsewhere adds up the session. On World PvP, **RECORD** is your kills and deaths.
- **RESULTS** has a tick for each match, oldest first, in your win or loss colour, grey for a match
  with no winner, and amber for a match you left early.
- **MATCHES** counts them.

**Click a session to open it**, and click it again to fold it. The newest session starts open and the
older ones folded, and a session you open or fold stays that way after a reload. An open session lists
its matches under it, with a row of column headings. When you scroll an open session's matches up past
the top of the list, its line stays pinned there.

Where every session on a tab holds only one match, the list skips the sessions and lists the matches
under one row of headings, with **WHEN** saying the day.

**A season line stands between two seasons**, so you can see where one ended.

### Each match

Each match is one line. Which columns show depends on the tab:

- a small square for the spec you played
- **MATCH**, the match number. A match you left early is numbered `L1`, `L2` and so on.
- **FORMAT**, on **All** when the list holds more than one kind of match
- **RESULT**, with your faction's crest in front where the match had sides. A Solo Shuffle shows its
  six rounds as small marks under **ROUNDS** instead.
- **WHERE**, the map
- **AGAINST**, a small mark for each opponent in their class colour, or **LOBBY** on Solo Shuffle for
  the other five players
- **LENGTH**
- **CHANGE**, your rating change as a small bar and its figure, and **RATING**, your rating after the
  match in its tier colour

A Solo Shuffle you won three rounds of reads `3 of 6`. The **Skirmish** tab, and any tab where nothing
moves a rating, has no **CHANGE** or **RATING** column.

The columns spread across the whole width of the window. In a narrow window a long value, such as a
long map name, is cut short; the column headings never are.

The time range you pick (see [Summary and rating graph](Summary-and-Rating-Graph)) also decides which
matches the list shows. An empty list reads `No matches yet.` before you've played anything, and
`No matches.` when the tab or the time range leaves nothing to show.

### Searching and filtering

Four controls sit at the head of the list on every tab: a search box at the left, and three dropdowns
at the right, for the spec, the result and the time range, in that order.

**The search box** narrows the list to the matches whose players, specs or map carry every term you
type. Separate terms with commas. A spec is read together with its class, so `Frost Mage` finds a Frost
Mage and not a Frost Death Knight. Start a term with `-` or `!` to leave out the matches that carry it.
Accented letters and Cyrillic match whatever case you type them in. `/pvph search` and some text does
the same from chat, and `/pvph search` alone clears it.

**The spec dropdown** reads **All specs** until you pick one of the specs you played. It lists each
spec you played on the tab you are on, with how many matches that is, the one you played most first.

**The result dropdown** reads **All results** until you pick **Won**, **Lost** or **Even**. **Even**
covers a match with no winner, such as a Solo Shuffle you won three rounds of six.

**The time range dropdown** is the same one as on **Stats**: pick a range in either place and both
follow. See [Choosing a time range](Summary-and-Rating-Graph#choosing-a-time-range).

A filter that leaves nothing says so, such as `No won matches as Frost Mage.` The figures, the graph
and **Stats** read the whole tab in the time range you picked. Your search and your spec and result
choices last until you log out or reload, and aren't saved; the time range is saved.
`/pvph filter result` with `all`, `won`, `lost` or `even`, and `/pvph filter spec` with a spec or `all`,
set the dropdowns from chat, and `/pvph filter` alone prints both choices and the count.

### The right-click menu

Right-click a match to get a menu of what you can do with it, without opening it first:

- **Open**, which reads **Close** while that match's window is up
- **Write a note**, which opens the match's window with the cursor in its note box
- **Note this roster**, or **Note this duel**, which opens the [players window](Players-and-Notes)
- **Print in chat**
- **Enter result**, with **win**, **loss** and **draw** under it, offered only where the addon couldn't
  record a result

A Solo Shuffle offers **Enter result** only where its rounds don't settle anything, and a World PvP
session never does, since it has no winner. A match you left early has its own menu under **WHY YOU
LEFT** instead.

### The tooltip

Hold `Shift` while the pointer is over a match to see it in a tooltip. Its first line is the result,
the format, the map and the rating change. An arena or a Solo Shuffle then lists every player, your
team first, with their spec, damage, healing and dispels, and a Solo Shuffle adds a line for each
round. A battleground shows each team's objective totals and then your own line. Without `Shift` nothing
shows. A duel, a World PvP session and a match you left early have no tooltip.

![The Shift tooltip on a battleground: the result, each team's objective total and your own line, over made-up players](images/shift-tooltip.png)

## One match, in its own window

Click a match to open it in a window of its own. Its title bar names the match number, the format, and
the date and time it started.

![A Solo Shuffle match in its own window: the result and the ratings at the top, a card for each round, then the table of players and rounds, over made-up players](images/match-window.png)

**At the top**, the result is in large letters at the right: `WON`, `LOST`, or on a Solo Shuffle the
rounds, such as `WON 4 OF 6`, `LOST, WON 2 OF 6` or `DRAW 3 OF 6`. At the left is the map, and under it
how long the match lasted and the spec you played.

**On a rated match**, your rating going in, an arrow, your rating coming out and the change sit under
the map: a Solo Shuffle you went into at 1716 and won 9 on reads `1716`, the arrow, `1725` and `+9`. At
the right, a chip names the tier you ended in, in its colour, with your matchmaking rating beside it,
and the chip reads `reached` when the match took you into a new tier. Under them, a bar shows the tiers
around you with marks at your rating before and after.

For a duel, the heading is your opponent. For a World PvP session, it's the zone, with your kills and
deaths beside it. See [World PvP](World-PvP).

**Below that is everyone who played**. A Solo Shuffle shows one table of the players and the rounds,
described on the [Solo Shuffle](Solo-Shuffle#the-round-table) page, and in the **Match the game**
appearance a card for each round above it. Every
other match has one row each: the spec's icon, their name in their class colour and realm, spec, role,
damage (with a bar comparing it to the top damage in the match), healing, killing blows, and under
**DISP** how many dispels they cast, as the game's own damage meter counted them. **Your team is always
listed first.**

A dash under **DISP** means there is no figure for that player, which is every player in a match saved
before version 0.13.0. A duel has no **DISP** column. `/pvph meter` and a match number prints the same
figures in chat, with the reason for each dash, and round by round in a Solo Shuffle.

**Click a player's name to open [their own window](Players-and-Notes#one-player)**, and click it again
to close it. A modified click puts that player into the match list's search instead:

- `Shift`-click adds their name and realm, so the list shows the matches you played with them.
- `Ctrl`-click adds their spec and class, such as `Frost Mage`.
- Add `Alt` to either, or hold it alone, to leave out the matches that carry the term instead.

The list narrows at once, and the history window comes up if it was hidden. Clicking the same term twice
doesn't add it twice, and clicking it with the opposite key flips it. A player with no recorded spec
adds nothing on `Ctrl`, and the click says so.

**In a battleground**, each team's objective totals (flags, bases, carts and so on) appear above the
players, so you can see whether you won the objective or the fight. On maps the addon knows, each
player's own objective numbers take the place of their healing and damage in their row.

**If one team was bots**, as in some practice modes, its heading says how many were bots. Their role is
left blank, because the game reports a made-up one for bots. Bot teams are never counted in your
[compositions](Compositions).

**At the bottom**, always in the same place, is a box for a note on the match, which reads
`Note on this match, then Enter` until you type in it. A note you are part way through typing stays
while the window redraws, and Escape puts back the note you had. Beside it, **Note this roster** opens
the [players window](Players-and-Notes) on everyone who played, and on a duel it reads **Note this
duel**. If the addon couldn't record the result, the **win**, **loss** and **draw** buttons on the same
line let you enter it. Printed in chat, a result you entered is marked as entered by hand.

Typing `/pvph` followed by a match number prints the same match in chat.

### After a match

When you leave a match the addon has just saved, its window opens by itself once you are out of the
instance and out of combat. A duel, a match you left early and a match that wasn't saved open nothing. If
two matches were saved before you got out, only the newer one opens. Turn it off with **Open the match
after it ends** in the [settings](Settings-and-Storage), or `/pvph aftermatch off`; `/pvph aftermatch`
alone says whether it's on and whether a match is waiting.

### Several at once

You can have several match windows open. Each new one opens beside the match list, a step down from
the one before, and stays attached to the list: drag the list and they come with it. Drag a match
window and that one comes loose and stays where you put it.

**Clicking a match a second time closes its window**, however you opened it: its row in the list, a
match listed under **Stats**, the **LAST MATCH** card, `/pvph show` and the match number, or a match in
a player's list of encounters. The rows of the matches you have open are marked in the list.
`/pvph show last` opens your newest match, and `/pvph show last` with a [format word](Commands#format-words)
opens your newest match of that format. **The link in chat after a match is the exception**: it opens
the window or brings it to the front, and never closes it.

Match windows stay open when you close the list. Press Escape to close the list and every match window
at once, or type `/pvph window close` to close every match and player window and leave the list up.

## About

![The About tab: the addon and your bests at the left, and your history by week, character and format at the right, over made-up matches](images/about-body.png)

**About** has two halves.

The left half shows the addon's name, version and what it does, who made it under **BY**, the
**LICENCE**, and the **WEBSITE** with **Copy link**, which opens a small box with the address already
selected: press Ctrl+C to copy it. Under them, **YOUR BESTS** lists your highest rating, your highest
rank, your longest win streak, the player you've met most, the map you've played most and your longest
match, each with its format or count and the date.

The right half, under **YOUR HISTORY**, says since when you've played and over how many days, then
counts your **MATCHES** (matches you left early included), **PLAYERS MET**, **NOTES WRITTEN** and
**CHARACTERS**. Under them are your matches by week, by character and by format. **SIZE** shows there
too while **Debug detail on screen** is on.

## The recent results bar

An optional bar at the top of your screen shows how your last matches went. It is off until you turn it
on with **Show the newest results on screen** in the **Window** section of the
[settings](Settings-and-Storage), or `/pvph overlay on`.

![The recent results bar: PVP HISTORY over Unrated Battleground, 1-0 today, and one green square marked W, over made-up matches](images/recent-results.png)

**PVP HISTORY** heads its left end. Under it is the format of the newest match your logged-in character
has saved, with your rating and today's change, or on an unrated format today's wins and losses. Beside
that is a square for each match of that format, newest at the left, in your win colour, your loss colour
or grey, marked `W`, `L` or `D`, or on Solo Shuffle with the rounds you won. With no matches saved yet it
reads `No matches yet.`. A World PvP session never becomes the bar's format, since it has no result.

Hover a square to see that match's date, length, season and rating change, click it to open or close
the match's window, and drag the bar to move it. **Window size and place** in the settings puts it
back. The settings also let you pick how many matches it shows (4 to 10, under **Matches shown**), how
dark its background is (**Background**), and whether it hides in combat (**Hide it in combat**, on by
default).

`/pvph overlay` alone prints the settings and which matches it would draw. `/pvph overlay count 4` to
`10`, `/pvph overlay opacity 0` to `100` and `/pvph overlay combat on` or `off` change the same
settings. `/pvph overlay preview` holds the bar up for this session without saving that it's on, and
`/pvph overlay preview off` takes it down.

## Resizing and moving

Drag the grip in the bottom right corner to resize the window, and drag the window itself to move it.
Both are remembered. The window gets wider and narrower as well as taller and shorter, and everything
in it spreads to the new width.

The window won't shrink past the point where things would start to overlap, and a saved size bigger
than your screen is fitted inside it.

If the window ends up somewhere you can't reach, type `/pvph window reset`, or use the **Reset** button
on **Window size and place** in the **Window** section of the [settings](Settings-and-Storage). Either
one puts every window and the recent results bar back in its place.

## Using it alongside the game's windows

The addon's windows behave like the game's own panels. Click one to bring it to the front, and the
game's windows (like your character sheet) can come in front of it too.

`/pvph show` with a match number closes that match's window if it's already open. `/pvph`,
`/pvph notes` and `/pvph options` open their window, and `/pvph options` also closes the window when the
settings are already showing.
