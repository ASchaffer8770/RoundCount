//
//  BarcodeService.swift
//  RoundCount
//

import Foundation

// MARK: - Result

struct BarcodeResult {
    var brand: String?
    var productLine: String?
    var caliber: String?
    var grain: Int?
    var bulletType: BulletType?
    var quantityPerBox: Int?
    var caseMaterial: String?

    var hasAnyAmmoData: Bool {
        brand != nil || caliber != nil || grain != nil
    }
}

// MARK: - Errors

enum BarcodeServiceError: LocalizedError {
    case notFound
    case rateLimitExceeded
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:          return "Product not found. Fill in the details manually."
        case .rateLimitExceeded: return "Lookup limit reached for today. Fill in manually."
        case .networkError(let e): return e.localizedDescription
        }
    }
}

// MARK: - Service

final class BarcodeService {
    static let shared = BarcodeService()
    private init() {}

    func lookup(upc: String) async throws -> BarcodeResult {
        var components = URLComponents(string: "https://api.upcitemdb.com/prod/trial/lookup")!
        components.queryItems = [URLQueryItem(name: "upc", value: upc)]

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: components.url!)
        } catch {
            throw BarcodeServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw BarcodeServiceError.rateLimitExceeded }
            guard http.statusCode == 200 else { throw BarcodeServiceError.notFound }
        }

        let decoded = try JSONDecoder().decode(UPCLookupResponse.self, from: data)
        guard let item = decoded.items.first else { throw BarcodeServiceError.notFound }

        return AmmoParser.parse(item: item)
    }
}

// MARK: - API Response Models

private struct UPCLookupResponse: Decodable {
    let code: String
    let items: [UPCItem]
}

private struct UPCItem: Decodable {
    let title: String?
    let brand: String?
    let description: String?
}

// MARK: - Ammo Parser

enum AmmoParser {

    /// Primary entry point used by tests (and internally below).
    static func parse(title: String, brand: String = "", description: String = "") -> BarcodeResult {
        let apiBrand = brand
        let haystack = "\(title) \(description)"

        var result = BarcodeResult()
        result.brand        = extractBrand(apiField: apiBrand, title: title)
        result.caliber      = extractCaliber(from: haystack)
        result.grain        = extractGrain(from: haystack)
        result.bulletType   = extractBulletType(from: haystack)
        result.quantityPerBox = extractQuantity(from: haystack)
        result.caseMaterial = extractCaseMaterial(from: haystack)
        result.productLine  = extractProductLine(title: title, brand: result.brand)
        return result
    }

    fileprivate static func parse(item: UPCItem) -> BarcodeResult {
        parse(title: item.title ?? "", brand: item.brand ?? "", description: item.description ?? "")
    }

    // MARK: Brand

    // Known parent companies that aren't the actual ammo brand.
    private static let parentCompanies: Set<String> = [
        "Vista Outdoor", "Ammo Inc", "Olin Corporation", "Remington Arms"
    ]

    // Well-known ammo brands and alternate names to normalize.
    private static let brandPatterns: [(pattern: String, canonical: String)] = [
        ("american eagle",      "Federal"),
        ("federal premium",     "Federal Premium"),
        ("federal",             "Federal"),
        ("cci",                 "CCI"),
        ("blazer brass",        "CCI"),         // Blazer Brass is CCI
        ("blazer",              "CCI"),
        ("speer",               "Speer"),
        ("gold dot",            "Speer"),
        ("hornady",             "Hornady"),
        ("critical defense",    "Hornady"),
        ("critical duty",       "Hornady"),
        ("winchester",          "Winchester"),
        ("remington",           "Remington"),
        ("pmc",                 "PMC"),
        ("fiocchi",             "Fiocchi"),
        ("magtech",             "Magtech"),
        ("aguila",              "Aguila"),
        ("sellier.*bellot",     "Sellier & Bellot"),
        ("wolf",                "Wolf"),
        ("tula",                "Tula"),
        ("herter",              "Herter's"),
        ("freedom munitions",   "Freedom Munitions"),
        ("norma",               "Norma"),
        ("nosler",              "Nosler"),
        ("barnes",              "Barnes"),
        ("sierra",              "Sierra"),
    ]

    private static func extractBrand(apiField: String, title: String) -> String? {
        // Skip known parent companies, fall through to title parsing.
        let useAPI = !apiField.isEmpty && !parentCompanies.contains(where: {
            apiField.localizedCaseInsensitiveContains($0)
        })
        if useAPI { return apiField.capitalized(with: nil) }

        // Scan the title for known brand names.
        let lower = title.lowercased()
        for (pattern, canonical) in brandPatterns {
            if let _ = firstMatch(pattern: "\\b\(pattern)\\b", in: lower) {
                return canonical
            }
        }
        // Fall back to the raw API brand if we found nothing in the title.
        return apiField.isEmpty ? nil : apiField
    }

    // MARK: Caliber

    // Each entry is (regex pattern, canonical display string).
    private static let caliberMap: [(pattern: String, canonical: String)] = [
        // 9mm family
        ("9\\s*mm\\s*(luger|para(bellum)?|x\\s*19)?",       "9mm"),
        ("9\\s*[x×]\\s*19",                                  "9mm"),  // 9x19 / 9×19
        // 5.56 / .223
        ("5\\.56\\s*(x\\s*45)?\\s*(mm)?\\s*(nato)?",        "5.56 NATO"),
        ("\\.223\\s*(rem(ington)?)?",                        ".223 Rem"),
        // .45 family
        ("\\.45\\s*(acp|auto|colt)?",                        ".45 ACP"),
        ("45\\s*(acp|auto)",                                 ".45 ACP"),
        // .40 S&W
        ("\\.40\\s*(s&w|s\\s*&\\s*w|sw|smith)?",            ".40 S&W"),
        ("40\\s*(s&w|sw)",                                   ".40 S&W"),
        // .308 / 7.62x51
        ("\\.308\\s*(win(chester)?)?",                       ".308 Win"),
        ("7\\.62\\s*[x×]\\s*51",                            ".308 Win"),
        // .380 ACP
        ("\\.380\\s*(acp|auto)?",                            ".380 ACP"),
        // 10mm
        ("10\\s*mm\\s*(auto)?",                              "10mm Auto"),
        // .357 Mag
        ("\\.357\\s*(mag(num)?|sig)?",                       ".357 Mag"),
        // .44 Mag
        ("\\.44\\s*(mag(num)?|rem(ington)?\\s*mag(num)?)?",  ".44 Mag"),
        // .22 LR
        ("\\.22\\s*(lr|long\\s*rifle)?",                     ".22 LR"),
        ("22\\s*(lr|long\\s*rifle)",                         ".22 LR"),
        // Shotgun gauges
        ("12\\s*(gauge|ga|g)(?!mm)",                         "12 Gauge"),
        ("20\\s*(gauge|ga|g)(?!mm)",                         "20 Gauge"),
        // 7.62x39
        ("7\\.62\\s*[x×]\\s*39",                            "7.62x39"),
        // 6.5 Creedmoor
        ("6\\.5\\s*(creedmoor|cm)",                          "6.5 Creedmoor"),
        // .300 BLK
        ("\\.300\\s*(blk|blackout|aac)?",                    ".300 BLK"),
        ("300\\s*(blk|blackout|aac)",                        ".300 BLK"),
        // .30-06
        ("\\.30\\s*-\\s*06\\s*(springfield)?",               ".30-06 Springfield"),
        ("30\\s*-\\s*06",                                    ".30-06 Springfield"),
        // .30 Carbine
        ("\\.30\\s*carbine",                                  ".30 Carbine"),
        // 7.62x54R
        ("7\\.62\\s*[x×]\\s*54",                            "7.62x54R"),
        // .243 Win
        ("\\.243\\s*(win(chester)?)?",                       ".243 Win"),
        // .270 Win
        ("\\.270\\s*(win(chester)?)?",                       ".270 Win"),
        // .30-30
        ("\\.30\\s*-\\s*30\\s*(win(chester)?)?",             ".30-30 Win"),
        // 5.45x39
        ("5\\.45\\s*[x×]\\s*39",                            "5.45x39"),
        // .338 Lapua
        ("\\.338\\s*(lapua)?",                               ".338 Lapua"),
        // .50 BMG
        ("\\.50\\s*(bmg)",                                   ".50 BMG"),
        // .357 SIG
        ("\\.357\\s*sig",                                    ".357 SIG"),
        // .45-70
        ("\\.45\\s*-\\s*70",                                 ".45-70 Govt"),
        // .454 Casull
        ("\\.454\\s*(casull)?",                              ".454 Casull"),
        // .460 S&W
        ("\\.460\\s*(s&w|sw)?",                              ".460 S&W"),
        // .500 S&W
        ("\\.500\\s*(s&w|sw)?",                              ".500 S&W"),
    ]

    private static func extractCaliber(from text: String) -> String? {
        for (pattern, canonical) in caliberMap {
            // \b before a literal dot (e.g. \.223) never matches because '.' is not a word char.
            // Use a negative lookbehind instead: "not preceded by a dot or digit".
            let prefix = pattern.hasPrefix("\\.") ? "(?<![.\\d])" : "\\b"
            if let _ = firstMatch(pattern: "\(prefix)\(pattern)\\b", in: text) {
                return canonical
            }
        }
        return nil
    }

    // MARK: Grain

    private static func extractGrain(from text: String) -> Int? {
        // Match patterns like "115gr", "115 grain", "115 grains", "115GR"
        guard let raw = firstCapture(
            pattern: "\\b(\\d{2,3})\\s*gr(ain)?s?\\b",
            in: text
        ) else { return nil }
        return Int(raw)
    }

    // MARK: Bullet Type

    private static func extractBulletType(from text: String) -> BulletType? {
        let lower = text.lowercased()

        // Frangible first (specific)
        if lower.contains("frangible") { return .frangible }

        // JHP indicators
        let jhpKeywords = [
            "jhp", "jacketed hollow", "hollow point", "\\bhp\\b",
            "critical defense", "critical duty", "hst", "xtp",
            "v-crown", "gold dot", "hydra-shok", "hydra shok",
            "hydrashok", "sxt", "bonded", "ftx", "bthp",
            "boat.tail hollow", "otm", "open tip"
        ]
        for kw in jhpKeywords {
            if let _ = firstMatch(pattern: kw, in: lower) { return .jhp }
        }

        // FMJ indicators
        let fmjKeywords = ["fmj", "full metal jacket", "tmj", "total metal jacket", "\\bball\\b"]
        for kw in fmjKeywords {
            if let _ = firstMatch(pattern: kw, in: lower) { return .fmj }
        }

        // Lead indicators
        let leadKeywords = ["\\blrn\\b", "lead round nose", "\\blwc\\b", "lead wad", "\\blswc\\b", "cast lead", "\\blead\\b"]
        for kw in leadKeywords {
            if let _ = firstMatch(pattern: kw, in: lower) { return .lead }
        }

        return nil
    }

    // MARK: Quantity

    private static func extractQuantity(from text: String) -> Int? {
        // "50 rounds", "50-count", "50rd", "box of 50", "50ct"
        let patterns = [
            "\\b(\\d+)\\s*-?\\s*(rounds?|rds?|count|ct)\\b",
            "\\bbox\\s+of\\s+(\\d+)\\b",
        ]
        for p in patterns {
            if let raw = firstCapture(pattern: p, in: text, caseInsensitive: true) {
                if let qty = Int(raw), qty > 0, qty <= 1000 { return qty }
            }
        }
        return nil
    }

    // MARK: Case Material

    private static func extractCaseMaterial(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("aluminum") || lower.contains("aluminium") { return "Aluminum" }
        if lower.contains("steel case") || lower.contains("steel-case") { return "Steel" }
        if lower.contains("nickel") { return "Nickel-Plated Brass" }
        if lower.contains("brass case") || lower.contains("brass-case") { return "Brass" }
        return nil
    }

    // MARK: Product Line

    // Known product line names by brand to scan for in the title.
    private static let productLinePatterns: [String] = [
        "blazer brass", "blazer aluminum",
        "american eagle", "premium",
        "gold medal", "punch", "solid core",
        "white box", "usa ready",
        "super-x", "super x", "aa target",
        "umc", "express", "core-lokt",
        "black hills", "varmint express", "critical defense", "critical duty",
        "match", "frontier", "leverevolution",
        "bronze", "gold",
        "gold dot", "lawman",
        "v-crown", "silvertip",
        "range & train", "trainer",
        "steel case", "polyformance",
    ]

    private static func extractProductLine(title: String, brand: String?) -> String? {
        let lower = title.lowercased()
        for line in productLinePatterns {
            if lower.contains(line) {
                // Title-case the match
                return line.split(separator: " ")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: " ")
            }
        }
        return nil
    }

    // MARK: Regex Helpers

    private static func firstMatch(pattern: String, in text: String, caseInsensitive: Bool = true) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? .caseInsensitive : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text)
        else { return nil }
        return String(text[range])
    }

    private static func firstCapture(pattern: String, in text: String, group: Int = 1, caseInsensitive: Bool = true) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? .caseInsensitive : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > group,
              let range = Range(match.range(at: group), in: text)
        else { return nil }
        return String(text[range])
    }
}
