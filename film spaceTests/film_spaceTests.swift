//
//  film_spaceTests.swift
//  film spaceTests
//
//  Unit tests for the pure model/controller logic that backs the studio:
//  lens math (FocalLength), scene-graph mutations (SceneState), and the
//  orbit camera math (OrbitCameraController). These tests intentionally avoid
//  RealityKit view/runtime setup so they exercise only deterministic logic.
//

import Testing
import Foundation
import simd
@testable import film_space

// MARK: - FocalLength

struct FocalLengthTests {

    @Test func labelsMatchMillimetres() {
        #expect(FocalLength.mm35.label == "35mm")
        #expect(FocalLength.mm50.label == "50mm")
        #expect(FocalLength.mm75.label == "75mm")
        #expect(FocalLength.mm200.label == "200mm")
    }

    /// Horizontal FOV for a 36mm full-frame sensor. Reference values come from
    /// 2 * atan(36 / (2 * f)) * 180 / pi.
    @Test func horizontalFOVApproximations() {
        let tolerance: Float = 0.05
        #expect(abs(FocalLength.mm35.horizontalFOVDegrees - 54.43) < tolerance)
        #expect(abs(FocalLength.mm50.horizontalFOVDegrees - 39.60) < tolerance)
        #expect(abs(FocalLength.mm75.horizontalFOVDegrees - 26.99) < tolerance)
        #expect(abs(FocalLength.mm200.horizontalFOVDegrees - 10.29) < tolerance)
    }

    @Test func fovDecreasesAsFocalLengthIncreases() {
        #expect(FocalLength.mm35.horizontalFOVDegrees > FocalLength.mm50.horizontalFOVDegrees)
        #expect(FocalLength.mm50.horizontalFOVDegrees > FocalLength.mm75.horizontalFOVDegrees)
        #expect(FocalLength.mm75.horizontalFOVDegrees > FocalLength.mm200.horizontalFOVDegrees)
    }
}

// MARK: - SceneState

struct SceneStateTests {

    @Test func addHumanSelectsTheNewlyAddedHuman() {
        let state = SceneState()
        state.addHuman()
        #expect(state.humans.count == 1)
        #expect(state.selectedHumanID == state.humans.last?.id)

        state.addHuman()
        #expect(state.humans.count == 2)
        #expect(state.selectedHumanID == state.humans.last?.id)
        #expect(state.selectedHuman?.id == state.humans[1].id)
    }

    @Test func deleteSelectedHumanRemovesOnlyTheSelectedHuman() {
        let state = SceneState()
        state.addHuman() // index 0
        state.addHuman() // index 1
        state.addHuman() // index 2

        let firstID = state.humans[0].id
        let middleID = state.humans[1].id
        let lastID = state.humans[2].id

        // Select the middle human explicitly, then delete it.
        state.selectHuman(id: middleID)
        state.deleteSelectedHuman()

        #expect(state.humans.count == 2)
        #expect(!state.humans.contains { $0.id == middleID })
        #expect(state.humans.contains { $0.id == firstID })
        #expect(state.humans.contains { $0.id == lastID })
    }

    @Test func rotateSelectedHumanChangesOnlyTheSelectedHuman() {
        let state = SceneState()
        state.addHuman() // index 0
        state.addHuman() // index 1

        let firstID = state.humans[0].id
        let secondID = state.humans[1].id

        state.selectHuman(id: secondID)
        let firstBefore = state.humans.first { $0.id == firstID }!.rotationY
        let secondBefore = state.humans.first { $0.id == secondID }!.rotationY

        state.rotateSelectedHuman(by: 0.5)

        let firstAfter = state.humans.first { $0.id == firstID }!.rotationY
        let secondAfter = state.humans.first { $0.id == secondID }!.rotationY

        #expect(firstAfter == firstBefore)
        #expect(secondAfter == secondBefore + 0.5)
    }
}

// MARK: - OrbitCameraController

struct OrbitCameraControllerTests {

    @Test func zoomClampsDistanceBetween1_5And20() {
        let zoomedTooClose = OrbitCameraController()
        // A very large scale divides distance down toward zero -> clamp to 1.5.
        zoomedTooClose.zoom(scale: 1000)
        #expect(zoomedTooClose.distance == 1.5)

        let zoomedTooFar = OrbitCameraController()
        // A tiny scale divides distance up toward infinity -> clamp to 20.
        zoomedTooFar.zoom(scale: 0.0001)
        #expect(zoomedTooFar.distance == 20)

        let zoomedInRange = OrbitCameraController()
        zoomedInRange.distance = 6
        zoomedInRange.zoom(scale: 2) // 6 / 2 = 3, within range
        #expect(zoomedInRange.distance == 3)
    }

    @Test func orbitClampsElevationBetweenNeg1_45And1_45() {
        let up = OrbitCameraController()
        up.orbit(deltaAzimuth: 0, deltaElevation: 100)
        #expect(up.elevation == 1.45)

        let down = OrbitCameraController()
        down.orbit(deltaAzimuth: 0, deltaElevation: -100)
        #expect(down.elevation == -1.45)
    }

    @Test func orbitAzimuthAccumulatesWithoutClamping() {
        let controller = OrbitCameraController()
        let before = controller.azimuth
        controller.orbit(deltaAzimuth: 1.0, deltaElevation: 0)
        #expect(controller.azimuth == before + 1.0)
    }

    @Test func lookAtTransformReturnsFiniteValues() {
        let m = OrbitCameraController.lookAtTransform(
            eye: [3, 2, 5],
            center: [0, 0.8, 0],
            up: [0, 1, 0]
        )
        let columns = [m.columns.0, m.columns.1, m.columns.2, m.columns.3]
        for column in columns {
            #expect(column.x.isFinite)
            #expect(column.y.isFinite)
            #expect(column.z.isFinite)
            #expect(column.w.isFinite)
        }
        // Eye position should be carried through in the translation column.
        #expect(m.columns.3.x == 3)
        #expect(m.columns.3.y == 2)
        #expect(m.columns.3.z == 5)
    }
}
