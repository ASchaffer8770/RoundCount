//
//  ImageStore.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import UIKit
import Combine

enum ImageStore {
    /// Legacy convenience — prefer PhotoStore directly for session/run images.
    static func saveJPEGForSession(_ image: UIImage, sessionId: UUID, photoId: UUID, quality: CGFloat = 0.82) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode JPEG"])
        }
        return try PhotoStore.saveJPEGForSession(sessionId: sessionId, photoId: photoId, jpegData: data)
    }

    static func loadImage(pathOrRelative: String) -> UIImage? {
        PhotoStore.loadImage(relativePath: pathOrRelative) // supports legacy absolute + new relative
    }

    static func delete(pathOrRelative: String) {
        if let abs = PhotoStore.absolutePath(for: pathOrRelative) {
            try? FileManager.default.removeItem(atPath: abs)
        }
    }
}

