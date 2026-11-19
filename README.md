# roblox-brainrot-01

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/daring-falcon-58/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/daring-falcon-58/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Brainrot Bazaar** — a 3D Roblox brainrot game: absurd snack-creatures parade on a conveyor, you buy them, place them on your base, and they earn money every second. Climb a ladder of 12 brainrots across 6 rarities (Common to Secret) and 4 mutations (Normal, Golden, Diamond, Rainbow), steal from rivals' bases, lock your own, slap thieves, rebirth for a permanent income multiplier — and when the tsunami comes, run home with your catch.

The complete loop, all real in the code: a brainrot is bought off the conveyor (`Spawner.buyBrainrot`), placed on a base slot (`Bases.placeBrainrotOnBase`), money ticks up at its rate every second (`Money.tickIncome`), and the shop HUD always shows the next tier to buy (`Catalog.nextTier`). Stealing with a lock and a slap (`Steal.stealBrainrot`, `Steal.slapThief`, `Bases.lockBase`), rebirths (`Money.rebirthPlayer`), and the tsunami hazard (`Wave.runWave`) are all in the server scripts. State lives in one place (`State`), the client only draws (`Hud`).

## Run it

```sh
node tools/generate-project.mjs
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Open `game.rbxl` in Roblox Studio to play it. Publish it as a Public experience to play it on Roblox — see `PUBLISH.md` for the steps and the play code.

---

<sub>Entered on [make.fun](https://make.fun/?ref=x6rfv0hh&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
