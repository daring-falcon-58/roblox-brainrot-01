# Publishing Brainrot Bazaar (for Jon)

The game is built and verified, but only the Roblox account's owner can
publish it. Do this on a Windows or Mac machine with Roblox Studio,
signed in to a Roblox account that can already publish: in good
standing, 2+ days old, past Roblox's age check.

## Steps

1. Open `game.rbxl` (in this repo) in Roblox Studio.
2. Play-test it once (Play button): walk to the conveyor, buy a
   brainrot with E, check it earns on your base. Watch Studio's Output
   for script errors and report any.
3. Publish it as a new experience: File -> Publish to Roblox As...
4. On the Creator Dashboard, open the experience:
   - **Description**: paste this play code exactly as it stands (it
     proves the account can edit the experience):
     `makefun-cotton-banner-silver`
     Add a line about the game around it, e.g. "Brainrot Bazaar - buy
     snack-creatures off the conveyor, guard your base, outrun the
     tsunami. makefun-cotton-banner-silver". (Roblox refuses a name or
     description that reads as a web address, so do not write make.fun
     with its dot anywhere.)
   - **Genre**: pick one, and answer the content questionnaire
     (answering "No" to age-restricted content ends it).
   - Set the experience **Public**.
5. Upload pictures (Creator Dashboard -> the experience ->
   Configurations -> Places -> start place, marked with a star):
   - **Icon**: a square picture, 512x512 is best. Any square crop of
     the game works; a brainrot close-up from `screenshots/` is fine.
   - **Thumbnails**: upload `screenshots/1-start.jpg` FIRST, on the
     Experience Detail Page tab. It must be the first thumbnail, and it
     must be the same picture as the screenshot in this repo.
   - Wait until the experience's page on Roblox shows both, past
     Roblox's review. Roblox's default picture never counts.
6. Send Wowo the two ids:
   - `place_id`: the number in the play link
     `https://www.roblox.com/games/<placeId>`
   - `universe_id`: the number after `experiences/` in the Creator
     Dashboard address, or `game.GameId` in Studio.

Wowo then writes them into `PLAY.json`, commits, re-checks and submits
that commit before the deadline (2026-11-20 21:30 WIB).

## If publishing is not possible

If there is no qualifying Roblox account or no Studio machine, do not
submit: the entry-link check refuses any entry whose experience is not
a real Public place, and a refused attempt counts toward the day's
quota.
