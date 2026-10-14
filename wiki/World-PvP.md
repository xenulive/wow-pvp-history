# World PvP

With War Mode on, the addon saves your fights in the open world as sessions. Each session counts your
honorable kills and your deaths, and has its own **World PvP** tab in the
[match history window](Match-History-Window).

## When a session starts and ends

A session starts with your first honorable kill, or your first death, in the open world with War Mode
on. Nothing inside a dungeon, a battleground or an arena counts, and nothing while War Mode is off.

It ends when 15 minutes pass with no kill and no death, when you enter an instance, or when you log
out. A session that was still going when the game closed is closed at your next login, as of its last
kill or death.

## What a session holds

- **Kills**: the game's own count of your honorable kills during the session.
- **Deaths**: how many times you died in it.
- **Where**: the zone the session started in.
- **How long**: from its start to its last kill or death.

On the **World PvP** tab, each session's **RESULT** reads its kills and deaths, such as `3 kills, 1
death`, and the session list's **RECORD** adds them up. The session's own window shows the same
beside the zone. A World PvP session has no winner, so it has no win rate, takes no typed result, and
never becomes the format of the [recent results bar](Match-History-Window#the-recent-results-bar).

![The World PvP tab: the session count and when you last played, then a session reading 3 kills, 1 death, over a made-up session](images/world-tab.png)

## Who you killed

When you land the killing blow on a player, the addon tries to add them to the session: their name,
class, race and faction, how many times you killed them, and on your own line how many killing blows
you landed. They then appear in the [players window](Players-and-Notes) like anyone else you've met.

When you have that player targeted, the game lets the addon read who they were, and the session names
them. Whether it can when you had nothing targeted hasn't been checked yet. If it can't, the session
still counts your kills and deaths, and names nobody for that kill. See
[What it cannot record](What-It-Cannot-Record).
