//
//  PermissionsService.swift
//  film space
//

import AVFoundation
import Photos

/// Normalised permission outcome, independent of which framework reported it.
enum MediaPermission: Equatable {
    case authorized
    case denied
    case undetermined
    case restricted
}

/// Thin, testable wrapper around microphone (AVFoundation) and add-only photo
/// library (Photos) authorization. The `map` functions are pure so the policy
/// can be unit tested without prompting; the `request` helpers are the only
/// parts that touch the live frameworks.
enum PermissionsService {

    static func map(_ status: AVAuthorizationStatus) -> MediaPermission {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .undetermined
        @unknown default: return .denied
        }
    }

    static func map(_ status: PHAuthorizationStatus) -> MediaPermission {
        switch status {
        case .authorized, .limited: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .undetermined
        @unknown default: return .denied
        }
    }

    static var microphone: MediaPermission {
        map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    static var photoAddOnly: MediaPermission {
        map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    static func requestMicrophone(_ completion: @escaping (MediaPermission) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted ? .authorized : .denied)
        }
    }

    static func requestPhotoAddOnly(_ completion: @escaping (MediaPermission) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            completion(map(status))
        }
    }
}
