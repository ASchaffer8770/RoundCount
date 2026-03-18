//
//  UPCLookupCache.swift
//  RoundCount
//

import Foundation
import SwiftData

/// Persists successful UPC barcode lookups so repeat scans of the same box
/// never hit the network again.
@Model
final class UPCLookupCache {

    @Attribute(.unique) var upc: String

    var brand: String?
    var productLine: String?
    var caliber: String?
    var grain: Int?
    var bulletTypeRaw: String?
    var quantityPerBox: Int?
    var caseMaterial: String?

    var cachedAt: Date

    init(upc: String, result: BarcodeResult) {
        self.upc = upc
        self.brand = result.brand
        self.productLine = result.productLine
        self.caliber = result.caliber
        self.grain = result.grain
        self.bulletTypeRaw = result.bulletType?.rawValue
        self.quantityPerBox = result.quantityPerBox
        self.caseMaterial = result.caseMaterial
        self.cachedAt = Date()
    }

    var asBarcodeResult: BarcodeResult {
        var r = BarcodeResult()
        r.brand = brand
        r.productLine = productLine
        r.caliber = caliber
        r.grain = grain
        r.bulletType = bulletTypeRaw.flatMap { BulletType(rawValue: $0) }
        r.quantityPerBox = quantityPerBox
        r.caseMaterial = caseMaterial
        return r
    }
}
