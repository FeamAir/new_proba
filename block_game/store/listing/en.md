# Cascado: Google Play listing (English, main)

Status: DRAFT for version 0.17. Not published. Publishing only after Vladimir's approval.
Age rating target: 13+. Developer: OWLIGHT Games.

---

## 1. Store title (max 30 characters)

| # | Variant | Chars | Notes |
|---|---------|-------|-------|
| 1 | **Cascado: Crystal Block Puzzle** | 29 | Brand + main search phrase "block puzzle" + our hook "crystal" |
| 2 | Cascado: Cozy Block Puzzle | 26 | Softer, "cozy" is a growing search word, but loses "crystal" |
| 3 | Cascado: Cascade Block Puzzle | 29 | Repeats the brand sound, weaker |

**Chosen: `Cascado: Crystal Block Puzzle`** (29 characters)

---

## 2. Short description (max 80 characters)

| # | Variant | Chars |
|---|---------|-------|
| 1 | **Chain cascades, free crystals, dress up a fluffy owl, axolotl, pup or kitten.** | 77 |
| 2 | Cozy block puzzle: chain cascades, free crystals, dress up 4 fluffy friends | 75 |

**Chosen: variant 1** (77 characters). Shows the cascade mechanic, the goal and all four heroes in one line.
Variant 2 is a backup for a store listing experiment (A/B test).

---

## 3. Full description (max 4000; this text is about 2,350 characters by hand count; Play Console shows the exact number)

Plain text for copy-paste into Play Console:

```
Deep in a crystal cave, glowing gems are sealed in stone. Drop blocks, clear lines and set them free. Then watch the rock crumble into a cascade: ×2, ×3... even ×6!

Cascado is a cozy falling-block puzzle with a twist. When a line clears, whole pieces drop down together and can complete new lines by themselves. One smart move can start a long chain reaction. Your fluffy friend sits right next to the board and cheers every cascade.

Choose your friend: an owlet, an axolotl, a puppy or a kitten. Make them a boy or a girl and give them a name. Each friend has its own wardrobe, its own forge recipes and its own 3D home.

What's inside:
• 100 handmade levels in 10 halls of the crystal cave, from the Amethyst Hall to the Crystal Crown, plus Endless Depths after level 100.
• Sticky cascades: pieces fall as a whole, and one clear can trigger a chain of new ones.
• 1 to 3 stars per level: the fewer pieces you use, the more stars you get.
• A wardrobe of 19 items for each friend, in 5 rarities, with little companions that fly around them and magic auras.
• The Crystal Forge: collect a full set and Master Hoot forges a legendary item. Three legendary items unlock your friend's super reward.
• A 3D home for every friend: the owlet's tree hollow, the axolotl's underwater grotto, the puppy's garden with a doghouse and the kitten's attic. Turn the camera all the way around.
• Decorate mode: 30 decorations in 3 styles for each home, plus walls, floor and lighting. Save up to 3 moods and switch between them.
• Hall of Fame: win a unique trophy for each of the 10 halls and see it on the shelf in your home.
• Gentle help: a short tutorial, and after 2 losses in a row the crystal offers to clear a row of stone for you.

Play your way:
• Accessibility options: symbols on blocks for color-blind players, left-handed controls, slow fall (stars stay the same) and large text.
• English and Russian.
• No ads and no in-app purchases.
• Fully offline: no internet and no account needed. No data is collected.
• Small download, about 13 MB.

Take a breath, drop a block and start the cascade.
```

### Checks
- No "Tetris", "tetromino" or other brands; no "#1", "best", "top", "free" in the title; no caps spam, no emoji.
- Every feature exists in version 0.17 (see README and the task brief): 4 heroes, boy/girl, name, 19 items per hero,
  5 rarities, companions and auras, Crystal Forge with Master Hoot, 4 3D homes, 30 decorations per home in 3 styles
  (checked in scripts/decor_data/*.gd), 3 moods, 10 trophies, hero next to the board, tutorial, crystal help,
  accessibility (names checked in scripts/i18n.gd), EN/RU.
- Nothing about online play, leaderboards, daily tasks, events or multiplayer.
- Hero names match the game's English interface: Owlet, Axolotl, Puppy, Kitten, Master Hoot, Crystal Forge, Hall of Fame.

### Things to keep true (update this text if the game changes)
- "No ads", "no in-app purchases", "Fully offline", "No data is collected": change the same day ads, purchases,
  analytics or any internet feature appear (also update Data safety in Play Console).
- "about 13 MB": check the real download size of the release AAB; remove the line if it grows a lot.
- "even ×6": the game shows chains up to ×6; keep while true.
- "100 levels in 10 halls", "Endless Depths", "19 items", "30 decorations", "3 moods": keep in sync with the build.
