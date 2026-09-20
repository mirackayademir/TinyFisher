# TinyFisher — Project Handoff / Dev Status

**Last updated:** 2026-09-20  
**Active repo:** `mirackayademir/TinyFisher`  
**Active branch:** `eski`  
**Current gameplay head before this handoff commit:** `ba05b3c9ac43955f471734a43bdbc552015f2789`

---

## NEW CHAT BOOT RULE — IMPORTANT

When a new ChatGPT conversation starts for this project:

1. Do not tell the user GitHub/repo write access is unavailable without checking first.
2. First inspect the available GitHub connector tools.
3. Verify `mirackayademir/TinyFisher` and branch `eski`.
4. If GitHub write tools are available, apply project changes directly.
5. Do not ask the user for zip/manual code/reconnect unless the connector itself was checked and actually failed.
6. Do not create or switch branches without user approval. Continue on `eski`.
7. The user normally only does:
   - `git pull`
   - Godot F5 test
   - screenshot / visual feedback
8. Do not send project implementation code unless the user explicitly asks; edit the repo directly.
9. Do not switch to Work mode automatically.
10. After each completed task, give a short report and commit SHA.
11. Container/terminal network errors are not evidence that the GitHub connector is unavailable.
12. New runtime visual objects should also be mirrored in `scenes/world_editor_preview.tscn` when technically appropriate.

---

## CURRENT STOPPING POINT — 2026-09-20

We stopped after adding and validating the new **Kürek Balığı (Oarfish)** and then adding its first dedicated animation pass.

The user confirmed:

> “tamam çalışıyor burda duralım”

So the current Oarfish implementation is the accepted baseline for the next chat. Do not rework it automatically unless the user asks.

---

## KÜREK BALIĞI / OARFISH — CURRENT STATE

### Artwork / loading

The first direct WebP and PNG attempts were rejected by Godot as corrupt.

Final solution:

- The approved Oarfish artwork is stored as verified Base64 text:
  - `generation/runtime_encoded/fish/kurek_baligi.b64`
- Runtime texture loader:
  - `scenes/oarfish_exact_art.gd`
- `scenes/fish_catalog.gd` calls `OarfishExactArt.get_texture()`.
- The old corrupt:
  - `generation/fish/kurek_baligi.webp`
  - `generation/fish/kurek_baligi.png`
  are no longer used.

Relevant commit:

- `0407e207` — **Load oarfish art from verified runtime base64**

### Test placement

For easy F5 visual inspection, the Oarfish currently has a guaranteed temporary test spawn beside the harbor.

Current test position:

- `Vector2(920.0, 690.0)`

Implemented in:

- `scenes/fishing_spot.gd`

Relevant commit:

- `63b4554a` — **Move test oarfish spawn beside harbor**

Important:

- This is a **temporary test placement**.
- The natural rare/deep-water spawn profile remains preserved for later balancing.

### Catalog / rarity

Current profile:

- Name: `Kürek Balığı`
- Value: `$540`
- Natural habitat: deep open sea
- Natural depth label: `65–90 m`
- Normal population target: `0`
- Rare spawn chance system remains active.
- Dedicated behavior id: `oarfish`

The F5 guaranteed harbor spawn is only for animation/testing convenience.

---

## KÜREK BALIĞI — CURRENT ANIMATION

Latest implementation:

- `ba05b3c9` — **Add oarfish ribbon-body and dorsal-fin animation**

Implemented mainly in:

- `scenes/fish.gd`
- `scenes/fish_catalog.gd`

### Motion design

The animation combines the user's requested eel-like visual motion with Oarfish-specific behavior.

#### Whole body

- The long body uses a single continuous mesh.
- The whole fish bends into a smooth **S-shaped ribbon curve**.
- No separated sprite chunks.
- The wave is slower/heavier than a normal eel.
- Tail/rear body flexes more strongly than the head.

#### Dorsal fin

- The long red dorsal fin gets a separate traveling wave.
- The fin wave is faster than the body wave.
- This is intentionally the dominant propulsion detail.

#### Head crest / long red rays

- The long red rays near the head have delayed independent sway.
- They drag through the water rather than moving rigidly with the body.

#### Special posture

The fish occasionally enters an Oarfish-specific **head-up posture**:

- approximately 58° in the game for readability,
- movement slows strongly,
- body stiffens,
- dorsal-fin wave becomes more active,
- then it gradually returns to horizontal swimming.

When the hook/bait is nearby:

- it exits the head-up posture,
- turns toward the hook,
- approaches calmly,
- uses a short stronger movement near the bait.

### User verdict

The user tested F5 and confirmed the animation is working.

Treat this state as accepted unless the user asks for refinement.

---

## SWORD FISH — CURRENT STATE

### Artwork
- `generation/fish/kilic_baligi.webp`

### Animation
Dedicated Swordfish animation remains active:

- head/sword comparatively stable,
- rear-body flex,
- tail-driven propulsion,
- short burst behavior,
- gill-cover breathing.

Relevant commits:

- `77e7fdc` — restore Swordfish with new artwork
- `941f0ad` — spawn Swordfish beside harbor for testing
- `0ee5ee9` — realistic Swordfish swim animation

---

## ANGLERFISH / FENER BALIĞI — CURRENT STATE

Current artwork:

- `generation/fish/fener_baligi_yeni.webp`

Dedicated articulated animation remains active:

- slow heavy tail,
- rear-body follow-through,
- stabilizing fins,
- subtle jaw motion,
- independently swaying lure,
- glow following lure motion,
- slow hover/inertia.

Latest relevant commit:

- `5abc1f340ca7dacebce6a0eaa631444539e2062b`
- **feat: add articulated anglerfish animation**

The user previously accepted this as:

> “fena değil”

Do not rework automatically.

---

## OTHER SPECIAL FISH STILL PRESENT

Existing dedicated animation work remains active for:

- Barakuda
- Müren
- Vatoz
- Deniz Şeytanı
- Kalamar
- Köpekbalığı
- Kılıç Balığı
- Fener Balığı
- Kürek Balığı

Do not remove or rewrite these systems unless the requested task requires it.

---

## IMPORTANT FILES

### Fish systems

- `scenes/fish.gd`
  - species behavior
  - movement
  - hook attraction
  - special articulated/mesh animation systems
  - Oarfish ribbon-body animation

- `scenes/fish_catalog.gd`
  - fish profiles
  - rarity/spawn ranges
  - movement/fight stats
  - Oarfish runtime texture hookup

- `scenes/fishing_spot.gd`
  - fish spawning
  - rare spawn checks
  - temporary harbor test spawn for Oarfish

- `scenes/oarfish_exact_art.gd`
  - runtime Base64 → PNG texture decode

- `generation/runtime_encoded/fish/kurek_baligi.b64`
  - approved Oarfish image data

- `generation/ASSET_LIST.md`
  - asset tracking

---

## MOST RECENT DEVELOPMENT CHAIN

Recent Oarfish work on branch `eski`:

1. Added Oarfish to catalog and rare spawn system.
2. Discovered corrupt WebP import.
3. Replaced WebP attempt with PNG.
4. Discovered PNG binary was also damaged.
5. Replaced binary asset dependency with verified Base64 runtime texture loading.
6. Added guaranteed F5 test spawn.
7. Moved guaranteed test spawn beside harbor.
8. Added dedicated Oarfish behavior.
9. Added continuous S-shaped ribbon-body mesh animation.
10. Added independent dorsal-fin traveling wave.
11. Added head-ray sway.
12. Added occasional head-up posture.

Latest gameplay commit before this MD:

`ba05b3c9` — **Add oarfish ribbon-body and dorsal-fin animation**

---

## EXPECTED NEXT CHAT FLOW

When the user starts a new chat:

1. Read this file.
2. Verify repo `mirackayademir/TinyFisher`.
3. Verify branch `eski`.
4. Verify current branch head.
5. Give a short status report.
6. Continue from the user's next requested task.
7. Do not redo Oarfish animation unless specifically requested.
8. Keep Oarfish harbor test spawn in place until the user says testing is finished.
9. If Oarfish animation work resumes, preserve the current continuous S-body + dorsal-fin wave as the baseline.

No new next feature has been selected yet.

---

## USER WORKFLOW PREFERENCES

- Turkish communication.
- KISS.
- Serious/direct responses.
- User does not want unnecessary new work.
- User expects ChatGPT to perform feasible repo edits directly.
- **Do not send code for the user to paste unless explicitly requested.**
- User only wants to open Godot and test the result.
- Do not create a new branch without asking.
- Do not switch to Work mode automatically.
- After each completed task/change: concise report + commit SHA.
