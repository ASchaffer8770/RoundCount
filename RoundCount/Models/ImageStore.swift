//
//  ImageStore.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import UIKit

enum ImageStore {
    static func saveJPEG(_ image: UIImage, quality: CGFloat = 0.82) throws -> String {
        let data = image.jpegData(compressionQuality: quality) ?? Data()
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent("session_photo_\(UUID().uuidString).jpg")
        try data.write(to: url, options: [.atomic])
        return url.path
    }

    static func loadImage(path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    static func delete(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}

