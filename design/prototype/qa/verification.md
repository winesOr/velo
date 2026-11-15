> 历史验收记录，不代表公开插画版或当前版本已通过；截图未公开。

# Prototype V2 verification — 2026-10-23

Browser: ego-browser, one review task space, local HTTP origin `http://127.0.0.1:8765`. Only prototype files and the visual audit were edited; no Flutter checks, APK build, physical Android playback or TV device performance test were run.

## Passed checks

32 browser assertions are recorded in `interaction-results.json`:

- Rapid carousel changes resolve to the last selected title and artwork; intermediate palette frames occur; the default fallback is not inserted during the change.
- Full episode selection updates the play action; version selection updates resolution; favorite state toggles; movie detail omits episode controls.
- Combined library filters produce an empty state; reset restores all 8 sample entries; search covers both film and music.
- First danmaku use starts with no source; loopback input receives a validation message; a user-entered path-prefixed URL saves; style range accepts keyboard input.
- Invalid room code shows an error; valid code `246810` opens a guest lobby; readiness toggles.
- Casting mock selects a device; heatmap toggles; timeline accepts keyboard seek.
- TV focus moves between controls using an arrow key.
- All six surfaces render media with no missing image and no horizontal scroll overflow in their primary content scrollers.
- Home, detail, library, together and settings fit a 390px mobile viewport without document overflow.
- Overview contains all six main surfaces.

The source created during checks was removed through the UI and font size restored to 22; the saved demo starts with no sources. The browser's prototype settings are isolated under `plezy-visual-study-settings-v2`.

## Visual inspection

Captured and inspected phone screens, long-detail content / stream information, movie detail, filters / empty state, source onboarding, danmaku style, together lobby, cast mock, TV layouts and the overview. During inspection, corrected screenshot UI appearing inside poster cards, duplicated detail text, inconsistent player button backgrounds, settings-profile width, and TV first-row height.

TV screenshots use document coordinates (`getBoundingClientRect + scrollX / scrollY`) so that the captured artifact contains the TV device. Earlier incorrectly clipped TV captures were replaced after inspecting the images. `*-tv.png` are the corrected versions.

- `overview.png`: six-page design board.
- `home-phone.png`, `home-phone-blue.png`, `home-tv.png`: artwork / palette states.
- `detail-phone.png`, `detail-content.png`, `detail-info.png`, `detail-movie.png`, `detail-tv.png`, `mobile-detail.png`: detail hierarchy.
- `library-phone.png`, `library-empty.png`, `library-tv.png`: library.
- `settings-phone.png`, `settings-tv.png`, `source-empty.png`, `danmaku-style.png`: settings and source flow.
- `together-phone.png`, `together-lobby.png`, `together-tv.png`: rooms.
- `player-phone.png`, `player-cast.png`, `player-tv.png`: playback UI.

## Static verification

- `node --check` passed for every JS file in `design/prototype/`.
- All literal HTML `src` / `href` local paths resolve.
- `git diff --check` passed for this task's prototype and audit paths. The directory was already untracked at task start; no files were staged or committed.

These checks establish prototype behavior and layout, not real playback, networking, device discovery or application runtime performance. Detail artwork is taken from regions of the supplied full-page screenshot; final app work must use clean artwork / clear logos from the selected server.
