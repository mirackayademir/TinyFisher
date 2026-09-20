# TinyFisher — Project Handoff / Dev Status

**Last updated:** 2026-09-20  
**Active repo:** `mirackayademir/TinyFisher`  
**Active branch:** `eski`  
**Current gameplay head before this handoff commit:** `5abc1f340ca7dacebce6a0eaa631444539e2062b`

---

## NEW CHAT BOOT RULE — IMPORTANT

When a new ChatGPT conversation starts for this project:

1. **Do not tell the user GitHub/repo write access is unavailable without checking first.**
2. First inspect the available GitHub connector tools.
3. Verify `mirackayademir/TinyFisher` and branch `eski`.
4. If GitHub write tools are available, **apply project changes directly**.
5. Do not ask the user for zip/manual code/reconnect unless the connector itself was checked and actually failed.
6. **Do not create or switch branches without user approval. Continue on `eski`.**
7. The user normally only does:
   - `git pull`
   - Godot F5 test
   - screenshot / visual feedback
8. Do not send project implementation code unless the user explicitly asks; edit the repo directly.
9. Do not switch to Work mode automatically.
10. After each completed task, give a short report and commit SHA.
11. Container/terminal network errors are **not** evidence that the GitHub connector is unavailable.
12. **Editor Preview Rule:** new runtime visual objects should also be mirrored in `scenes/world_editor_preview.tscn` when technically appropriate.

---

## CURRENT STOPPING POINT — 2026-09-20

We stopped after replacing/restoring the **Swordfish** and **Anglerfish** and adding their species-specific animation work.

The user tested the current Anglerfish animation and said:

> “tamam fena değil”

So **do not rework it automatically tomorrow**. Continue from this state unless the user specifically asks for changes.

---

## SWORD FISH — CURRENT STATE

### Artwork
- Current asset:
  - `generation/fish/kilic_baligi.webp`
- Previous Swordfish was removed, then the new approved artwork was restored.

### Runtime/test placement
- Fish is active in the catalog.
- Temporarily placed near the harbor so the user can inspect it immediately with F5.
- Current target count: 1.

### Animation
Swordfish now has a dedicated realistic swim mesh.

Motion character:
- Thunniform/high-speed swimmer.
- Head and sword stay comparatively stable.
- Rear body provides small controlled flex.
- Tail provides most of the propulsion.
- Cruise and short burst behavior.
- Gill-cover breathing details.
- Very small whole-body inertia movement.

### Important commits
- `77e7fdc` — **feat: restore swordfish with new artwork**
- `941f0ad` — **fix: spawn swordfish beside harbor for testing**
- `0ee5ee9` — **feat: add realistic swordfish swim animation**

---

## ANGLERFISH / FENER BALIĞI — CURRENT STATE

### Artwork
Current approved/new asset:

- `generation/fish/fener_baligi_yeni.webp`

The previous Anglerfish was deliberately removed first and then replaced with this new artwork.

### Catalog/runtime
`scenes/fish_catalog.gd` currently contains:

- Fish: `Fener Balığı`
- Behavior: `hover`
- Target count: 1
- Temporary harbor test spawn
- Slow deep-water movement profile
- New generated artwork path

### Asset/import commits
- `e334970` — **chore: remove anglerfish from active roster**
- `58a06c8` — **fix: clean fish catalog after anglerfish removal**
- `250fd20` — **feat: add new anglerfish artwork and restore species**
- `e36bfae` — **fix: finalize anglerfish asset import**

### Dedicated special animation
Latest implementation:

- `5abc1f340ca7dacebce6a0eaa631444539e2062b`
- **feat: add articulated anglerfish animation**

Implemented in:
- `scenes/fish.gd`

The Anglerfish now uses a **single continuous deformation mesh**, rather than visibly separated sprite chunks.

#### Animated regions / behavior

**Tail**
- Slow, low-frequency propulsion.
- Stronger movement when the fish accelerates/attacks.
- Designed to feel heavy rather than fast.

**Rear body**
- Soft follow-through from the tail.
- Movement decreases toward the head.

**Main body / head**
- Mostly stable.
- Very small heavy-water inertia.
- Avoids rubbery full-body bending.

**Upper/lower fin areas**
- Separate phase behavior.
- Slow paddle-like stabilizing movement.
- Intentionally different from fast fish tail motion.

**Jaw**
- Subtle breathing/open-close motion.
- Opens more during attack/dash behavior.

**Angler lure / antenna**
- Independent sway and bob.
- Delayed movement relative to body.
- Moves more during an attack.

**Glow**
- Existing Anglerfish glow remains active.
- Glow position follows the animated lure movement.
- Soft pulsing remains part of the fish's look.

**Whole fish**
- Slow vertical hover.
- Tiny pitch/inertia movement.
- Designed to feel like a deep-water ambush predator.

### User verdict
Current result was accepted as:

> “fena değil”

Treat the current Anglerfish animation as the accepted baseline.

---

## OTHER SPECIAL FISH — STILL PRESENT

Previous special animation work remains in `scenes/fish.gd`:

- Barakuda
- Müren
- Vatoz
- Deniz Şeytanı
- Kalamar
- Köpekbalığı
- Kılıç Balığı
- Fener Balığı

Do not remove or rewrite these systems unless the task requires it.

### Previous five-fish state
The earlier animation test group remains intentionally in enlarged/test-friendly state unless changed later:

- Barakuda
- Müren
- Vatoz
- Deniz Şeytanı
- Kalamar

The user previously accepted these as “eh işte idare ederler”.

---

## IMPORTANT FILES RIGHT NOW

### Fish systems
- `scenes/fish.gd`
  - Fish species behavior.
  - Hook attraction.
  - Base movement.
  - Special articulated/mesh animation systems.
  - Current Swordfish and Anglerfish custom rigs.

- `scenes/fish_catalog.gd`
  - Species profiles.
  - Asset paths.
  - Spawn positions.
  - Speeds/scales.
  - Fight/tension profiles.

- `scenes/fish.tscn`
  - Base fish scene.

### Current generated fish assets
- `generation/fish/kilic_baligi.webp`
- `generation/fish/fener_baligi_yeni.webp`

### Asset tracking
- `generation/ASSET_LIST.md`

---

## MOST RECENT DEVELOPMENT CHAIN

Current recent sequence on branch `eski`:

1. Remove old Swordfish.
2. Repair generated fish imports.
3. Restore Swordfish using new artwork.
4. Move Swordfish beside harbor for test.
5. Add realistic Swordfish animation.
6. Remove old Anglerfish.
7. Clean Anglerfish from catalog/runtime.
8. Restore Anglerfish with new artwork.
9. Fix Anglerfish asset import.
10. Add dedicated articulated Anglerfish animation.

Latest gameplay commit before this MD:

`5abc1f3` — **feat: add articulated anglerfish animation**

---

## EXPECTED NEXT CHAT FLOW

When the user starts a new chat tomorrow:

1. Read this file.
2. Verify repo `mirackayademir/TinyFisher`.
3. Verify branch `eski`.
4. Verify current branch head.
5. Give a **short status report only**.
6. Continue from the user's next requested task.
7. Do not redo Swordfish or Anglerfish animation unless asked.

No next feature has been selected yet.

---

## USER WORKFLOW PREFERENCES

- Turkish communication.
- KISS.
- Serious/direct responses.
- User does not want unnecessary new work.
- User expects ChatGPT to perform feasible repo edits directly.
- Do not create a new branch without asking.
- Do not switch to Work mode automatically.
- Do not make the user manually edit project code.
- After each completed task/change: concise report + commit SHA.
