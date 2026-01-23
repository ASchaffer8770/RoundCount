//
//  PhotoMx.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/21/26.
//

import Foundation
import SwiftData

enum PhotoMaintenance {

    /// V1 (SwiftData-backed): photos are stored in `SessionPhoto.imageData` (external storage).
    /// This purge removes corrupt/empty photo records.
    static func purgeCorruptPhotos(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SessionPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else { return }

        var deleted = 0

        for p in photos {
            // If bytes are missing/corrupt, delete the record.
            if p.imageData.isEmpty {
                modelContext.delete(p)
                deleted += 1
            }
        }

        if deleted > 0 {
            try? modelContext.save()
            print("🧹 Purged corrupt SessionPhoto records:", deleted)
        }
    }
}
