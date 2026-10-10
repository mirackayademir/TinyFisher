# Tiny Fisher

Godot fishing game prototype. The project explores a compact fishing loop with responsive controls, fish variety and satisfying progression.

## Prototype gameplay scope

- Travel to fishing spots and cast a line.
- Fight a hooked fish with a readable catch/progress interaction.
- Sell catches for money and buy upgrades to improve the next fishing trip.
- Distinct target fish: sardine, sea bass, tuna, mackerel, swordfish and shark (names displayed in Turkish during development).
- Early experiments included a top-down WASD boat, harbor interaction and an upgrade progression from level 5 to 10.

## Design direction

A later prototype explored a side-on pier-to-open-sea layout inspired by simple arcade fishing games. The side-view idea and the earlier top-down prototype are **alternative design experiments**, not proof that both modes exist in the current runnable build. Verify the active scene before changing either direction.

## Manual testing

1. Open the project in its configured Godot version and run the current main scene.
2. Verify movement, casting, hook feedback and catching; test fish near and far from the player.
3. Confirm fish type and sale reward match the displayed result.
4. Check that money persists through the intended loop and upgrades change gameplay predictably.
5. Test UI interactions after returning to the harbor or dock.
6. If the active branch uses side-on fishing, separately test horizontal casting distance, line descent, reeling and visible fish depth.

## Contribution rules

- Work on the existing `main` branch unless a new branch is explicitly approved.
- Keep gameplay fixes distinct from purely visual polish and document which scene was tested.
- Commit real changes; avoid placeholder commits made solely to change the contribution graph.
- Local uncommitted Godot assets and scene edits must be saved and pushed from the machine that owns them; remote documentation changes cannot upload those files automatically.

## Suggested next development slice

First confirm which camera/layout experiment is the active prototype, then polish a **single complete catch → sell → upgrade → catch** loop before expanding content.
