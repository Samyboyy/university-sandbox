# University Sandbox save format

Saves are the existing BDCC JSON files written by `SaveManager` (`SAVE` autoload,
`Game/SaveManager.gd`). T3 adds an identity and a versioned, University-owned section on top.
There is no separate save manager.

## Identity and schema

| Key | Value | Owner |
|---|---|---|
| `savefile_version` | `2` (unchanged BDCC base format) | `SaveManager.currentSavefileVersion` |
| `game_id` | `"university_sandbox"` | `UniversitySaveSchema.GAME_ID` |
| `university.schema_version` | `1` | `UniversitySaveSchema.CURRENT_SCHEMA_VERSION` |
| `university.systems` | `{ "<system id>": { ... } }` | `UniversityState` (`GM.main.university`) |

`Game/University/UniversitySaveSchema.gd` holds the constants and the only validate/migrate code.
`Game/University/UniversityState.gd` is the live, per-game data. `MainScene` creates a fresh
instance for every new game. Both scripts are loaded with `preload`, not `class_name`, so
headless runs don't need the editor to regenerate `project.godot`.

## Validation order

`SAVE.validateSaveData(data)` is the single gate. It only reads, and it runs before anything in
the live game changes:

1. The parsed file is a dictionary. (Before this, `readSaveFile()` reports missing, unreadable
   or non-JSON files.)
2. `savefile_version` is a whole number no higher than the supported base version.
3. `game_id` is present, is text, and equals `university_sandbox`.
4. `player` and `main` are dictionaries.
5. `university` is present, then `UniversitySaveSchema.validateAndMigrate()` checks it:
   - it is a dictionary with a whole-number `schema_version`;
   - that version is within `MIN_SUPPORTED_SCHEMA_VERSION`..`CURRENT_SCHEMA_VERSION`;
   - a **deep copy** is migrated step by step to the current version;
   - the migrated copy passes `checkCurrentStructure()`.

Only after all of that does `tryLoadData()` apply the base save. It then hands the migrated copy to
`GM.main.university.loadData()`. Unknown keys inside `university` are kept unchanged and logged
as warnings.

## Entry points

| Call | Use |
|---|---|
| `SAVE.tryLoadGame(path) -> bool` / `SAVE.tryLoadData(dict) -> bool` | Load with a result. On failure nothing is applied and `SAVE.getLastLoadError()` says why. |
| `SAVE.loadGame(path)` / `SAVE.loadData(dict)` | Existing void wrappers (quickload helpers, rollback, dev tools). Same validation. |
| `SAVE.inspectSaveFile(path)` | Read and validate without loading (menu load, save list). |
| `SAVE.switchToGameAndLoad(path)` | Validates **before** leaving the menu. If the file breaks after that check, the load fails and the game returns to the main menu instead of leaving a fresh game running. |
| `SAVE.getLatestLoadableSavePath()` | "Continue" uses the newest save that passes validation. |

## Behaviour by save type

| Save | Result |
|---|---|
| Current University Sandbox save | Loads. |
| Foreign `game_id`, or `game_id` missing (original BDCC saves, and T1/T2 test builds) | Refused: "belongs to another game" / "Not a University Sandbox save". |
| Malformed JSON, wrong structure, missing `player`/`main`/`university`, malformed section or systems table | Refused with a specific reason. |
| `schema_version` older than `MIN_SUPPORTED_SCHEMA_VERSION` | Refused. |
| Older but supported `schema_version` | Migrated in memory; the file on disk is only upgraded by the next save. |
| `schema_version` newer than this build, or a newer `savefile_version` | Refused ("a newer version of the game is needed"). |

Refused files are never modified, moved or deleted. Reasons appear in the log and console
(`Log.printerr`), in the save list ("Can't load: …", with the Load button hidden), and in the
game text for a failed quickload. The save-info cache is at version 2, so older caches are
rebuilt rather than trusted.

## Adding data for a new system

1. Pick a stable system id (for example `calendar`) and store JSON-safe dictionaries through
   `GM.main.university.setSystemData(id, data)`; read them with `getSystemData(id)`.
2. Don't add top-level save keys, and don't check versions inside the system.
3. When a stored shape changes incompatibly:
   - bump `CURRENT_SCHEMA_VERSION`;
   - add `migrateFrom<N>(section) -> Dictionary` to `UniversitySaveSchema`;
   - tighten `checkCurrentStructure()` if new data is required.
4. Add a fixture or assertion to `Tests/run_tests.gd`. The rejection cases in phase 6 are the
   template to follow.
