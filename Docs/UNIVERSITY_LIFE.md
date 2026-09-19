# University life interface, navigation and daily simulation (T6)

The normal-play screen for a valid University game. Legacy/profile-free games keep BDCC's
`WorldScene` untouched: `UniversityHubScene` falls back to it when
`UniversityDailyLife.isActive()` is false (valid `student_profile` required, as in T5).

## Pieces

| File | Role |
|---|---|
| `Game/University/UniversityLocations.gd` | Destination definitions: name, description, room, travel time, opening hours |
| `Game/University/UniversityNeeds.gd` | The eight needs, two contextual meters, clamping, drift, bar rendering |
| `Game/University/UniversityTimetable.gd` | Class data, next-class lookup, attendance and missed sessions |
| `Game/University/UniversityDailyLife.gd` | The central service: gating, travel, time, action catalogue and resolution |
| `Modules/UniversityModule/Scenes/UniversityHubScene.gd` | Presentation only |

Every destination wraps a **real registered room**, so saving, the inherited event system and the
T5 objective keep working. Travel fires the same `Trigger.EnteringRoom` that `WorldScene` fires.

## Adding content

- **A location:** add an entry to `UniversityLocations.LOCATIONS` (with `opens`/`closes` and a
  `closed_reason` if it isn't always open) **and** a `GameRoom` with the matching `roomID` in
  `Modules/UniversityModule/World/UniversityDormFloor.tscn`.
- **An action:** add an entry to `UniversityDailyLife.ACTIONS`: which locations offer it, its
  `minutes`, its `effects` (need deltas) and a description. Set `"scene"` to hand off to an
  existing scene instead. No new scene script is needed for ordinary actions.
- **A class:** add an entry to `UniversityTimetable.CLASSES` with weekdays, start/end hour and
  location. Weekday is `day % 7`.

## Locations

Private Dorm Room, Dorm Bathroom, Dorm Common Room, Campus Quad, Student Services (08–18),
Lecture Hall (07–22), Cafeteria (07–20), Library (08–23). Travel costs 2–9 minutes depending on
distance; closed destinations are shown **disabled with the reason**, never hidden.

## Needs

| Group | Meters | Direction |
|---|---|---|
| Reserves | rest, relaxation, attention, food, hygiene, composure | higher is better; drain with time, restored by actions |
| Pressures | bladder, release | higher is worse; build with time, relieved by actions |
| Contextual | arousal, humiliation | shown only above zero, ready for later adult content |

All values are 0–100 and **every** write goes through `UniversityNeeds` (`setValue`, `addValue`,
`applyEffects`, `applyTimeDrift`), so nothing pokes the dictionary directly and nothing escapes the
clamp. Time drift is applied once per action or journey, not per frame.

## Previews, thresholds and poses

**Previews are state-aware.** `getActionNetEffects()` copies the player's current values and
simulates the exact production sequence without writing state: elapsed-time drift followed by a
clamp, then policy-adjusted action effects followed by another clamp. The button therefore shows
the actual before-to-after delta even when a meter begins near 0 or 100. Sleeping skips drift (the
clock jumps) and simulates the shared `SLEEP_EFFECTS` against the current values, along with its
duration to the next 06:00.

**Central threshold policy** (`UniversityDailyLife`): every ordinary need changes an outcome,
but soft problems never stack below half effectiveness. Rest/food/bladder block demanding actions
only at the critical thresholds (10 / 90), with recovery instructions on the disabled button; at
the soft thresholds (30 / 70) they reduce academic progress. Low relaxation adds a composure cost
to demanding actions. Low attention reduces academic progress and adds a composure cost. Poor
hygiene reduces social recovery, then blocks socialising at 10 with a shower instruction. Low
composure reduces academic and social effectiveness. High release reduces academic focus and
adds relaxation/composure costs. Policy-adjusted effects appear in the same state-aware preview,
and result text discloses reduced non-need rewards. Every need has a recovery action, including
`private_time` in the dorm for `release` (which also clears arousal).

**Activity poses.** `ACTION_ANIMATIONS` maps each action to a stage and a state that the stage
really supports: `Sleeping` (`sleep`, `rub`), `Showering` (`body`, `head`, `crotch`) and `Solo`
(`stand`, `sit`, `kneel`). The harness validates every mapping against
`GlobalRegistry.getStageScenesCachedStates()`. Toilet uses `Solo`/`kneel` as the closest safe
state because the inherited renderer has no toilet stage — a deliberate, documented limitation.

## Interface structure (T7)

Valid University games opt into a dedicated three-column shell; profile-free legacy saves retain
the inherited interface. The palette is near-black/charcoal with off-white copy, blue choices,
green money, green/amber/red need states and restrained rose/purple accents.

- **Left rail:** `$` money, time/date, next class/objective, all eight compact `ProgressBar` needs,
  contextual pressures only while relevant, then Save/Load/Skills/Menu controls. The old room
  map and scene/character list are hidden. Its 286-pixel width is fixed so wide windows give their
  spare space to the centre rather than stretching the compact controls.
- **Centre:** a scrollable dark location card with description, last result, and real inline
  `Button` controls for actions and direct destinations. Action names stay compact while time,
  effects and disabled reasons wrap onto a secondary line. Scene-backed interactions such as
  check-in, orientation and first-day sleep use the same shell through a generic inline presenter.
  The inherited 15-cell keyboard grid is hidden, while its option registry remains active for
  keyboard compatibility and automation.
- **Right:** the existing authoritative layered `Stage3D` player renderer, enlarged by removing the
  name/species, Level, Pain, Lust, Stamina and Work Credits header. Status Effects stays below it.
  Its 330-pixel width is likewise fixed.

The status rail remains registered as `university_status_panel` and the centre card as
`university_main_panel`, making the visible controls directly inspectable by the harness.

## Daily loop

Sleep, nap, private time, toilet, shower, eat, snack, relax, study, socialise, attend class, plus the T5
check-in and orientation actions. Each shows its time cost and important need effects before the
player commits; `getActionPreview()` and the committed effects come from the same data.

Classes: *Introduction to Your Subject* (Mon/Wed/Fri 10–12) and *Academic Study Skills*
(Tue/Thu 14–16), both in the lecture hall. `getNextClass()` searches a full week forward, so
Friday evening and weekends still show Monday's class, and `describeWhen()` names anything beyond
tomorrow by weekday. Arriving within 15 minutes of the start counts as on
time (more study progress); later still counts as attended but less. A class whose window passes
unattended is written off as missed exactly once, tracked by a `handled` session key.

## Save data and migration

Two new optional systems in the T3 section, both validated by
`UniversitySaveSchema.SYSTEM_VALIDATORS`:

```json
"needs":     {"values": {...eight...}, "contextual": {"arousal": 0, "humiliation": 0}}
"timetable": {"attended": 0, "missed": 0, "study_progress": 0, "handled": []}
```

**No schema bump.** Both are optional in version 1, so a T5-era University save still validates and
receives stable defaults through `UniversityDailyLife.ensureState()` without touching its existing
profile or first-day state. Profile-free saves never gain them.

## Interface

The T7 shell deliberately borrows the information hierarchy of a compact browser life sim without
copying its assets: persistent information at left, readable choices in the centre, and this
project's layered character animation at right. Layout and palette resources are original and live
in `UniversityUIStyle.gd`.
