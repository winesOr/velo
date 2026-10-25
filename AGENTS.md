# Contributor And Agent Guidance

Velo is a community project derived from Plezy under GPL-3.0. Preserve upstream attribution and copyright notices. Read `README.md` and `CONTRIBUTING.md` before changing the project.

## Architecture

- `lib/media/`: backend-neutral domain models and interfaces.
- `lib/services/`: Plex / Jellyfin / Emby integration and supporting services.
- `lib/providers/`: Provider / ChangeNotifier state.
- `lib/mpv/player/` and `android/app/src/main/kotlin/`: playback backends.
- `lib/widgets/video_controls/`: playback UI and timeline painters.
- `lib/danmaku/`: danmaku sources, matching, session, filtering and heatmap.
- `lib/focus/`: TV and gamepad focus infrastructure; keep controls reachable.
- `lib/i18n/*.i18n.json`: slang source translations, with English as the base.
- `lib/theme/`: custom themes, tokens and presentation helpers.

## Rules

- Preserve Plex, Jellyfin, Emby, Watch Together and mobile / TV support.
- Keep mpv and ExoPlayer; do not replace them when adding an optional backend.
- Danmaku gateways are user-configured. Do not add a built-in gateway or third-party AppId / secret.
- Do not commit credentials, signing material, server data, build output, third-party APKs or reverse-engineering dumps.
- Do not edit generated Dart files directly. Change their sources and run `scripts/codegen.sh`.
- Use slang for user-facing text and focusable wrappers for interactive TV controls.
- Treat historical design and implementation notes as context, not proof of current behavior or completed testing.
- Do not revert unrelated contributor changes.

## Validation

Run `flutter analyze` and `scripts/run_tests.sh` before committing. For broader validation run `scripts/ci_checks.sh`; use `scripts/codegen.sh --check` to check generated output. Keep one logical change per commit and disclose any checks that could not run.
