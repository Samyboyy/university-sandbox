# University Sandbox automated tests

A dependency-free headless harness for the conversion. It launches the project with
Godot 3.6.2, lets the real registry initialise, starts a new game through `MainScene`,
saves, changes in-memory state, reloads through `SAVE`, and checks the state came back.

## Running

Linux:

```
Tests/run_tests.sh --godot /path/to/Godot_v3.6.2-stable_linux_headless.64
```

Windows (PowerShell 5.1 or later):

```
powershell -ExecutionPolicy Bypass -File Tests\run_tests.ps1 -Godot "C:\path\to\Godot_v3.6.2-stable_win64.exe"
```

The Godot path can also come from the `GODOT_BIN` environment variable.
Options: `--keep` / `-Keep` keeps the temporary folder after a pass;
`--timeout N` / `-TimeoutSeconds N` sets the time limit (default 600 s).

Exit codes: `0` pass, `1` test failure, `2` setup error.

## Isolation

Always use a runner. Each run creates a new `university_sandbox_tests.<id>` folder in the
system temporary directory and points `HOME`, `XDG_*` (and on Windows `APPDATA`,
`LOCALAPPDATA`, `TEMP`) at it before Godot starts. The harness itself refuses to continue
unless `user://` resolves inside that folder (`US_TEST_ROOT`).

- Your normal `university_sandbox` and old BDCC user-data folders are never used.
- The folder is removed after a pass and kept after a failure. Removal only happens when the
  folder name, marker file and parent directory all match what the runner created.
- The runner refuses to start if a `UniversitySandboxData` folder sits next to the Godot
  executable, because portable mode would redirect user data.

## Reading the results

Each phase prints `[PASS]`/`[FAIL]` lines, with expected and observed values for failures,
followed by `HARNESS RESULT: PASS|FAIL`. The runner then fails the run on script/parse errors
or startup network errors, counts dummy-renderer messages from headless builds without
failing on them, and lists any other engine `ERROR:` lines for review.

Baseline-specific values (starting scene, starting location) are printed as `[INFO]` only,
so later tickets can change the introduction without breaking the harness.
