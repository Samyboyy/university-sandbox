# University Sandbox new-game route (T4)

## Production route

```
Main menu "New Game"  (MainMenu._on_NewGameButton_pressed)
  -> MainScene._ready() -> startNewGame() -> runScene("UniversityNewGameScene")
     ""           welcome
     askforname   name text box, or BDCC's CharacterNameGeneratorScene ("Random?")
     -> UniversityCharacterCreatorScene     gender -> pronouns -> appearance
          -> UniversityChangeSkinScene      (from Body attributes -> Skin/Colors)
     movein       starter outfit equipped, player placed in the private dorm
     finish       onboarding marked complete -> WorldScene (normal play, saving enabled)
```

BDCC's `IntroScene` → `IntroIntake` → `IntroMedical` → `IntroWakeup` and `PickStartingPerksScene` are
**not started**. That skips the interrogation, crime choice, intake, forced shower, medical exam,
restraints, uniform, cell assignment and wake-up. They stay registered as legacy content.

## University-owned components

| Path | Role |
|---|---|
| `Modules/UniversityModule/Module.gd` | Registers the scenes and item below; registers the dorm floor in `preInit()` |
| `Modules/UniversityModule/Scenes/UniversityNewGameScene.gd` | The route controller (states above) |
| `Modules/UniversityModule/Scenes/UniversityCharacterCreatorScene.gd` | Extends BDCC's creator; own appearance, bodypart and attribute screens |
| `Modules/UniversityModule/Scenes/UniversityChangeSkinScene.gd` | Extends BDCC's skin editor; plain skins only |
| `Modules/UniversityModule/Items/UniversityStarterClothes.gd` | Placeholder outfit |
| `Modules/UniversityModule/World/UniversityDormFloor.tscn` | Dorm floor |
| `Game/University/UniversityPlayablePolicy.gd` | **Human-only boundary** |
| `Game/University/UniversityStudentProfile.gd` | Persistent student profile: contract and validation |

**Changes to existing files:**
- `MainScene.startNewGame()`: one line now runs the University scene.
- `QuestSystem`: a small gate hides legacy quests in University games (see "Legacy containment").
- `UniversitySaveSchema.SYSTEM_VALIDATORS`: validates the student profile.

The new scripts use `preload`, not `class_name`, so headless runs don't depend on the editor
regenerating `project.godot`.

## Human-only enforcement

`UniversityPlayablePolicy` is the only place that defines what the player may be.

- **Species.** The player is always `["human"]`. The University creator never shows BDCC's species
  or hybrid screens. Any `setspecies`/`pickspecies`/`pickhybrid1`/`pick2species` action is refused: the
  player stays human and keeps their current appearance choices. Human defaults are applied only
  when the route starts and after pronouns are chosen.
- **Bodyparts.** There is an allowlist per slot (`ALLOWED_BODYPARTS`), and slots without one (tail,
  horns) are not offered. Only allowlisted parts are listed, and `setbodypart` refuses anything else.
  This excludes:
  - digitigrade legs and hoofs;
  - non-human and ovipositor genitals;
  - egg-laying vagina and cloaca, and the womb variant;
  - the mane and "Kid Tails" hairstyles;
  - the android head.
- **Skins.** Only `HumanSkin` and `EmptySkin` are offered (the other BDCC skins are fur or fantasy
  patterns). Colours stay free. "Randomize ALL" is replaced with colour-only randomising.
- **Labels.** BDCC names such as "Anthro Body" are shown as neutral names (`DISPLAY_NAMES`).
- **Final check.** `enforceOnPlayer()` runs:
  - when the route starts (BDCC's `Player` defaults are feline);
  - after every creator and skin action;
  - when the creator closes;
  - at move-in.

  It replaces disallowed parts with the human default for that slot, removes tails and horns, and
  resets disallowed skins. `getViolations()` reports anything still out of policy (used by the tests).
- **Adults only.** All wording describes an adult first-year student. A numeric age comes in a later
  ticket.

## Starting outfit (temporary placeholder)

| Slot | Item id |
|---|---|
| Body | `UniversityStarterClothes` ("Plain T-shirt and shorts") |
| Underwear bottom | `plainPanties` if the body has a vagina and no penis, otherwise `plainBriefs` |
| Underwear top | `plainBra` if the chest isn't flat |

`UniversityStarterClothes` reuses BDCC's `CasualClothes` rigged model and state. It only replaces
that item's "inmate shirt" wording, and has no buffs or style tags. The inventory is cleared before
equipping, so no uniform, collar, cuffs or restraints are ever applied.

## Dorm

| | |
|---|---|
| Room id | `university_private_dorm` |
| Name | "Private Dorm Room" |
| Floor | `UniversityDormFloor` |

The dorm is one isolated room: no exits yet, no NPC population, and NPC meetings off for the floor.
It reuses BDCC's bed map icon; the description is text only (placeholder visual). It sits far from
other floors' coordinates. The player's location is set to it from the first screen, so even a
mid-creation save never points at `cellblock_orange_playercell`.

## Persisted student profile

A long-lived record, not just a route-start marker. It is stored in the T3 section as
`university.systems["student_profile"]` and kept in `Game/University/UniversityStudentProfile.gd`.

While onboarding:

```json
{"onboarding_completed": false, "student_year": 1, "housing_id": "university_private_dorm", "route": "university", "is_adult": true}
```

After move-in, the same with `"onboarding_completed": true`.

`UniversityStudentProfile.validate()` runs from `UniversitySaveSchema.checkCurrentStructure()`
whenever the system is present. It requires:

| Field | Rule |
|---|---|
| `onboarding_completed` | a boolean |
| `student_year` | a whole number of at least 1 (JSON loads it as `1.0`; fractions, text and booleans are rejected) |
| `housing_id` | exactly `university_private_dorm` (the only supported room) |
| `route` | exactly `university` |
| `is_adult` | a boolean, and it must be `true` |

Any failure rejects the whole load before anything is applied.

The system is **optional** in schema version 1, so there is no schema bump: T3-era saves without
it still load. A game counts as University-route only when it holds a **valid** student profile
(`isUniversityGame()`).

## Legacy systems still initialised, and why

All BDCC modules, species, bodyparts, skins, items, events and quests stay registered. They supply
the renderer, the human body meshes, clothing models, hair and the creator itself, and deleting them
would break those shared paths.

In the dorm, they stay inert:
- **Room-agnostic events** (for example Hypnokink, drug den, portal panties, nemesis, lootable rooms)
  are gated by inmate population, flags, perks, items or missions, and the dorm has none of those.
- **NPC pawns** can't reach an isolated room with no population.

## Legacy containment

- **Quests.** In a University game (valid `student_profile` present), `QuestSystem.getAllQuests()` drops every
  quest whose id doesn't start with `university_`, and `isActive()` returns false for them. BDCC's
  "Escape from the prison" and "Mineshafts" were otherwise visible by default. Games without the
  profile keep BDCC behaviour.
- **Flags.** `Game_PickedStartingPerks` is set, so BDCC's "Pick Perks!" prompt in the Me menu stays
  hidden until University perks exist.
- **No prison flags.** The route never sets `Player_Crime_Type` or `InmateType` flags, and never
  assigns `Game_CompletedPrologue`.

## Durable human policy after onboarding (T4C)

T4 guarantees a human player *during* onboarding. T4C keeps that true afterwards, for the
**canonical University player only**: the original PC of a game holding a valid `student_profile`
(`Player.isUniversityPlayerLocked()`). NPCs, player overrides, profile-free legacy/T3 games and all
registries are unaffected.

**Two layers.**

1. **Player-only interception** (`Player/Player.gd`). Edited: `setSpecies()` (always resolves to
   human), `resetBodypartsToDefaultFor()`, `applyTFData()` (canonicalise after), and `loadData()`
   (marks `needsUniversityPolicySweep`; the profile isn't restored yet). Overridden from
   `BaseCharacter`: `giveBodypart()` (substitutes the human default, or drops tail/horn attempts),
   `removeBodypart()` (no callback, to avoid remove/refill recursion), `updateAppearance()` (the
   guarded backstop and the atomic end of transformation write-back), plus
   `applyBodypartsSkinData()`, `applyRandomSkin()`, `applyRandomSkinAndColors()`,
   `applyRandomSkinAndColorsAndParts()` and `checkSkins()`.
2. **Post-load sweep** (`Game/SaveManager.gd`). `applyUniversityPolicyAfterLoad()` runs right after
   `GM.main.university.loadData(...)` and before `loadingSavefileFinished()`, because the player
   payload is restored *before* University state.

`enforcingUniversityPolicy` is the reentrancy guard: while the policy is mutating the player, the
overrides call the inherited implementations directly. `enforceOnPlayer(character, refreshAppearance)`
separates data correction from the visual refresh, so the inherited appearance update runs once per
external call. Enforcement is a no-op when `getViolations()` is empty, so valid human choices —
hairstyles, human skins and colours, femininity, thickness, male and female anatomy — are untouched.

**Custom part-skins.** Ears, hair and penis parts use `pickedSkin` as a *part-skin* id. A non-null
value is valid only if registered for that exact part (`GlobalRegistry.getPartSkins(part.id)`), so
`humanearspierced`, human penis variants and hair highlight/fade/tip variants survive, while a
foreign id such as a wolf-ear pattern is reset to `null`.

**Non-human save payloads** are loaded and canonicalised, never rejected: structural validation
(T3) still runs first, and repair happens before anything renders.

**Transformation suppression.** For a University player, every registered transformation's
`EncounterSettings` weight is set to `0.0` except `UniversityPlayablePolicy.ALLOWED_TRANSFORMATION_IDS`
(initially empty), so `canStartTransformation()` refuses them and no animal transformation is ever
narrated. Applied at onboarding and reapplied by the post-load sweep. Definitions are untouched and
NPCs are unaffected. Suppression is not the boundary: already-running or directly applied
transformations are still canonicalised.

**Deferred task (T4D): equipment containment.** No reachable University-world path can equip
restraints today (the dorm has no NPCs, pawns or prison events), so T4C adds no inventory guard. When
campus NPCs and events arrive, add a University player equip guard for muzzles, collars, wrist and
ankle restraints, cages and prison uniforms. Tests already assert none are equipped.

## First campus day (T5)

The first post-onboarding gameplay loop: leave the dorm, cross campus, check in, attend
orientation, come home and sleep.

**Campus topology** (one floor, `UniversityDormFloor`, all links bidirectional):

```
Private Dorm Room ─S─ Dorm Corridor ─S─ Dorm Lobby ─S─ Campus Quad ─E─ Student Services
                                                              └────W─ Lecture Hall
```

| Room id | Name |
|---|---|
| `university_private_dorm` | Private Dorm Room |
| `university_dorm_corridor` | Dorm Corridor |
| `university_dorm_lobby` | Dorm Lobby |
| `university_quad` | Campus Quad |
| `university_student_services` | Student Services |
| `university_lecture_hall` | Lecture Hall |

Travel uses the inherited WorldScene `go` action and its standard 30-second cost; the dorm keeps
no NPC population. Room buttons use the inherited `RoomAction` node: **Sleep** (dorm),
**Talk to the coordinator** (Student Services) and **Attend orientation** (Lecture Hall).

**NPC.** Priya Raman, the first-year orientation coordinator (`universityCoordinator`), is a
persistent, serialized human `Character` at Student Services. Her dialogue branches on the current
stage, and she only checks the player in once.

**Objective state** lives in `university.systems["first_day"]`:

```json
{"stage": "leave_dorm", "completed_on_day": -1}
```

Stages run `leave_dorm → check_in → attend_orientation → return_dorm → sleep → complete`.
`advanceFrom(state, fromStage)` only moves the sequence when the player is *at* that stage, so
steps can't be skipped and repeating a finished interaction does nothing. `completed_on_day` records
the day the sequence finished (written before the night passes) and is `-1` until then.
Completion advances the day through `MainScene.startNewDay()`, which also triggers the game's
normal autosave.

The objective is shown through a real quest, `university_first_day` (Tasks screen), and repeated in
scene text when the player arrives somewhere on campus. The quest and the progress event both
require a **valid `student_profile`**, so a legacy/T3 game that happens to carry first-day data never
runs or shows the sequence.

**Validation and schema.** `UniversityFirstDay.validate()` is registered in
`UniversitySaveSchema.SYSTEM_VALIDATORS`: the stage must be one of the known stages, and
`completed_on_day` must be a whole number ≥ -1 that is set if and only if the stage is `complete`.
**No schema bump:** like `student_profile`, the system is optional in version 1, so profile-free
T3-era saves remain valid.

**Equipment containment (T4D) stays deferred.** The slice adds no path to inherited restraint or
equipment behaviour: the coordinator scene equips nothing, the campus rooms have no NPC population
or pawns, no interaction system runs there, and no prison event is reachable. Tests assert the
player still has no muzzle, collar, cuffs, cage or prison uniform after the whole day. Revisit when
campus NPCs, pawns or events are introduced.

## Placeholders

- The starter outfit reuses BDCC's shirt-and-shorts model.
- The dorm uses the bed map icon and text description only; there are no exits or facilities yet.
- The creator still uses BDCC's naked preview pose, gender and pronoun wording, and some
  character-named hairstyles ("Tavi", "Jacki Hair", "Ferri").

## Extending the route

- **New onboarding steps** (major, background, preferences…): in
  `UniversityNewGameScene._react_scene_end()`, run the next child scene after `character_creator`,
  and only set `movein` when the last step ends.
- **New persisted choices:** add fields to `student_profile` (with validation and tests), or give
  unrelated data its own system id, with a validator in
  `UniversitySaveSchema.SYSTEM_VALIDATORS`.
- **Campus locations:** add rooms to `UniversityDormFloor.tscn`, or new floors registered in the
  module's `preInit()`, and enable the dorm's exits.
- **University quests:** use ids starting with `university_`.
- **New allowed bodyparts or skins:** change only `UniversityPlayablePolicy`. The harness
  (`Tests/run_tests.gd`, phases 4a–4g) checks every offered choice against the policy and the
  registry.
