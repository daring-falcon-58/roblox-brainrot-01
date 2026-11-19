# Screenshots

## How they were made

There is no Roblox Studio on this Linux build machine, so there was no
viewport to capture. `tools/render-shots.py` draws each screenshot from
the same `default.project.json` the place is built from: every island,
conveyor, plot, palm, sign and sample brainrot is a part the generator
placed, at its real position, size and colour, in an isometric view.
The HUD text is the same text `Hud.client.luau` draws (start screen,
live HUD with cash ticking, wave warning, rebirth banner). The blocky
figure is a generic Roblox avatar stand-in, for scale. The brainrot
labels (name, rarity, $/s) are the same labels the server builds at
runtime (`Builder.buildBrainrotModel`, from `Catalog`). Nothing pictured
is gameplay the code does not have.

- `1-start.jpg` — the cover: the bazaar from spawn, start screen on.
- `2-play.jpg` — play: cash ticking, a brainrot bought and placed, the
  shop showing the next tier.
- `3-end.jpg` — the end beat: the tsunami sweeping in and the rebirth
  banner.

All three are 1280x720 JPEGs, each under 256 KiB.

## The thumbnail

`1-start.jpg` is the cover (first by name) and the picture to upload
as the experience's first thumbnail on the Creator Dashboard, so the
thumbnail and the screenshot are the same picture by construction.

## After publishing: swap in real captures if you can

Once the game is published, the best screenshots are real captures of
the game running in Roblox Studio (1280x720 viewport captures). If Jon
takes those on his Studio machine, replace these three files with them
(same filenames, same 1280x720 size), keep `1-start.jpg` as the
uploaded thumbnail, and re-commit. Note: Roblox's own server-rendered
place thumbnails top out at 420x420 square, which is below the
screenshots' 480px short-side minimum, so they cannot be used as
screenshots — Studio captures are the only server-true source at the
right size.
