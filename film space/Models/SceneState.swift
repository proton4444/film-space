//
//  SceneState.swift
//  film space
//

import Foundation
import RealityKit

enum AppMode: String, CaseIterable {
    case edit = "Edit"
    case camera = "Camera"
}

/// Explicit lifecycle for a recording so a *failed* capture is representable
/// and surfaced, instead of a single Bool that can't distinguish "recording"
/// from "tried to record but the writer never started".
enum RecordingState: Equatable {
    case idle
    case starting
    case recording
    case failed(reason: String)
}

enum FocalLength: Float, CaseIterable {
    case mm35 = 35
    case mm50 = 50
    case mm75 = 75
    case mm200 = 200

    var label: String { "\(Int(rawValue))mm" }

    var next: FocalLength {
        let all = FocalLength.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    /// Horizontal field of view for a full-frame (36mm wide) sensor.
    var horizontalFOVDegrees: Float {
        let sensorWidth: Float = 36
        return 2 * atan(sensorWidth / (2 * rawValue)) * 180 / .pi
    }
}

struct HumanPlacement: Identifiable, Equatable {
    let id: UUID
    var position: SIMD3<Float>
    var rotationY: Float

    init(id: UUID = UUID(), position: SIMD3<Float> = [0, 0, 0], rotationY: Float = 0) {
        self.id = id
        self.position = position
        self.rotationY = rotationY
    }
}

@Observable
final class SceneState {
    var mode: AppMode = .edit
    var humans: [HumanPlacement] = []
    var selectedHumanID: UUID?
    var focalLength: FocalLength = .mm35
    private(set) var recordingState: RecordingState = .idle

    /// Backwards-compatible flag the AR view uses to drive the recorder:
    /// true while a recording is being started or is active.
    var isRecording: Bool {
        recordingState == .starting || recordingState == .recording
    }

    /// User-facing reason when the last recording attempt failed; nil otherwise.
    var recordingFailureMessage: String? {
        if case let .failed(reason) = recordingState { return reason }
        return nil
    }

    func cycleFocalLength() {
        focalLength = focalLength.next
    }

    /// Replaces the blocking state from a restored snapshot. The selection is
    /// only kept if it still refers to an existing human.
    func restore(humans: [HumanPlacement], selectedHumanID: UUID?, focalLength: FocalLength) {
        self.humans = humans
        if let id = selectedHumanID, humans.contains(where: { $0.id == id }) {
            self.selectedHumanID = id
        } else {
            self.selectedHumanID = nil
        }
        self.focalLength = focalLength
    }

    // MARK: - Recording state transitions

    /// Record-button intent: begin starting from idle/failed, or stop when a
    /// recording is already starting or active.
    func toggleRecording() {
        switch recordingState {
        case .idle, .failed:
            recordingState = .starting
        case .starting, .recording:
            recordingState = .idle
        }
    }

    /// The recorder confirmed the writer is active.
    func recordingDidStart() {
        if recordingState == .starting {
            recordingState = .recording
        }
    }

    /// The recorder could not start (or failed mid-capture).
    func recordingDidFail(_ reason: String) {
        recordingState = .failed(reason: reason)
    }

    /// Force back to idle (e.g. when the Camera view is dismantled).
    func forceStopRecording() {
        recordingState = .idle
    }

    var selectedHuman: HumanPlacement? {
        guard let id = selectedHumanID else { return nil }
        return humans.first { $0.id == id }
    }

    func addHuman() {
        let offset = Float(humans.count) * 0.6
        let placement = HumanPlacement(position: [offset, 0, 0])
        humans.append(placement)
        selectedHumanID = placement.id
    }

    func deleteSelectedHuman() {
        guard let id = selectedHumanID else { return }
        humans.removeAll { $0.id == id }
        selectedHumanID = humans.last?.id
    }

    func selectHuman(id: UUID?) {
        selectedHumanID = id
    }

    func updateHumanPosition(id: UUID, position: SIMD3<Float>) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].position = position
    }

    func updateHumanRotation(id: UUID, rotationY: Float) {
        guard let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY = rotationY
    }

    func rotateSelectedHuman(by delta: Float) {
        guard let id = selectedHumanID,
              let index = humans.firstIndex(where: { $0.id == id }) else { return }
        humans[index].rotationY += delta
    }
}
