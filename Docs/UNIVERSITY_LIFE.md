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

## Interface structure

The status region is built from real Godot controls added through `GM.ui.addCustomControl`, so it
is inspectable in tests rather than BBCode pretending to be panels:

```
PanelContainer "UniversityStatusPanel"
  VBoxContainer "StatusRows"
    Label        "StatusHeadline"    location, time, day, credits
    Label        "StatusObligation"  next class and current objective
    GridContainer "NeedsGrid"        8 x (Label + ProgressBar, min width 120px)
    GridContainer "ContextualGrid"   only while arousal/humiliation are above zero
```

It sits inside the inherited GameUI text container (already within a `ScrollContainer`), so
scrolling, keyboard use and the existing button flow are unchanged, and the layered character
renderer stays permanently visible. The proven GameUI itself is not rewritten.

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

Status block (location, time, day, credits, next class, current objective, needs bars, contextual
meters), location description, numbered actions with previews, then destinations with travel times.
The layered BDCC doll stays visible in the inherited stage panel during ordinary play — it is not
replaced by a portrait. Palette: charcoal surfaces, muted purple, restrained rose accents
(`#e8a0bf` rose, `#9db8e8` information, `#7ad4a0` wellbeing, `#ffc46b` warning). All original.
