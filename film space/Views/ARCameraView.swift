//
//  ARCameraView.swift
//  film space
//

import SwiftUI
import RealityKit
import ARKit

struct ARCameraView: UIViewRepresentable {
    @Bindable var sceneState: SceneState
    var cameraController: OrbitCameraController

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneState: sceneState, cameraController: cameraController)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(SceneEnvironment.studioGrey)
        context.coordinator.setup(in: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.sceneState = sceneState
        context.coordinator.rebuildScene()
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.recorder.stop()
        coordinator.sceneState.forceStopRecording()
        coordinator.trackingSession.pause()
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        var sceneState: SceneState
        let cameraController: OrbitCameraController
        var editCameraTransform: simd_float4x4
        let trackingSession = ARSession()
        let recorder = SceneRecorder()

        private weak var arView: ARView?
        private var studioRoot: Entity?
        private var cameraEntity: Entity?
        private var referenceTransform: simd_float4x4?
        private var lastHumanSignature = ""
        private var lastFocalLength: FocalLength?

        init(sceneState: SceneState, cameraController: OrbitCameraController) {
            self.sceneState = sceneState
            self.cameraController = cameraController
            self.editCameraTransform = cameraController.worldTransform
        }

        func setup(in arView: ARView) {
            self.arView = arView

            let anchor = AnchorEntity(world: .zero)

            let root = SceneEnvironment.makeStudioRoot()
            anchor.addChild(root)
            studioRoot = root

            let camera = Entity()
            camera.components.set(PerspectiveCameraComponent())
            camera.transform = Transform(matrix: editCameraTransform)
            anchor.addChild(camera)
            cameraEntity = camera

            arView.scene.addAnchor(anchor)

            rebuildScene()
            startTracking()
        }

        private func startTracking() {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            trackingSession.delegate = self
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = []
            config.environmentTexturing = .none
            trackingSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        func rebuildScene() {
            guard let root = studioRoot else { return }

            let signature = sceneState.humans
                .map { "\($0.id)-\($0.position)-\($0.rotationY)" }
                .joined(separator: "|")
            guard signature != lastHumanSignature else { return }
            lastHumanSignature = signature

            SceneContentBuilder.syncHumans(
                placements: sceneState.humans,
                selectedID: nil,
                into: root
            )
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let deviceTransform = frame.camera.transform
            Task { @MainActor in
                self.applyDeviceMotion(deviceTransform)
            }
        }

        @MainActor
        private func applyDeviceMotion(_ deviceTransform: simd_float4x4) {
            // Return-to-lock: rebase onto the locked pose at the current physical
            // position so the camera snaps back to the locked spot.
            if cameraController.pendingRecenter, let locked = cameraController.lockedTransform {
                editCameraTransform = locked
                referenceTransform = deviceTransform
                cameraController.pendingRecenter = false
            }

            // Shoulder placement: jump to the center point at ~1.5 m, keeping the
            // phone's current orientation (tilt + heading), then track from there.
            if cameraController.pendingShoulderPlacement {
                var placed = deviceTransform
                placed.columns.3 = SIMD4<Float>(
                    cameraController.target.x,
                    OrbitCameraController.shoulderHeight,
                    cameraController.target.z,
                    1
                )
                editCameraTransform = placed
                referenceTransform = deviceTransform
                cameraController.pendingShoulderPlacement = false
            }

            if referenceTransform == nil {
                referenceTransform = deviceTransform
            }
            guard let reference = referenceTransform, let camera = cameraEntity else { return }

            let edit = editCameraTransform

            // Orientation: start at the edit-mode look direction, then apply the
            // device's rotation since Camera mode began (free look-around).
            let deltaRotation = simd_quatf(rotation(reference).transpose * rotation(deviceTransform))
            let newRotation = simd_quatf(rotation(edit)) * deltaRotation

            // Position: apply the device's *world-space* displacement so vertical
            // stays vertical and horizontal stays horizontal — height no longer
            // couples with distance. Yaw-align it so physical "forward" still
            // heads toward the scene from the edit-mode viewpoint.
            let worldDelta = translation(deviceTransform) - translation(reference)
            let yawAlign = simd_quatf(angle: yaw(of: edit) - yaw(of: reference), axis: [0, 1, 0])
            let newPosition = translation(edit) + yawAlign.act(worldDelta)

            camera.transform = Transform(scale: .one, rotation: newRotation, translation: newPosition)
            cameraController.liveCameraTransform = camera.transform.matrix

            applyFocalLengthIfNeeded()
            syncRecording()
        }

        private func syncRecording() {
            guard let arView else { return }
            if sceneState.isRecording, !recorder.isRecording {
                recorder.start(arView: arView) { [weak sceneState] result in
                    switch result {
                    case .started:
                        sceneState?.recordingDidStart()
                    case .failed(let reason):
                        sceneState?.recordingDidFail(reason)
                    }
                }
            } else if !sceneState.isRecording, recorder.isRecording {
                recorder.stop { [weak sceneState] saved in
                    guard !saved else { return }
                    Task { @MainActor in
                        sceneState?.recordingDidFail("Couldn't save the recording to your photo library. Check Photos access in Settings.")
                    }
                }
            }
        }

        private func applyFocalLengthIfNeeded() {
            guard let camera = cameraEntity else { return }
            let focal = sceneState.focalLength
            guard focal != lastFocalLength else { return }
            lastFocalLength = focal

            var component = camera.components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent()
            component.fieldOfViewInDegrees = focal.horizontalFOVDegrees
            camera.components.set(component)
        }

        private func rotation(_ m: simd_float4x4) -> simd_float3x3 {
            simd_float3x3(
                SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
            )
        }

        private func translation(_ m: simd_float4x4) -> SIMD3<Float> {
            SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        }

        /// Heading (rotation about world up) of a camera-to-world transform,
        /// derived from its forward (-Z) axis projected onto the ground plane.
        private func yaw(of m: simd_float4x4) -> Float {
            let forward = SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z)
            return atan2(forward.x, forward.z)
        }
    }
}
