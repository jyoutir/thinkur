# Dev/Release Split Plan for `thinkur`

## Summary

Refactor the project from one mixed-purpose app identity into two clear lanes built from the same source repo:

- `Dev` lane for day-to-day development on the main machine
- `Release` lane for signed/notarized DMGs and public Sparkle rollout

This plan intentionally removes `Beta` from scope. Release candidate testing will happen by manually sharing the notarized `Release` DMG to the clean second Mac before the appcast is updated.

The key architectural change is:

- `Debug` becomes the dedicated `Dev` app identity
- `Release` stays the public `thinkur` identity
- Sparkle is disabled in `Dev`
- Publishing a DMG is split from publishing the appcast
- The repo moves out of `~/Downloads` into a stable local dev folder such as `~/Developer/thinkur`

This is the recommended shape because the app's core value path depends on macOS permissions. Microphone, Accessibility, and Input Monitoring are central to the app, and the current setup is forcing one app identity to behave as both an unstable development binary and a public distribution binary. That is the root problem.

## Goals

1. Make daily development stable and low-friction on the main machine.
2. Keep macOS permission grants stable for the `Dev` app.
3. Keep public users unaffected until the appcast is explicitly published.
4. Preserve the existing notarized DMG distribution model and Sparkle updater.
5. Simplify scripts so each one has one responsibility.
6. Remove coupling between release staging and public rollout.

## Non-Goals

- No `Beta` bundle ID, beta feed, or beta appcast.
- No CI migration in this plan.
- No repo consolidation between `thinkur` and `thinkur-web`.
- No packaging format change away from DMG.
- No App Store or TestFlight distribution work.

## Chosen Defaults and Assumptions

- Source repo will move from `~/Downloads/thinkur` to a safe working directory such as `~/Developer/thinkur`.
- `Debug` is the `Dev` lane.
- `Release` remains the public lane.
- `Dev` state is isolated from `Release` for app data, defaults, permissions, and non-license secrets.
- License state is shared between `Dev` and `Release` for convenience.
- Normal development workflow defaults to an installed `Dev` app in `~/Applications/thinkur Dev.app`.
- Direct Xcode runs remain available, but only for focused debugger sessions, not as the default loop.
- `thinkur-web` remains the host repo for GitHub release assets and `public/appcast.xml`.
- Manual DMG testing on the clean second Mac is the gate before public rollout.
- Public rollout only happens when `publish-appcast` is run.

## Why This Design

### 1. Separate app identities fix the permission churn problem

Reasoning:

- Apple’s signing model treats identity and trust as properties of the signed app.
- The repo currently uses one bundle ID for both Debug and Release in `project.yml`, while switching signing identity between Apple Development and Developer ID.
- The current workaround is to reset TCC on every Debug build in `project.yml`, which confirms the existing setup is unstable.

Conclusion:

- `Debug` must become `com.jyo.thinkur.dev`.
- `Release` remains `com.jyo.thinkur`.
- `Dev` and `Release` must not share the same permission surface.

This split is an implementation inference from Apple’s code-signing identity model and the repo’s observed TCC instability, not a direct Apple requirement that development builds must use a separate bundle ID.

### 2. DMG publication must be separated from appcast publication

Reasoning:

- Sparkle updates are driven by the appcast feed, not by the mere existence of a DMG asset.
- The current public rollout path is bundled together in `scripts/publish-release.sh`, which both uploads the DMG and updates `appcast.xml`.
- GitHub draft releases are a safe staging area because draft releases are only visible to collaborators with repository access.

Conclusion:

- Building and staging a DMG must not update the production appcast.
- Public rollout must be a separate explicit command.

### 3. `~/Downloads` must stop being the canonical repo location

Reasoning:

- The repo already documents a repeatable macOS provenance/xattr problem when build tools touch the checkout in `~/Downloads` in `docs/building.md` and `CLAUDE.md`.
- The release build script already works around this by copying to `/tmp` in `scripts/build-dmg.sh`.

Conclusion:

- The main working repo must move to `~/Developer/thinkur` or similar.
- The `/tmp` copy pattern for release builds stays.

### 4. `Dev` should not talk to the public updater or pollute production telemetry

Reasoning:

- `UpdaterService` currently always starts Sparkle in `Sources/thinkur/Core/UpdaterService.swift`.
- `SUFeedURL` is hard-coded to production in `Sources/thinkur/Resources/Info.plist`.
- `TelemetryService` always initializes TelemetryDeck in `Sources/thinkur/Core/TelemetryService.swift`.

Conclusion:

- Sparkle must be disabled in `Dev`.
- Telemetry should be disabled in `Dev` by build config to avoid polluting metrics.

## Desired End State

### Repo and working directories

Use this layout:

- `~/Developer/thinkur` for the main source repo
- `~/Developer/thinkur-web` for the website/appcast repo
- `~/Applications/thinkur Dev.app` for the installed development app
- `/Applications/thinkur.app` for public release installs
- `/tmp/thinkur-release-*` as transient release build workspace

Do not keep `~/Downloads/thinkur` as the canonical repo after migration.

### Build identities

Use one target with two identities driven by configuration:

| Configuration | Purpose | Bundle ID | Product Name | Signing | Sparkle | Telemetry |
| --- | --- | --- | --- | --- | --- | --- |
| `Debug` | Development | `com.jyo.thinkur.dev` | `thinkur Dev` | Apple Development | Off | Off |
| `Release` | Public distribution | `com.jyo.thinkur` | `thinkur` | Developer ID Application | On | On |

## Implementation Plan

## Phase 0: Repo relocation and safety baseline

### Work items

1. Move or re-clone the working repo to `~/Developer/thinkur`.
2. Move or verify `thinkur-web` at `~/Developer/thinkur-web`.
3. Update local docs to make `~/Developer/thinkur` the canonical path.
4. Treat the old `~/Downloads/thinkur` checkout as deprecated.

### Acceptance criteria

- No official docs instruct building from `~/Downloads`.
- All examples reference a safe working directory.
- Release build still uses `/tmp` isolation.

## Phase 1: Build configuration split

### Changes in `project.yml`

Modify `project.yml` so that `Debug` and `Release` explicitly diverge on identity and behavior.

### Add these build settings

Add the following user-defined settings to the app target:

| Setting | Debug value | Release value | Purpose |
| --- | --- | --- | --- |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.jyo.thinkur.dev` | `com.jyo.thinkur` | Separate identities |
| `PRODUCT_NAME` | `thinkur Dev` | `thinkur` | Separate app names |
| `THINKUR_APP_MODE` | `dev` | `release` | Runtime behavior switch |
| `THINKUR_SUPPORT_DIR_NAME` | `thinkur-dev` | `thinkur` | Separate app data location |
| `THINKUR_ENABLE_SPARKLE` | `NO` | `YES` | Disable updater in Dev |
| `THINKUR_SU_FEED_URL` | empty string | `https://thinkur.app/appcast.xml` | Feed only in Release |
| `THINKUR_ENABLE_TELEMETRY` | `NO` | `YES` | Keep dev noise out of analytics |
| `THINKUR_DEV_INSTALL_PATH` | `$HOME/Applications/thinkur Dev.app` | empty string | Dev install target |
| `THINKUR_SHARED_LICENSE_SERVICE` | `com.jyo.thinkur.license` | `com.jyo.thinkur.license` | Shared license cache |
| `THINKUR_SECRET_SERVICE_PREFIX` | `com.jyo.thinkur.dev` | `com.jyo.thinkur` | Isolate non-license secrets |

### Scheme behavior

Keep a single main scheme unless implementation friction demands two schemes. Simpler is better here.

For the main scheme:

- `Run` uses `Debug`
- `Test` uses `Debug`
- `Archive` uses `Release`

Remove the current Debug post-action that resets TCC on every build in `project.yml`.

Replace it with a Debug-only post-action that installs the built app to `~/Applications/thinkur Dev.app` by calling a dedicated script.

Do not auto-reset TCC in the normal workflow anymore.

### Acceptance criteria

- `Debug` builds produce `thinkur Dev.app` with bundle ID `com.jyo.thinkur.dev`.
- `Release` archives produce `thinkur.app` with bundle ID `com.jyo.thinkur`.
- Building Debug no longer runs `tccutil reset`.

## Phase 2: Runtime configuration layer

### New internal type

Add a small internal configuration abstraction, for example:

- `Sources/thinkur/Core/AppRuntimeConfiguration.swift`

This type should read from `Bundle.main.infoDictionary` and expose:

- `appMode`
- `displayName`
- `bundleIdentifier`
- `isSparkleEnabled`
- `sparkleFeedURL`
- `isTelemetryEnabled`
- `supportDirectoryName`
- `sharedLicenseService`
- `secretServicePrefix`
- `isDevelopmentBuild`

This should be the single place where build settings are interpreted at runtime.

### Why add this type

Without it, build-mode branching will spread across `Info.plist`, `Constants`, `UpdaterService`, `TelemetryService`, onboarding views, and secret storage. The abstraction reduces drift and makes the behavior testable.

### Acceptance criteria

- No runtime code reads raw custom plist keys in more than one place.
- `Dev` and `Release` behavior can be reasoned about from one type.

## Phase 3: `Info.plist` refactor

### Changes in `Info.plist`

Update `Sources/thinkur/Resources/Info.plist` to stop hard-coding release-only values.

Make these substitutions:

- `CFBundleName` -> `$(PRODUCT_NAME)`
- add `CFBundleDisplayName` -> `$(PRODUCT_NAME)` if needed for clearer UI naming
- `SUFeedURL` -> `$(THINKUR_SU_FEED_URL)`

Add custom keys for runtime configuration if the implementation reads them from plist:

- `ThinkurAppMode` -> `$(THINKUR_APP_MODE)`
- `ThinkurEnableSparkle` -> `$(THINKUR_ENABLE_SPARKLE)`
- `ThinkurEnableTelemetry` -> `$(THINKUR_ENABLE_TELEMETRY)`
- `ThinkurSupportDirName` -> `$(THINKUR_SUPPORT_DIR_NAME)`
- `ThinkurSharedLicenseService` -> `$(THINKUR_SHARED_LICENSE_SERVICE)`
- `ThinkurSecretServicePrefix` -> `$(THINKUR_SECRET_SERVICE_PREFIX)`

Keep `SUPublicEDKey` unchanged.

### Acceptance criteria

- `Dev` app bundle metadata clearly reflects `thinkur Dev`.
- `Release` keeps the production Sparkle feed.
- `Dev` does not ship a usable production feed URL.

## Phase 4: Persistence and secret isolation

### App Support directory separation

`Sources/thinkur/Utilities/Constants.swift` currently hard-codes `Application Support/thinkur`.

Change this so the root directory is based on runtime configuration:

- `Dev` -> `~/Library/Application Support/thinkur-dev`
- `Release` -> `~/Library/Application Support/thinkur`

This affects:

- analytics store
- shortcuts store
- style preferences store
- meetings store
- speaker profiles store
- audio files
- cached models
- any other files under `Constants.appSupportDirectory`

### License sharing

Keep the license keychain service shared between `Dev` and `Release`.

Implementation rule:

- `KeychainHelper` should support a caller-provided or configuration-provided service name.
- `LicenseManager` uses `com.jyo.thinkur.license` in both modes.

Reason:

- This preserves convenience and avoids forced re-activation in `Dev`.

### Non-license secret separation

Parameterize any non-license keychain service strings by app mode or service prefix.

At minimum update:

- `Sources/thinkur/Core/SmartHome/HueBridgeBackend.swift` keychain service
- any other non-license keychain service constants found during implementation

### Acceptance criteria

- `Dev` and `Release` do not share history/data/model caches.
- `Dev` and `Release` do share license state.
- `Dev` and `Release` do not share integration secrets unless intentionally configured.

## Phase 5: Updater behavior split

### Changes in `UpdaterService`

Refactor `Sources/thinkur/Core/UpdaterService.swift` so Sparkle is optional.

Implementation behavior:

- if `isSparkleEnabled == false`, do not create or start `SPUStandardUpdaterController`
- `checkForUpdates()` becomes a no-op when disabled
- expose `isEnabled` so the UI can react
- log a single informational message in Dev like `Updater disabled for dev build`

Keep Release behavior the same:

- automatic checks
- 4 hour interval
- initial lightweight probe
- existing delegate behavior

### UI adjustments

Update the UI so Dev does not imply updater behavior that does not exist.

In these files:

- `Sources/thinkur/UI/Pages/SystemSettingsView.swift`
- `Sources/thinkur/UI/MainWindow/SidebarView.swift`

Rules:

- hide the `Automatic Updates` toggle when updater is disabled
- hide the sidebar update banner when updater is disabled
- do not show empty or disabled updater UI in Dev

### Acceptance criteria

- Dev never checks the production feed.
- Dev never shows update UI.
- Release behavior is unchanged.

## Phase 6: Dev install workflow

### New script

Add a new script:

- `scripts/install-dev-app.sh`

Responsibilities:

- accept the built app path from Xcode environment variables
- ensure `~/Applications` exists
- install the built Debug product to `~/Applications/thinkur Dev.app` using `ditto`
- replace the previous installed dev app cleanly
- optionally stop the running Dev app before overwrite
- never touch Release installs in `/Applications`

### Xcode integration

The Debug build post-action in `project.yml` should call `scripts/install-dev-app.sh`.

It should use Xcode-provided variables such as:

- `BUILT_PRODUCTS_DIR`
- `FULL_PRODUCT_NAME`
- `CONFIGURATION`

Only run this step for `Debug`.

### Day-to-day dev workflow after this change

Use this as the documented normal loop:

1. Edit code in `~/Developer/thinkur`.
2. Run `xcodegen generate` when files, schemes, or settings change.
3. Build in Xcode.
4. Let the build install `~/Applications/thinkur Dev.app`.
5. Launch `~/Applications/thinkur Dev.app`.
6. Do permission-sensitive testing there.
7. If debugger attachment is needed, use `Debug > Attach to Process` for the installed Dev app.
8. Reserve direct `Cmd+R` sessions for targeted debugging, not as the normal loop.

### Important note

Because the app’s core functionality depends on permissions, the normal loop must favor the installed Dev app. Direct Xcode runs are still allowed, but they are not the solution to the TCC problem.

### Acceptance criteria

- a successful Debug build refreshes `~/Applications/thinkur Dev.app`
- permission grants are associated with the installed Dev app, not a disposable DerivedData path
- the documented default workflow no longer depends on automatic TCC resets

## Phase 7: Manual permission repair tool

### Existing script refactor

Refactor `scripts/dev-permissions.sh`.

New behavior:

- rename to `scripts/dev-reset-permissions.sh`
- target `com.jyo.thinkur.dev`
- update messaging to refer to `thinkur Dev`
- keep it as a manual repair tool only

Do not call it automatically from Xcode.

### Acceptance criteria

- Dev permission reset is explicit and manual.
- The default development path no longer trains developers to wipe permissions on every build.

## Phase 8: Naming and permission copy cleanup

### Dynamic display name usage

Onboarding and permission help text currently hard-code `thinkur` in places that matter for System Settings instructions, for example in `Sources/thinkur/UI/Onboarding/OnboardingStepView.swift`.

Update permission-facing and install-facing strings to use the runtime display name where it improves clarity.

Files to review:

- `Sources/thinkur/UI/Onboarding/OnboardingStepView.swift`
- `Sources/thinkur/UI/Pages/PermissionsView.swift`
- `Sources/thinkur/UI/Pages/MeetingSetupView.swift`
- `Sources/thinkur/thinkurApp.swift`

Scope rule:

- update permission instructions and menu labels that need to reflect `thinkur Dev`
- do not attempt a full brand-copy audit in this plan

### Acceptance criteria

- when Dev asks the user to enable permissions, the name shown in instructions matches the installed app name closely enough to avoid confusion

## Phase 9: Telemetry split

### Changes in `TelemetryService`

Refactor `Sources/thinkur/Core/TelemetryService.swift` so it respects build mode.

Behavior:

- if telemetry is disabled by config, skip `TelemetryDeck.initialize`
- `send(...)` should no-op when telemetry is disabled
- optionally hide or disable the analytics toggle in Dev; hiding is simpler and preferred

Reason:

- Dev metrics are not product metrics.
- Keeping telemetry off in Dev prevents noisy data.

### Acceptance criteria

- Dev does not initialize TelemetryDeck.
- Release telemetry behavior remains unchanged.

## Phase 10: Release script simplification

## Script topology after refactor

Keep the current DMG build core, but split staging from public rollout.

### Final script set

| Script | Keep / Add / Change | New responsibility |
| --- | --- | --- |
| `scripts/release-preflight.sh` | Change | Validate local release prerequisites for building and staging only |
| `scripts/bump-version.sh` | Change lightly | Bump version and build number only |
| `scripts/build-dmg.sh` | Keep and refine | Build signed, notarized DMG only |
| `scripts/stage-release.sh` | Add | Create or update a GitHub draft release with the DMG asset only |
| `scripts/publish-appcast.sh` | Add | Generate and push appcast, then publish the draft release |
| `scripts/release.sh` | Change | Thin orchestrator with explicit verbs, not one giant auto-publish path |
| `scripts/dev-reset-permissions.sh` | Rename from current | Manual repair tool only |
| `scripts/install-dev-app.sh` | Add | Install Debug build to `~/Applications` |

### Simplification goals

- one script should not both stage candidate bits and make them public
- appcast generation should not be a prerequisite for DMG building
- normal release preflight should not require Sparkle appcast tooling
- publishing should be explicit

## Phase 11: `release-preflight.sh` refactor

### Current problem

`scripts/release-preflight.sh` currently requires `generate_appcast` in DerivedData and requires `thinkur-web` before any release work starts.

That is too early and too coupled for the new flow.

### New behavior

`release-preflight.sh` should validate only what is needed before creating a release candidate DMG:

- `xcodegen`
- `create-dmg`
- `gh`
- `xcrun`
- `Developer ID Application` certificate
- notarization profile
- clean git tree
- correct branch or explicit override
- presence of `thinkur-web` only if `stage-release.sh` still needs it for the release asset repo

Remove from default preflight:

- `generate_appcast`
- DerivedData search

Add a second publish-only preflight inside `publish-appcast.sh` for:

- `generate_appcast`
- `thinkur-web`
- release notes conversion prerequisites if any

### Acceptance criteria

- it is possible to build and stage a DMG without having appcast tooling installed
- appcast tooling is only required when actually publishing

## Phase 12: Deterministic Sparkle tooling

### Current problem

Both `scripts/release-preflight.sh` and `scripts/publish-release.sh` search DerivedData for `generate_appcast`.

That is brittle and couples publishing to arbitrary local Xcode state.

### New approach

Use a deterministic Sparkle tool path.

Preferred implementation:

- add `scripts/bootstrap-release-tools.sh`
- pin Sparkle tools to the same version used by the app
- download or extract Sparkle’s distribution archive into a stable local cache such as `~/.cache/thinkur/tools/sparkle-<version>/`
- `publish-appcast.sh` should use that exact cached `generate_appcast` path

Fallback:

- allow an override env var such as `SPARKLE_GENERATE_APPCAST`
- fail with a clear message if the tool is missing

Also fix the Sparkle version drift:

- align `Package.swift` with `project.yml`
- choose `2.8.0` unless there is a separate reason to move both to another pinned version

### Acceptance criteria

- no script searches DerivedData for `generate_appcast`
- Sparkle dependency version is consistent across the repo

## Phase 13: `build-dmg.sh` keep and refine

### Keep as-is conceptually

`scripts/build-dmg.sh` already has the correct macro-shape:

- `xcodegen generate`
- copy source to `/tmp`
- archive in temp workspace
- export
- verify code signature
- create DMG
- sign DMG
- notarize
- staple
- verify with `spctl`
- copy artifact back

That should remain the Release build engine.

### Required refinements

- update comments so it is clearly the public Release build path
- use a shared helper for version reading instead of duplicating `grep` and `sed` logic across scripts
- keep `spctl` validation
- keep `notarytool`
- keep the `/tmp` isolation
- ensure the script never updates appcast or GitHub releases

### Acceptance criteria

- running `build-dmg.sh` only creates a notarized DMG
- public users are unaffected

## Phase 14: Add `stage-release.sh`

### Purpose

Create or update a GitHub draft release that contains the DMG asset, but do not update the appcast.

### Behavior

`stage-release.sh` should:

1. read version and tag from `project.yml`
2. validate the DMG exists in `build/`
3. create or update a GitHub draft release in `jyoutir/thinkur-web`
4. attach the DMG asset
5. use `RELEASE_NOTES.md` if present
6. leave the release as draft

### Important rule

A draft release is the staging artifact for clean-second-Mac testing. It is not public rollout.

### Acceptance criteria

- it is possible to create a draft release with the DMG asset
- no appcast changes occur
- public Sparkle users do not see the release

## Phase 15: Add `publish-appcast.sh`

### Purpose

Make a previously staged release public to Sparkle users.

### Behavior

`publish-appcast.sh` should:

1. validate the DMG exists
2. validate the Sparkle `generate_appcast` tool exists in the deterministic location or env override
3. create an appcast staging directory
4. copy the DMG into it
5. convert `RELEASE_NOTES.md` to HTML if needed
6. run `generate_appcast`
7. copy the resulting `appcast.xml` into `thinkur-web/public/appcast.xml`
8. commit and push that appcast change in `thinkur-web`
9. publish the GitHub draft release, for example via `gh release edit <tag> --draft=false`

### Ordering rule

Make the release public only after the appcast commit has been pushed.

This preserves the principle that public visibility and public update availability become live together.

### Acceptance criteria

- running `publish-appcast.sh` is the only step that makes the new version visible to Sparkle users
- if the appcast step is never run, public users stay on the old version

## Phase 16: `release.sh` orchestration redesign

### Current problem

`scripts/release.sh` currently assumes a single full-release path ending in automatic publish.

That is no longer the desired model.

### New interface

Refactor `release.sh` to use explicit verbs:

- `./scripts/release.sh prepare patch`
- `./scripts/release.sh prepare minor`
- `./scripts/release.sh prepare major`
- `./scripts/release.sh publish`

### `prepare` behavior

`prepare <bump>` should:

1. run build/stage preflight
2. bump version and build number
3. run `xcodegen generate`
4. commit the version bump
5. create the version tag
6. build the notarized DMG
7. push the commit and tag
8. create or update the GitHub draft release with the DMG asset
9. stop and print next steps for manual validation on the clean second Mac

It must not update the appcast.

### `publish` behavior

`publish` should run `publish-appcast.sh`.

### Output messaging

At the end of `prepare`, print a short checklist:

- install DMG on clean second Mac
- verify permissions, onboarding, licensing, updater behavior, and first launch
- when approved, run `./scripts/release.sh publish`

### Acceptance criteria

- there is no single command that automatically pushes a public Sparkle update without a deliberate publish step
- the release flow matches the manual DMG validation requirement

## Phase 17: Shared script helper library

### Purpose

Reduce duplicated shell logic.

### Add

Create a small shared helper script, for example:

- `scripts/lib/release-common.sh`

Move into it:

- project root resolution
- version and build parsing
- tag derivation
- common validation helpers
- logging helpers

### Why

Current scripts duplicate version parsing and path setup. This is low-grade complexity that makes release logic harder to maintain.

### Acceptance criteria

- version parsing logic lives in one place
- release scripts are shorter and clearer

## Phase 18: Documentation cleanup

### Files to update

- `docs/building.md`
- `CLAUDE.md`
- main README if applicable

### Doc changes

Document exactly this model:

- main repo belongs in `~/Developer/thinkur`
- `Debug` is `thinkur Dev`
- Dev workflow is build, install, and launch installed app
- direct Xcode runs are for targeted debugging only
- Release workflow is `prepare` then manual clean-Mac validation then `publish`
- DMG staging does not update public users
- appcast publish is the public switch
- Sparkle tooling no longer depends on DerivedData

Also fix current contradictions:

- `docs/building.md` says Debug copies to `/Applications` but the current scheme does not
- `CLAUDE.md` says both `never run xcodebuild in Downloads` and also provides commands that do exactly that in that location
- `Package.swift` and `project.yml` disagree on Sparkle version

### Acceptance criteria

- a new engineer can follow the docs without hitting contradictory instructions
- the docs reflect the actual implemented workflow

## Important Interfaces and Public-Facing Changes

## Build-time interfaces

These are the new build/config interfaces the implementing agent should add:

- `THINKUR_APP_MODE`
- `THINKUR_SUPPORT_DIR_NAME`
- `THINKUR_ENABLE_SPARKLE`
- `THINKUR_SU_FEED_URL`
- `THINKUR_ENABLE_TELEMETRY`
- `THINKUR_SHARED_LICENSE_SERVICE`
- `THINKUR_SECRET_SERVICE_PREFIX`
- `THINKUR_DEV_INSTALL_PATH`

## Internal runtime interfaces

Add one internal type:

- `AppRuntimeConfiguration`

Expected responsibilities:

- interpret build mode
- expose runtime behavior flags
- centralize config access

## Script interfaces

Final command surface to document and support:

- `./scripts/release.sh prepare patch|minor|major`
- `./scripts/release.sh publish`
- `./scripts/build-dmg.sh`
- `./scripts/stage-release.sh`
- `./scripts/publish-appcast.sh`
- `./scripts/dev-reset-permissions.sh`
- `./scripts/install-dev-app.sh`

## Test Cases and Validation Scenarios

## A. Dev identity and permissions

1. build Debug in Xcode
2. confirm installed app path is `~/Applications/thinkur Dev.app`
3. confirm bundle ID is `com.jyo.thinkur.dev`
4. grant Microphone, Accessibility, and Input Monitoring to `thinkur Dev`
5. rebuild Debug and reinstall
6. relaunch `thinkur Dev`
7. confirm permissions remain granted
8. confirm TCC is not reset automatically

Expected result:

- Dev permissions are stable across rebuild and install cycles.

## B. Dev updater isolation

1. launch `thinkur Dev`
2. confirm no Sparkle check occurs
3. confirm no update banner appears
4. confirm no `Automatic Updates` setting is shown

Expected result:

- Dev does not touch production update infrastructure.

## C. Dev persistence isolation

1. use Dev to create history, shortcuts, analytics records, and meetings
2. launch Release build on another machine or later on the same machine
3. confirm Release does not see Dev-created data
4. confirm Dev and Release use different Application Support roots

Expected result:

- Dev and Release data are separated.

## D. License sharing

1. activate license in Release
2. launch Dev
3. confirm Dev recognizes the existing license without re-activation

Expected result:

- license cache is shared as intended

## E. Non-license secret isolation

1. configure an integration in Dev
2. launch Release
3. confirm Release does not automatically inherit that integration secret

Expected result:

- non-license secrets are isolated

## F. Release build safety

1. run `./scripts/build-dmg.sh` from the safe repo location
2. confirm the script builds in `/tmp`
3. confirm it outputs a notarized DMG in `build/`
4. confirm it does not update GitHub releases or appcast

Expected result:

- build only, no public effect

## G. Draft release staging

1. run `./scripts/release.sh prepare patch`
2. confirm version bump commit and tag are created and pushed
3. confirm a GitHub draft release exists with the DMG attached
4. confirm no appcast change has been pushed yet

Expected result:

- release candidate is staged but not public to Sparkle users

## H. Clean second Mac validation

1. install the staged Release DMG on the clean second Mac
2. test first launch
3. test onboarding and permission prompts
4. test activation and license state
5. test normal dictation flow
6. test auto-update UI behavior
7. confirm this is all happening before appcast publish

Expected result:

- release candidate is manually validated before public rollout

## I. Public publish

1. run `./scripts/release.sh publish`
2. confirm `appcast.xml` is regenerated and pushed to `thinkur-web/public/`
3. confirm the draft release becomes published
4. confirm the Release app now sees the update from Sparkle

Expected result:

- public rollout happens only at this step

## J. Failure-mode tests

1. missing `generate_appcast` tool when running `publish`
2. missing `thinkur-web` repo when running `publish`
3. dirty git tree when running `prepare`
4. missing notarization profile when running `build`
5. DMG missing when running `stage-release` or `publish-appcast`

Expected result:

- each script fails early with a clear, actionable message

## Rollout Order

Implement in this order:

1. move repo location and update docs references
2. split Debug and Release build settings in `project.yml`
3. add `AppRuntimeConfiguration`
4. isolate persistence and secrets
5. disable Sparkle and telemetry in Dev
6. add `install-dev-app.sh` and Xcode Debug install post-action
7. refactor Dev UI around updater visibility
8. split release scripts into build, stage, and publish
9. remove DerivedData Sparkle tool discovery
10. update docs and run full validation

This order minimizes confusion because the Dev identity split is foundational. Script work should happen after the build and runtime behavior is correct.

## Risks and Mitigations

### Risk: direct Xcode runs still reintroduce permission weirdness

Mitigation:

- document them as debugger-only
- default workflow is the installed Dev app

### Risk: shared license cache may still surprise some edge cases

Mitigation:

- keep the sharing intentional and scoped only to license state
- separate all other state

### Risk: publishing order mismatch between appcast and GitHub release visibility

Mitigation:

- `publish-appcast.sh` should push the appcast first, then publish the draft release

### Risk: Sparkle tool bootstrap adds complexity

Mitigation:

- keep an env-var override
- fail clearly
- remove DerivedData heuristics entirely

### Risk: docs and scripts drift again

Mitigation:

- treat `project.yml` and script command interfaces as the source of truth
- update docs in the same implementation pass

## Sources Used

### External primary sources

- Apple TN2206, macOS Code Signing In Depth  
  https://developer.apple.com/library/archive/technotes/tn2206/_index.html

- Apple Developer ID overview  
  https://developer.apple.com/developer-id/

- Apple macOS distribution guidance  
  https://developer.apple.com/macos/distribution/

- Apple notarization workflow for scripted and custom flows  
  https://developer.apple.com/documentation/security/customizing-the-notarization-workflow

- Apple Developer ID certificate glossary  
  https://developer.apple.com/help/glossary/developer-id-certificate/

- Sparkle main documentation  
  https://sparkle-project.org/documentation/

- Sparkle publishing updates and appcast guidance  
  https://sparkle-project.org/documentation/publishing/

- GitHub release management docs  
  https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

- GitHub CLI `gh release edit` docs  
  https://cli.github.com/manual/gh_release_edit

### Repo-local sources

- build settings and current TCC reset workaround in `project.yml`
- provenance and xattr warnings in `docs/building.md`
- conflicting build instructions in `CLAUDE.md`
- current release build flow in `scripts/build-dmg.sh`
- current monolithic publish flow in `scripts/publish-release.sh`
- current preflight coupling in `scripts/release-preflight.sh`
- current updater behavior in `Sources/thinkur/Core/UpdaterService.swift`
- current permission behavior in `Sources/thinkur/Core/PermissionManager.swift`
- current shared app data path in `Sources/thinkur/Utilities/Constants.swift`
- current shared license service in `Sources/thinkur/Utilities/KeychainHelper.swift`
- current telemetry initialization in `Sources/thinkur/Core/TelemetryService.swift`

## Final Implementation Outcome

When this plan is complete:

- work will happen from one repo in `~/Developer/thinkur`
- development will happen against `thinkur Dev.app`
- the main machine will stop treating every rebuild as a fresh public app
- Release DMGs will be built without automatically updating users
- the DMG will be manually validated on the clean second Mac
- public users will only update when the appcast is explicitly published

That is the correct simplified model for the stated workflow.
