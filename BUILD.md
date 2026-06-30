# Building & Testing Film space

Film space is an iOS SwiftUI app using **RealityKit** and **ARKit**. The Xcode
project name contains a space, so always quote paths and scheme names
(`"film space.xcodeproj"`, scheme `"film space"`).

## Requirements (observed in the project)

| Setting | Value | Source |
|---|---|---|
| iOS deployment target | **iOS 26.0** | `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in `project.pbxproj` |
| Required toolchain | **Xcode 26** (matching the iOS 26 SDK) | implied by the iOS 26 target + `objectVersion = 77` project format |
| Swift version | 5.0 language mode | `SWIFT_VERSION = 5.0` |
| Device family | iPhone + iPad (`1,2`) | `TARGETED_DEVICE_FAMILY` |
| Test framework | Swift Testing (`import Testing`) | `film spaceTests` |

> The iOS 26 deployment target means a stable/older Xcode **cannot open or
> build this project**. You need an Xcode that ships the iOS 26 SDK. If your
> machine only has the Command Line Tools (no `Xcode.app`), `xcodebuild` and
> `xcrun simctl` are unavailable — install full Xcode first.

## iPad support

The app is a **universal iPhone + iPad** target — iPad is supported out of the
box, no separate project or port is required:

- `TARGETED_DEVICE_FAMILY = "1,2"` — builds and installs for iPhone **and** iPad.
- `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = LandscapeLeft
  LandscapeRight` — iPad runs in landscape (matching the recommended
  orientation).
- `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES` — trackpad /
  pointer input is supported on iPad.

**Caveat — ARKit is required to install.**
`INFOPLIST_KEY_UIRequiredDeviceCapabilities = arkit` restricts installation to
ARKit-capable devices. In practice that is **every iPad from 2017 onward**
(iPad 5th gen and later, all recent iPad Pro / Air / mini); older iPads are
excluded. `ARCameraView` also guards Camera mode with
`ARWorldTrackingConfiguration.isSupported`.

**Caveat — Camera mode needs a real iPad.** As with iPhone, ARKit world
tracking does not run in the Simulator. Edit mode and the unit tests are
device-independent and run anywhere with the iOS 26 SDK.

> Note: this is **not** an Android-capable app. The stack is Apple-native
> (SwiftUI / RealityKit / ARKit / AVFoundation) and has no Android target;
> "cross-platform" here means iPhone + iPad only.

## Open in Xcode

```bash
open "film space.xcodeproj"
```

Then select the `film space` scheme and an iOS 26 simulator or a connected
device.

## Build from the command line (no signing)

Use `CODE_SIGNING_ALLOWED=NO` so you do not need the original signing team to
verify a build. **Do not** change `DEVELOPMENT_TEAM` to make builds pass.

```bash
xcodebuild \
  -project "film space.xcodeproj" \
  -scheme "film space" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Run the tests

Unit tests live in `film spaceTests/` and use Swift Testing. They cover pure
logic (`FocalLength`, `SceneState`, `OrbitCameraController`) and do not require
AR hardware. Pick an available iOS 26 simulator:

```bash
# See which simulators exist
xcrun simctl list devices available

xcodebuild \
  -project "film space.xcodeproj" \
  -scheme "film space" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

If `iPhone 16` is not installed, substitute any available iPhone simulator name
from the `simctl list` output.

## Code signing notes

- For local build verification and CI, prefer `CODE_SIGNING_ALLOWED=NO`. This
  builds the binary without provisioning.
- Running on a **physical device** requires a valid signing identity /
  provisioning profile. The checked-in `DEVELOPMENT_TEAM` (`A77Y59F5HZ`)
  belongs to the upstream author; substitute your own team in Xcode's
  Signing & Capabilities tab for on-device runs. Do not commit that change to
  this fork.

## ARKit / device notes

- **Camera mode** drives the virtual camera from real-world phone motion via
  ARKit world tracking. This needs a **real device** with a rear camera and
  motion sensors.
- The **iOS Simulator does not provide real ARKit tracking.** It can compile
  and launch the app and exercise Edit mode / unit tests, but Camera-mode
  tracking, recording from the AR view, and microphone capture will not behave
  as they do on hardware.
- Recording saves to the photo library, which also requires the relevant
  privacy permissions on a real device.

## Known limitations

- Simulator runs cannot validate ARKit tracking, the recorded camera path, or
  real audio capture.
- CI **is** validated on the iOS 26 SDK: GitHub-hosted `macos-latest` runners
  currently provide **Xcode 26.5** with an iPhone 17 Pro simulator, and the
  workflow builds and runs the unit tests green there. (Local machines without
  full Xcode still cannot build — see the requirements above.)
