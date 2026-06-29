# Film space — Foundation Audit

**Audit date:** 2026-06-29
**Branch:** `knosso/hardening-foundation` (fork: `proton4444/film-space`,
upstream: `maxprokopp/film-space`)
**Scope:** Foundation-hardening only — tests, CI, and docs. No behavioural,
architectural, signing, bundle-ID, or app-name changes.

## Repo purpose

Film space is an iOS SwiftUI app for **3D camera-motion capture using ARKit**,
intended as a blocking/camera-reference tool for AI video workflows (e.g.
feeding the recorded camera path into Seedance 2.0 for style transfer). You
block a scene with human stand-ins in Edit mode, then walk the phone through the
scene in Camera mode so physical motion drives the virtual camera, and record
the result to the photo library.

## Current architecture summary

- **`ContentView`** — root view; switches between Edit mode
  (`VirtualStudioView`) and Camera mode (`ARCameraView`) based on
  `sceneState.mode`, and overlays `StudioToolbar`. Owns the single
  `SceneState` and `OrbitCameraController` instances.
- **`SceneState`** (`@Observable`) — owns app `mode`, the `humans` array,
  `selectedHumanID`, `focalLength`, and the `isRecording` flag. Provides the
  scene-graph mutations: `addHuman`, `deleteSelectedHuman`, `selectHuman`,
  `updateHumanPosition/Rotation`, `rotateSelectedHuman`, `cycleFocalLength`.
- **`OrbitCameraController`** (`@Observable`) — Edit-mode orbit camera math:
  azimuth/elevation/distance/target, `orbit`/`pan`/`zoom`/`move*`, lock &
  return-to-pose, and the `lookAtTransform` matrix helper. Clamps zoom to
  [1.5, 20] and elevation to [-1.45, 1.45].
- **`VirtualStudioView`** — RealityKit edit view; handles orbiting, zoom,
  selection, and placement of human stand-ins.
- **`ARCameraView`** — `UIViewRepresentable` over `ARView`; an
  `ARSessionDelegate` coordinator maps ARKit-derived physical camera motion
  onto the virtual camera, rebuilds the scene, and drives recording.
- **`SceneRecorder`** (`@MainActor`) — records the rendered `ARView` snapshots
  (scene only, no SwiftUI overlay) at 30fps via `CADisplayLink` plus
  microphone audio through an `AVCaptureSession`, encoding off-main and saving
  to the photo library.
- Supporting services: `HumanFigureFactory`, `SceneContentBuilder`,
  `SceneEnvironment`.

## Main risks

1. **No license found upstream.** There is no `LICENSE` file in the upstream
   repo. Treat this fork as a technical prototype only — do not redistribute
   binaries, do not submit to the App Store, and do not open an upstream PR
   without the author's permission.
2. **Placeholder tests before this patch.** The only unit test was an empty
   `example()` stub. This branch replaces it with real coverage of
   `FocalLength`, `SceneState`, and `OrbitCameraController`.
3. **No CI before this patch.** Nothing validated builds or tests on push.
   This branch adds a conservative GitHub Actions workflow (see *CI caveat*).
4. **Recording state is only a `Bool`.** `SceneState.isRecording` /
   `SceneRecorder.isRecording` cannot represent a *failed* start or a
   mid-recording error. A failed capture can still present as "recording".
5. **Permission denial is mostly silent.** Microphone and photo-library
   permission failures are not surfaced clearly to the user.
6. **Scene state is not persisted.** Humans, selection, focal length, and
   camera pose are lost when the app terminates; there is no save/load.
7. **No camera-path export.** The recorded video is saved, but there is no
   structured export of the blocking / camera path (shot list, transforms)
   for downstream tools.

## Platform support

- **iPhone + iPad (universal).** `TARGETED_DEVICE_FAMILY = "1,2"`; iPad
  landscape orientations are declared and pointer/trackpad input is enabled.
  iPad needs no separate project or port.
- **Installation requires ARKit** (`UIRequiredDeviceCapabilities = arkit`), so
  the app runs on ARKit-capable iPads only (effectively iPad 5th gen / 2017 and
  later). Camera mode additionally guards on
  `ARWorldTrackingConfiguration.isSupported`.
- **No Android support.** The stack is fully Apple-native (SwiftUI, RealityKit,
  ARKit, AVFoundation, Photos); there is no shared/portable layer. An Android
  build would be a separate app (Kotlin + ARCore + a 3D engine) or a
  cross-platform rewrite (Unity/Flutter), not a modification of this codebase.

## Build / test verification status

- **Local machine:** no `Xcode.app` is installed — only the Command Line
  Tools — so `xcodebuild` and `xcrun simctl` are unavailable. Build and test
  could not be run locally during this audit.
- **Even with Xcode present:** the project targets **iOS 26.0**
  (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, project `objectVersion = 77`), so it
  requires **Xcode 26 / the iOS 26 SDK** to compile. A stable/older Xcode
  cannot build it.
- The new unit tests are written against the actual current APIs and verified
  values (FOV reference numbers match the `2·atan(36/2f)·180/π` formula), but
  they have **not been executed** in this environment. They must be run on a
  machine with Xcode 26 + an iOS 26 simulator.

### CI caveat

GitHub-hosted macOS runners may not yet ship **Xcode 26 / the iOS 26 SDK**. If
the CI job fails at the build/test step because no iOS 26 SDK is available, that
is expected until GitHub provides a compatible image. The workflow is written
to print the available Xcode version and schemes first so the runner's
capability is visible in the logs; bump the `xcode-version` once a compatible
runner image exists.

## Recommended next branches

1. **`knosso/hardening-recording-state`** — replace the `Bool` recording flag
   with an explicit state enum (`idle / starting / recording / failed(reason)`)
   so failures are representable and surfaced.
2. **`knosso/hardening-permissions`** — explicit microphone / photo-library
   permission requests with user-visible handling of denial.
3. **`knosso/feature-project-save-load`** — persist scene state (humans,
   selection, focal length, camera pose) across launches.
4. **`knosso/feature-shot-list-camera-path-export`** — export the blocking and
   camera path (transforms / shot list) for downstream AI video tools.

> Per the engagement constraints, the recording-state rewrite (#1) is **not**
> implemented in this foundation branch. It is captured here as the next branch
> only.
