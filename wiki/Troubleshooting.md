# Troubleshooting

## Start here

Most problems go away with one of these. Try them in order:

1. Type `/reload`, which reloads the game's interface and every addon's windows with it.
2. If a window is off the screen or the wrong size, type `/pvph window reset`.
3. If the windows use the game's plain font, or the minimap button is an empty circle, copy the whole
   `WowPvpHistory` folder into `Interface\AddOns` again, then log out and back in.

Still stuck? Find what you're seeing below.

## The addon's windows use the game's normal font

The `fonts` folder inside the addon's folder didn't get copied. Copy the whole `WowPvpHistory` folder
again, including `fonts` and `textures`, then log out and back in. Everything still works in the game's
font, it just doesn't look as intended.

On a Russian, Korean or Chinese game client the addon uses the game's fonts on purpose for text its own
fonts can't show. `/pvph status` says when that's the case.

## The minimap button is an empty circle

The `textures` folder didn't get copied. Copy the whole addon folder again as above. The empty button
still works in the meantime.

## I can't find the minimap button

- `/pvph minimap reset` puts it back in its original place.
- `/pvph minimap show` shows it, and `/pvph minimap hide` hides it.

You can always open the history with `/pvph`, from the addon menu beside the minimap, or with a key
binding (**Open the match history**, under **Key Bindings**, in the **PvPHistory** section).

## A window is off the screen or the wrong size

Type `/pvph window reset`, or click **Reset all** on **Size and place of every window** on the **General** page
of the [settings](Settings-and-Storage). Either one puts every window the addon has back in its place,
match windows included.

## A map name or other value is cut short

The window is narrow enough that the value doesn't fit its column. Drag the grip in the bottom right
corner to make the window wider, and the columns spread with it. Column headings are never cut, and the
window won't get narrower than they need, with one exception: in the [spec table](Specs) under
**Stats**, a narrow window can cut the table's column headings. The **AGAINST YOU** and **WITH YOU**
headings above them stay whole, and widening the window brings the rest back.

A figure on a card or in the strip above the list isn't cut: it steps down to a shorter form, or is
left off where none fits.

## A match window won't come to the front

Clicking a match whose window is already open closes that window. Click the match again and it opens
in front.

## The game's settings panel won't open from the addon

The game doesn't allow its settings panel to open during combat. Leave combat and try again. The addon
says in chat when combat is the reason.

## A match is missing

- **Did you leave before the end?** Matches left early are under the **Other** tab. See
  [Duels and unfinished matches](Duels-and-Unfinished-Matches).
- **Was it a duel?** A duel is only saved when the game prints its result in chat.
- **Did the game crash or get closed from outside?** The game only saves addon data to disk when you log
  out, type `/reload`, or exit normally. Matches played since the last save can be lost if it crashes.
- **Still missing?** `/pvph status` shows whether the addon had to skip any matches, and the [Debug log](Debug-Log) page says what to include in a report.

## A character in the dropdown has no name

A character appears by name once you've logged into it with the addon installed. Log into it once and
its name will show.

## Points are missing from the rating graph

If a match's rating is wildly different from the match before it (more than 1,000 points), the addon
treats it as a bad reading from the game and leaves it off the graph. It's counted as skipped, and the
match itself is still in your history. See [Summary and rating graph](Summary-and-Rating-Graph).

## A Solo Shuffle round has no result

Sometimes neither the round counter nor the scoreboard totals can settle a round. You can fill it in
yourself. See [Filling in a missing round](Solo-Shuffle#filling-in-a-missing-round).

## A session's ROUNDS figure is dimmed

One of that session's Solo Shuffles has rounds that don't add up, so it's left out of the sum rather
than guessed. Hover the figure to see how many of the session's matches it covers. See
[Solo Shuffle](Solo-Shuffle#elsewhere).

## A Stats card shows a dash

A card only names an answer once enough games are behind it, 20 rounds for a spec, 10 games for a team
composition and 8 decided matches for a map, and only where the record answers its question: **WORST
COMP** names a composition you lose to at least as often as you beat, not one you beat. Until a row
qualifies the card shows a dash; rest the pointer on it to see what a row needs. See
[Only rows with enough games are ranked](Ask#only-rows-with-enough-games-are-ranked).

## My World PvP kills aren't being saved

War Mode has to be on, and only kills and deaths in the open world count, never inside a dungeon, a
battleground or an arena. See [World PvP](World-PvP).

## Nobody gets a mark on their nameplate

The mark only shows outside battlegrounds and arenas, and only for a player you've rated, tagged,
noted or commented on. Someone in your group is never marked. Check that **A mark on their
nameplate**, under **ON NAMEPLATES** on the **Notes and players** page of the settings, is on, or type `/pvph sight` to see whether it is and how many
nameplates carry a mark. See [Alerts](Alerts#when-someone-you-wrote-about-appears).

## The group finder card doesn't show for an applicant

Your own characters get no card, and neither does a name that two players in your history share
without a realm to tell them apart. Someone you've never met gets a card reading `Not met before.`
See [In the group finder](Alerts#in-the-group-finder).

## A message at login says the backup couldn't be made

At logout the addon couldn't read your history, so it kept your previous backup rather than overwrite it. The message says how long this has been happening and how old the kept backup is.

Don't erase anything. `/pvph restore` shows what the kept backup holds without changing anything. If you're not sure what happened, report it as the [Debug log](Debug-Log) page describes.

## The players window shows PLAYERS DID NOT DRAW

The players window hit an error while drawing. Click **Copy a report**, press Ctrl+C, and include the
text in your report. Closing and opening the window again usually draws it.

## The addon shows an error

`/pvph error` shows the last error it hit and when. Include that in your report.

## Running out of room

`/pvph size` shows how much space your history uses and how much is left before the game can't load the
file. If it's getting full, export a copy (see [Settings and storage](Settings-and-Storage)).
