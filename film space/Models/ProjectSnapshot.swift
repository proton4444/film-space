//
//  ProjectSnapshot.swift
//  film space
//

import Foundation

/// A Codable snapshot of everything worth persisting between launches: the
/// blocking (human stand-ins + selection), the lens, and the edit camera pose.
/// Stored as flat scalars so the format is stable and independent of SIMD's
/// Codable representation. Transient state (recording, mode) is not persisted.
struct ProjectSnapshot: Codable, Equatable {

    struct Human: Codable, Equatable {
        var id: UUID
        var x: Float
        var y: Float
        var z: Float
        var rotationY: Float
    }

    var humans: [Human]
    var selectedHumanID: UUID?
    var focalLength: Float
    var cameraAzimuth: Float
    var cameraElevation: Float
    var cameraDistance: Float
    var cameraTargetX: Float
    var cameraTargetY: Float
    var cameraTargetZ: Float

    init(scene: SceneState, camera: OrbitCameraController) {
        humans = scene.humans.map {
            Human(id: $0.id, x: $0.position.x, y: $0.position.y, z: $0.position.z, rotationY: $0.rotationY)
        }
        selectedHumanID = scene.selectedHumanID
        focalLength = scene.focalLength.rawValue
        cameraAzimuth = camera.azimuth
        cameraElevation = camera.elevation
        cameraDistance = camera.distance
        cameraTargetX = camera.target.x
        cameraTargetY = camera.target.y
        cameraTargetZ = camera.target.z
    }

    /// Applies this snapshot back onto live state. A missing/unknown focal
    /// length falls back to the default rather than failing.
    func apply(to scene: SceneState, camera: OrbitCameraController) {
        scene.restore(
            humans: humans.map {
                HumanPlacement(id: $0.id, position: [$0.x, $0.y, $0.z], rotationY: $0.rotationY)
            },
            selectedHumanID: selectedHumanID,
            focalLength: FocalLength(rawValue: focalLength) ?? .mm35
        )
        camera.restore(
            azimuth: cameraAzimuth,
            elevation: cameraElevation,
            distance: cameraDistance,
            target: [cameraTargetX, cameraTargetY, cameraTargetZ]
        )
    }
}
