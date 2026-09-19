# TinyFisher — Project Handoff / Dev Status

**Last updated:** 2026-09-19  
**Active repo:** `mirackayademir/TinyFisher`  
**Active branch:** `eski`  
**Current branch head before this preview-system commit:** `8bb5da0b54ebdf8b8f172ba47ca08e9220dcf55a`

---

## NEW CHAT BOOT RULE — IMPORTANT

When a new ChatGPT conversation starts for this project:

1. **Do not tell the user GitHub/repo write access is unavailable without checking first.**
2. First inspect available GitHub tools/connectors.
3. If GitHub tools such as `fetch_file`, `update_file`, `create_commit`, `create_blob`, `create_tree`, or `update_ref` are available, **use them directly**.
4. Do **not** ask the user for a zip, reconnect, manual code copy/paste, or Git setup when the repository is already accessible.
5. The user expects ChatGPT to perform all feasible repository edits itself and only asks the user for local-only checks such as:
   - `git pull`
   - Godot F5 test
   - screenshot / visual feedback
6. Do not switch branches unless the user explicitly approves it. Continue on **`eski`**.
7. After each completed task, give a short status report with commit SHA and what changed.
8. **The user does not manually edit project code/repo files. ChatGPT performs all feasible implementation and repository changes directly.** The user's normal role is only `git pull`, Godot testing, and screenshots/feedback.
9. Do not switch to Work mode automatically.
10. **Editor Preview Rule:** every new visual/runtime object added to the project must also be visible in `scenes/world_editor_preview.tscn` in the same change/commit whenever technically possible. Static `world.tscn` nodes appear automatically; runtime-spawned systems must be mirrored by the editor preview script.

This rule exists because previous chats incorrectly claimed the GitHub write tools had disappeared even though the tools were still available.

---

## CURRENT TASK STATE

We stopped after completing the first-pass special animation set for the five new test fish.

The user said the current result is **“eh işte idare ederler”** and asked to stop here and continue tomorrow in a new chat.

All five fish are still intentionally enlarged and temporarily placed around **10–15 m** below the harbor for easy animation review.

### Current five fish

- **Barakuda**
  - Articulated realistic swim rig.
  - Head relatively stable.
  - Rear body and tail provide propulsion.
  - Gill / jaw details.
  - Accepted enough to move on.

- **Müren**
  - Rebuilt from segmented animation to a **continuous deformation mesh**.
  - Head mostly stable.
  - Body and tail create a strong full-body **S-wave**.
  - This is currently the realism reference level for the remaining fish.
  - User specifically liked the general realism direction, though not perfect.

- **Vatoz**
  - Dedicated pectoral-fin mesh.
  - Wide wings flap/undulate rather than fish-style tail wag.
  - Wing tips have extra delayed flex.
  - Tail follows softly.
  - User approved moving on.

- **Deniz Şeytanı**
  - Heavy predator body motion.
  - Strong low-frequency tail propulsion.
  - Small fin flutter.
  - Gill and jaw breathing.
  - Three lure/glow points move independently and pulse.
  - User approved moving on.

- **Kalamar**
  - Current version uses an independent-limb mesh.
  - **8 arms + 2 long tentacles = 10 separate motion regions.**
  - Each limb has its own phase/frequency.
  - Latest revision changed every limb so the wave travels root-to-tip like the Moray tail:
    - root stays calmer
    - middle bends
    - tip develops the widest S-wave
    - roughly 1.2–1.5 S-waves per limb
  - Upper and lower rear fins remain independently animated.
  - User said the final result is **“eh işte idare eder”** and chose to stop here.

---

## MOST RECENT COMMITS

### Kalamar
- `bf9258f1fbd1ce21fa187f92fbd82196c4a1eab3`
  - **Make each Squid limb flow with full S-wave motion**
  - Latest project head.
  - Every arm/tentacle now gets a root-to-tip S-wave inspired by the Moray movement.

- `b662da5cf4500d875f1e8929e41c0479c207d181`
  - **Rebuild Squid with independent limb and fin animation**
  - Removed the earlier single-body style.
  - Created 10 independent arm/tentacle motion bands.
  - Added independent upper/lower fin motion.

- `97199ffd9325d1a023d5a51d18cb6c722e6e966e`
  - **Add realistic Squid mantle and jet animation**
  - Older Kalamar version; later replaced because the user did not like it.

### Deniz Şeytanı
- `9d958193370f1e3c56fb2c4d2cd1567c363d4acb`
  - **Add realistic Sea Devil predator animation**

### Vatoz
- `d53af0289f69f6eb75795d8a1f21851190c15f3f`
  - **Increase realistic Stingray wing articulation**

- `9cb92cc4bf9dbc06829b1b9dee334bac1f68a50c`
  - **Add realistic species-specific Stingray fin animation**

### Müren
- `41d12306caa838952eed0ea7f56a90bb62fda050`
  - **Fix Moray mesh loop syntax**

- `7dcc9d3acfca6dd3bd088ba684c1f951d039830f`
  - **Rebuild Moray with continuous S-wave body mesh**

- `b40f7d89072eb2e8f83264e37ab9714fe3a1599e`
  - **Refine Moray full-body S-curve animation**

### Barakuda
- `b27913bc5e4d5e9a90bd3694c98c06f3f5654946`
  - **Add articulated realistic Barracuda animation**

### Test sizing / exact artwork
- `16f364b6f0bbb32da4a289163100e8976d341c8d`
  - **Enlarge five test fish for animation review**

- `0c419c549b6f3fb9d50f1d2542bcc5b6b021392a`
  - **Use exact fish artwork and harbor test spawns**

---

## TEST FISH VISUAL SCALES

Current enlarged temporary test scales:

- Barakuda: `1.12`
- Müren: `1.18`
- Vatoz: `1.18`
- Deniz Şeytanı: `1.12`
- Kalamar: `1.16`

Do **not** restore natural sizes/depths until the user asks or confirms the animation review is finished.

---

## CURRENT IMPORTANT FILES

- `scenes/fish.gd`
  - Main species behavior and all special articulated/mesh animation systems.

- `scenes/fish_catalog.gd`
  - Central fish profiles, temporary test spawn positions, test scales, behavior parameters.

- `scenes/fish.tscn`
  - Fish scene and base Sprite2D setup.

- `assets/fish/barakuda.png`
- `assets/fish/muren.png`
- `assets/fish/vatoz.png`
- `assets/fish/deniz_seytani.png`
- `assets/fish/kalamar.png`

These five PNGs are the exact/approved user artwork currently used by the game.

---

## EXPECTED NEXT STEP

No new task has been chosen yet.

When the user starts the next chat and says to continue:

1. Read this file / inspect branch `eski`.
2. Verify current head.
3. Give a **very short status report**.
4. Ask only what direction the user wants next **if they have not already specified it**.
5. If the user specifies a task, immediately implement it in the repo instead of giving manual instructions.

Potential later cleanup, only when requested:
- Restore the five fish from the temporary 10–15 m harbor test area to natural depth zones.
- Restore production visual scales.
- Further polish any of the five animations if the user requests it.

---

## USER WORKFLOW PREFERENCES

- Turkish step-by-step communication.
- KISS: avoid unnecessary complexity.
- Full final scripts if manual code is ever necessary, but prefer editing the repo directly.
- Do not create a new branch without asking.
- Keep control with the user.
- After a task: concise report + commit SHA.
- Do not make the user do repository work that ChatGPT can do itself.
