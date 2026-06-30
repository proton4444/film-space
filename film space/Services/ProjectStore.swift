//
//  ProjectStore.swift
//  film space
//

import Foundation

/// Persists a ProjectSnapshot as JSON in the app's Documents directory.
/// Every operation is best-effort: any failure (missing file, corrupt data,
/// write error) is swallowed so persistence can never crash the app or block a
/// fresh start. A nil load simply means "start with an empty studio".
enum ProjectStore {

    static let filename = "film-space-project.json"

    static var defaultURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(filename)
    }

    static func save(_ snapshot: ProjectSnapshot, to url: URL = ProjectStore.defaultURL) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(from url: URL = ProjectStore.defaultURL) -> ProjectSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProjectSnapshot.self, from: data)
    }

    static func clear(at url: URL = ProjectStore.defaultURL) {
        try? FileManager.default.removeItem(at: url)
    }
}
