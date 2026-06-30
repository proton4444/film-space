//
//  OrbitCameraController.swift
//  film space
//

import Observation
import RealityKit
import simd

@Observable
final class OrbitCameraController {
    var azimuth: Float = 0.6
    var elevation: Float = 0.35
    var distance: Float = 6
    var target: SIMD3<Float> = [0, 0.8, 0]

    private(set) var cameraEntity: Entity?

    func makeCameraEntity() -> Entity {
        let camera = Entity()
        camera.components.set(PerspectiveCameraComponent())
        cameraEntity = camera
        updateCameraTransform()
        return camera
    }

    func orbit(deltaAzimuth: Float, deltaElevation: Float) {
        azimuth += deltaAzimuth
        elevation = min(max(elevation + deltaElevation, -1.45), 1.45)
        updateCameraTransform()
    }

    /// Restores the orbit pose from a saved snapshot.
    func restore(azimuth: Float, elevation: Float, distance: Float, target: SIMD3<Float>) {
        self.azimuth = azimuth
        self.elevation = elevation
        self.distance = distance
        self.target = target
        updateCameraTransform()
    }

    func pan(deltaX: Float, deltaY: Float) {
        let cosA = cos(azimuth)
        let sinA = sin(azimuth)
        let right = SIMD3<Float>(cosA, 0, -sinA)
        let up = SIMD3<Float>(0, 1, 0)
        let scale = distance * 0.0015
        target += right * (-deltaX * scale) + up * (deltaY * scale)
        updateCameraTransform()
    }

    func zoom(scale: Float) {
        distance = min(max(distance / scale, 1.5), 20)
        updateCameraTransform()
    }

    /// Raises/lowers the whole framing along the world Y axis by moving the
    /// orbit center, detaching it from a fixed height.
    func moveVertically(by delta: Float) {
        target.y += delta
        updateCameraTransform()
    }

    /// Pans the orbit center left/right relative to the current view direction.
    func moveHorizontally(by delta: Float) {
        let right = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
        target += right * delta
        updateCameraTransform()
    }

    /// Dollies the whole rig forward/backward along the view direction
    /// (projected onto the ground plane).
    func moveForward(by delta: Float) {
        let forward = SIMD3<Float>(-sin(azimuth), 0, -cos(azimuth))
        target += forward * delta
        updateCameraTransform()
    }

    // MARK: - Lock / return

    /// A saved camera pose (camera-to-world) that can be returned to.
    var lockedTransform: simd_float4x4?

    /// Latest camera pose while in Camera mode, written by the AR view so the
    /// lock button can capture the current viewpoint.
    var liveCameraTransform: simd_float4x4?

    /// Set by the return button in Camera mode; consumed by the AR view to snap
    /// the camera back to the locked pose at the current physical position.
    var pendingRecenter: Bool = false

    /// Set by the shoulder button in Camera mode; consumed by the AR view to
    /// place the camera at the center point at ~1.5 m, using the phone's tilt.
    var pendingShoulderPlacement: Bool = false

    /// Eye height used when placing the camera at shoulder level.
    static let shoulderHeight: Float = 1.5

    func lockEditPose() {
        lockedTransform = worldTransform
    }

    /// Restores the orbit camera to look from the locked eye along the locked
    /// direction (keeps the current orbit distance).
    func returnToLockedTransform() {
        guard let m = lockedTransform else { return }
        let eye = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        let forward = simd_normalize(SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z))
        let dir = -forward // direction from target toward eye
        elevation = asin(min(max(dir.y, -1), 1))
        azimuth = atan2(dir.x, dir.z)
        target = eye - dir * distance
        updateCameraTransform()
    }

    func updateCameraTransform() {
        guard let camera = cameraEntity else { return }

        let horizontal = distance * cos(elevation)
        let x = horizontal * sin(azimuth)
        let y = distance * sin(elevation)
        let z = horizontal * cos(azimuth)

        camera.position = target + SIMD3(x, y, z)
        camera.look(at: target, from: camera.position, relativeTo: nil)
    }

    /// Camera-to-world transform matching the current orbit pose.
    /// Used as the starting pose when entering Camera mode.
    var worldTransform: simd_float4x4 {
        let horizontal = distance * cos(elevation)
        let x = horizontal * sin(azimuth)
        let y = distance * sin(elevation)
        let z = horizontal * cos(azimuth)
        let eye = target + SIMD3<Float>(x, y, z)
        return Self.lookAtTransform(eye: eye, center: target, up: [0, 1, 0])
    }

    static func lookAtTransform(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let zAxis = simd_normalize(eye - center)
        let xAxis = simd_normalize(simd_cross(up, zAxis))
        let yAxis = simd_cross(zAxis, xAxis)
        return simd_float4x4(
            SIMD4<Float>(xAxis, 0),
            SIMD4<Float>(yAxis, 0),
            SIMD4<Float>(zAxis, 0),
            SIMD4<Float>(eye, 1)
        )
    }
}
