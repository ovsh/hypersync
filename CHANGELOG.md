# Changelog

All notable product changes shipped in Hypersync releases.

## [0.5.4](https://github.com/ovsh/hypersync/releases/tag/v0.5.4) - 2026-02-18

| Change | Value Prop | Why |
| --- | --- | --- |
| Legacy registry compatibility fixes (`everyone`/`shared-global` root aliasing, schema-aware mapping) | Existing teams with older repo structures sync successfully instead of hard-failing. | Production repos evolved over time; strict assumptions about one layout caused "no usable team roots" failures. |
| Skills markdown rendering performance improvements for large files ([PR #7](https://github.com/ovsh/hypersync/pull/7)) | Faster Skills browsing and less UI lag on heavy markdown content. | Skills pages are a daily hot path; rendering cost directly impacts perceived app quality. |
| Hardened release packaging/publishing pipeline (DMG retries, ZIP-first publishing, resilient asset upload) | Releases consistently include installable binaries (`.dmg`/`.zip`) rather than source-only pages. | Packaging flakes were blocking distribution even when app code was healthy. |

## [0.5.3](https://github.com/ovsh/hypersync/releases/tag/v0.5.3) - 2026-02-17

| Change | Value Prop | Why |
| --- | --- | --- |
| Window routing and onboarding flow refactor ([PR #6](https://github.com/ovsh/hypersync/pull/6)) | Skills window and onboarding presentation are more predictable across launch/reopen states. | Menu bar + dock apps need explicit and reliable window activation logic to avoid "app is running but invisible" failure modes. |
| Dock/launch Skills visibility fixes ([PR #4](https://github.com/ovsh/hypersync/pull/4), [PR #5](https://github.com/ovsh/hypersync/pull/5)) | Clicking the dock icon and launching the app now brings the main UI forward reliably. | This is the primary affordance users rely on; failures here feel like app startup bugs. |
| Onboarding and sync flow cleanup (state handling, failure/retry paths, explicit close path) | Users are less likely to get stuck in onboarding dead-ends and can always recover from sync/setup errors. | Setup is the highest-friction point in adoption; resilient state transitions reduce churn and support load. |
| E2E and planning test coverage additions (`scripts/test_e2e_smoke.sh`, `scripts/run_xcuitests.sh`, planner tests) | Regressions are caught earlier in CI and local validation. | The recent issues were lifecycle/state regressions that unit tests alone missed. |
