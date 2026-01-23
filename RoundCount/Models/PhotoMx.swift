//
//  PhotoMx.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import SwiftData

enum PhotoMaintenance {
    static func purgeMissingPhotos(modelContext: ModelContext) {
        let fm = FileManager.default

        let descriptor = FetchDescriptor<SessionPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else { return }

        var deleted = 0

        for p in photos {
            guard let abs = PhotoStore.absolutePath(for: p.filePath) else {
                modelContext.delete(p)
                deleted += 1
                continue
            }

            if !fm.fileExists(atPath: abs) {
                modelContext.delete(p)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? modelContext.save()
            print("🧹 Purged missing SessionPhoto records:", deleted)
        }
    }
}

