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
