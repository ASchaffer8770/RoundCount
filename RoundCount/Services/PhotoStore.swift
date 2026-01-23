//
//  PhotoStore.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import Foundation
import UIKit

enum PhotoStore {

    static func saveJPEGForSession(sessionId: UUID, photoId: UUID, jpegData: Data) throws -> String {
        let dir = try sessionDirectory(sessionId: sessionId)
        let filename = "\(photoId.uuidString).jpg"
        let fileURL = dir.appendingPathComponent(filename)

        try jpegData.write(to: fileURL, options: [.atomic])

        // ✅ Relative path (portable)
        return "Sessions/\(sessionId.uuidString)/\(filename)"
    }

    static func loadImage(relativePath: String) -> UIImage? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // ✅ Legacy absolute path support
        if trimmed.hasPrefix("/") {
            return UIImage(contentsOfFile: trimmed)
        }

        guard let url = absoluteURL(relativePath: trimmed) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func absolutePath(for relativePath: String) -> String? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") { return trimmed }
        guard let url = absoluteURL(relativePath: trimmed) else { return nil }
        return url.path
    }

    static func deletePhoto(relativePath: String) {
        guard let abs = absolutePath(for: relativePath) else { return }
        try? FileManager.default.removeItem(atPath: abs)
    }

    static func deleteAllPhotosForSession(sessionId: UUID) {
        do {
            let dir = try sessionDirectory(sessionId: sessionId)
            try FileManager.default.removeItem(at: dir)
        } catch {
            // non-fatal
        }
    }

    // MARK: - Helpers

    private static func sessionDirectory(sessionId: UUID) throws -> URL {
        let base = try documentsDirectory()
        let dir = base
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return dir
    }

    private static func absoluteURL(relativePath: String) -> URL? {
        guard let docs = try? documentsDirectory() else { return nil }
        return docs.appendingPathComponent(relativePath)
    }

    private static func documentsDirectory() throws -> URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "PhotoStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing documents directory"]
            )
        }
        return url
    }
}
