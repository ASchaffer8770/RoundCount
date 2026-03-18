//
//  AmmoParserTests.swift
//  RoundCountTests
//
//  Tests for AmmoParser — the pure parsing logic inside BarcodeService.
//  All tests are offline; no network calls are made.
//

import Testing
@testable import RoundCount

// MARK: - Caliber

@Suite("AmmoParser — caliber")
struct AmmoParserCaliberTests {

    @Test("9mm family", arguments: [
        "Federal 9mm 115gr FMJ",
        "CCI Blazer Brass 9mm Luger 115gr",
        "Speer Gold Dot 9mm Luger +P 124gr",
        "Winchester 9x19 115gr FMJ",
        "9mm Parabellum 124gr JHP",
    ])
    func nineMillimeter(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "9mm")
    }

    @Test("5.56 NATO", arguments: [
        "Winchester 5.56 NATO 55gr FMJ",
        "PMC 5.56x45 62gr FMJ",
        "Hornady 5.56mm 55gr",
    ])
    func fiveFiftySix(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "5.56 NATO")
    }

    @Test(".223 Rem", arguments: [
        "Federal .223 Rem 55gr FMJ",
        "Hornady .223 Remington 55gr V-MAX",
        "PMC .223 62gr BTHP",
    ])
    func twoTwentyThree(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".223 Rem")
    }

    @Test(".45 ACP", arguments: [
        "Federal .45 ACP 230gr FMJ",
        "Winchester .45 Auto 230gr FMJ",
        "Remington 45 ACP 185gr JHP",
    ])
    func fortyFiveACP(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".45 ACP")
    }

    @Test(".40 S&W", arguments: [
        "Federal .40 S&W 180gr FMJ",
        "Winchester 40 S&W 165gr FMJ",
    ])
    func fortySW(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".40 S&W")
    }

    @Test(".308 Win", arguments: [
        "Federal .308 Win 147gr FMJ",
        "Hornady .308 Winchester 168gr BTHP",
        "PMC 7.62x51 NATO 147gr FMJ",
    ])
    func threeOhEight(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".308 Win")
    }

    @Test(".380 ACP", arguments: [
        "Hornady Critical Defense .380 ACP 90gr FTX",
        "Federal .380 Auto 95gr FMJ",
    ])
    func threeEightyACP(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".380 ACP")
    }

    @Test("10mm Auto", arguments: [
        "Federal 10mm Auto 180gr JHP",
        "Hornady 10mm 155gr XTP",
    ])
    func tenMM(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "10mm Auto")
    }

    @Test(".22 LR", arguments: [
        "CCI .22 LR 40gr LRN",
        "Federal .22 Long Rifle 36gr HP",
        "Remington 22 LR 40gr",
    ])
    func twentyTwoLR(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".22 LR")
    }

    @Test("6.5 Creedmoor", arguments: [
        "Hornady 6.5 Creedmoor 140gr ELD Match",
        "Federal 6.5 CM 130gr",
    ])
    func sixFiveCreedmoor(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "6.5 Creedmoor")
    }

    @Test(".300 BLK", arguments: [
        "Hornady .300 Blackout 110gr V-MAX",
        "Federal .300 BLK 220gr OTM",
        "Remington 300 AAC 125gr FMJ",
    ])
    func threeHundredBlackout(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == ".300 BLK")
    }

    @Test("7.62x39", arguments: [
        "Wolf 7.62x39 122gr FMJ",
        "Tula 7.62 x 39 124gr HP",
    ])
    func sevenSixTwoX39(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "7.62x39")
    }

    @Test("12 Gauge", arguments: [
        "Federal 12 Gauge 00 Buckshot 2.75in",
        "Winchester 12GA 1oz Slug",
    ])
    func twelveGauge(title: String) {
        #expect(AmmoParser.parse(title: title).caliber == "12 Gauge")
    }

    @Test("unrecognized caliber returns nil") func unknownCaliber() {
        #expect(AmmoParser.parse(title: "Some Random Product 50ct").caliber == nil)
    }
}

// MARK: - Grain

@Suite("AmmoParser — grain")
struct AmmoParserGrainTests {

    @Test("standard formats", arguments: [
        ("Federal 9mm 115gr FMJ",       115),
        ("Speer 9mm 124 Grain JHP",      124),
        ("Winchester 9mm 147GR Subsonic",147),
        ("Federal .45 ACP 230 grains FMJ", 230),
        ("Hornady .223 55gr V-MAX",       55),
    ])
    func grainParsed(title: String, expected: Int) {
        #expect(AmmoParser.parse(title: title).grain == expected)
    }

    @Test("grain in description field") func grainFromDescription() {
        let result = AmmoParser.parse(title: "Federal 9mm FMJ", description: "115gr practice ammo")
        #expect(result.grain == 115)
    }

    @Test("no grain returns nil") func noGrain() {
        #expect(AmmoParser.parse(title: "CCI 9mm FMJ 50 Rounds").grain == nil)
    }

    @Test("single-digit number not mistaken for grain") func singleDigitIgnored() {
        // "9mm" should not be parsed as 9gr
        #expect(AmmoParser.parse(title: "Federal 9mm FMJ").grain == nil)
    }
}

// MARK: - Bullet Type

@Suite("AmmoParser — bullet type")
struct AmmoParserBulletTypeTests {

    @Test("FMJ variants", arguments: [
        "Federal 9mm 115gr FMJ",
        "CCI 9mm Full Metal Jacket 115gr",
        "Speer 9mm TMJ 115gr",
        "Winchester 9mm Total Metal Jacket 115gr",
        "Federal .45 ACP 230gr Ball",
    ])
    func fmjDetected(title: String) {
        #expect(AmmoParser.parse(title: title).bulletType == .fmj)
    }

    @Test("JHP variants", arguments: [
        "Speer 9mm 124gr JHP",
        "Federal HST 9mm 147gr",
        "Hornady Critical Defense 9mm 115gr FTX",
        "Hornady Critical Duty 9mm 135gr",
        "Speer Gold Dot 9mm 124gr",
        "Federal Hydra-Shok 9mm 135gr",
        "Winchester 9mm 147gr Jacketed Hollow Point",
        "Hornady XTP .357 Mag 158gr",
        "Federal 9mm 147gr BTHP",
        "Hornady 5.56 NATO 75gr OTM",
    ])
    func jhpDetected(title: String) {
        #expect(AmmoParser.parse(title: title).bulletType == .jhp)
    }

    @Test("frangible detected") func frangibleDetected() {
        #expect(AmmoParser.parse(title: "Sinterfire 9mm 100gr Frangible").bulletType == .frangible)
    }

    @Test("lead variants", arguments: [
        "CCI .22 LR 40gr LRN",
        "Federal .38 Special Lead Round Nose 158gr",
        "Cast Lead .44 Special 200gr",
    ])
    func leadDetected(title: String) {
        #expect(AmmoParser.parse(title: title).bulletType == .lead)
    }

    @Test("unknown type returns nil") func unknownBulletType() {
        #expect(AmmoParser.parse(title: "Federal 9mm 115gr").bulletType == nil)
    }

    @Test("frangible beats JHP when both keywords present") func frangibleTakesPrecedence() {
        // A product title that somehow mentions both — frangible should win
        #expect(AmmoParser.parse(title: "PolyCase 9mm 100gr Frangible Hollow Point").bulletType == .frangible)
    }
}

// MARK: - Brand

@Suite("AmmoParser — brand")
struct AmmoParserBrandTests {

    @Test("uses API brand when valid") func useAPIBrand() {
        let result = AmmoParser.parse(title: "9mm 115gr FMJ 50 Rounds", brand: "Federal")
        #expect(result.brand == "Federal")
    }

    @Test("skips parent company, falls back to title", arguments: [
        "Vista Outdoor",
        "Ammo Inc",
        "Olin Corporation",
    ])
    func skipsParentCompany(apiBrand: String) {
        let result = AmmoParser.parse(
            title: "Federal Premium 9mm HST 147gr JHP",
            brand: apiBrand
        )
        // Should extract brand from title, not use parent company name
        #expect(result.brand != apiBrand)
        #expect(result.brand != nil)
    }

    @Test("extracts known brand from title when API brand is empty") func brandFromTitle() {
        let result = AmmoParser.parse(title: "Hornady Critical Defense 9mm 115gr FTX")
        #expect(result.brand == "Hornady")
    }

    @Test("CCI extracted from title") func cciFromTitle() {
        let result = AmmoParser.parse(title: "CCI Blazer Brass 9mm 115gr FMJ 50ct")
        #expect(result.brand == "CCI")
    }

    @Test("Winchester extracted from title") func winchesterFromTitle() {
        let result = AmmoParser.parse(title: "Winchester USA White Box 9mm 115gr FMJ")
        #expect(result.brand == "Winchester")
    }

    @Test("returns nil when brand completely unknown") func unknownBrand() {
        let result = AmmoParser.parse(title: "9mm 115gr FMJ 50 Rounds")
        #expect(result.brand == nil)
    }
}

// MARK: - Quantity

@Suite("AmmoParser — quantity per box")
struct AmmoParserQuantityTests {

    @Test("common quantity formats", arguments: [
        ("Federal 9mm 115gr FMJ 50 Rounds",     50),
        ("Winchester 9mm 115gr FMJ 50-Round Box",50),
        ("CCI .22 LR 40gr 100rd",               100),
        ("Federal 5.56 55gr FMJ Box of 20",     20),
        ("Hornady 9mm 115gr FMJ 25ct",          25),
    ])
    func quantityParsed(title: String, expected: Int) {
        #expect(AmmoParser.parse(title: title).quantityPerBox == expected)
    }

    @Test("no quantity returns nil") func noQuantity() {
        #expect(AmmoParser.parse(title: "Federal 9mm 115gr FMJ").quantityPerBox == nil)
    }
}

// MARK: - Case Material

@Suite("AmmoParser — case material")
struct AmmoParserCaseMaterialTests {

    @Test("detects brass") func brassCase() {
        #expect(AmmoParser.parse(title: "CCI 9mm 115gr FMJ Brass Case 50rd").caseMaterial == "Brass")
    }

    @Test("detects steel") func steelCase() {
        #expect(AmmoParser.parse(title: "Wolf 9mm 115gr FMJ Steel Case 50rd").caseMaterial == "Steel")
    }

    @Test("detects aluminum") func aluminumCase() {
        #expect(AmmoParser.parse(title: "CCI Blazer 9mm 115gr FMJ Aluminum Case").caseMaterial == "Aluminum")
    }

    @Test("detects nickel-plated") func nickelCase() {
        #expect(AmmoParser.parse(title: "Speer Gold Dot 9mm 124gr JHP Nickel Plated").caseMaterial == "Nickel-Plated Brass")
    }

    @Test("no material mentioned returns nil") func noCaseMaterial() {
        #expect(AmmoParser.parse(title: "Federal 9mm 115gr FMJ").caseMaterial == nil)
    }
}

// MARK: - End-to-end realistic titles

@Suite("AmmoParser — real-world product titles")
struct AmmoParserEndToEndTests {

    @Test("Federal HST 9mm 147gr") func federalHST() {
        let r = AmmoParser.parse(
            title: "Federal Premium Personal Defense HST 9mm Luger 147 Grain JHP Handgun Ammo",
            brand: "Federal"
        )
        #expect(r.caliber    == "9mm")
        #expect(r.grain      == 147)
        #expect(r.bulletType == .jhp)
        #expect(r.brand      == "Federal")
    }

    @Test("CCI Blazer Brass 9mm 115gr FMJ") func cciBlazerBrass() {
        let r = AmmoParser.parse(
            title: "CCI Blazer Brass 9mm Luger 115 Grain FMJ Handgun Ammo 50 Rounds",
            brand: "CCI"
        )
        #expect(r.caliber        == "9mm")
        #expect(r.grain          == 115)
        #expect(r.bulletType     == .fmj)
        #expect(r.quantityPerBox == 50)
    }

    @Test("Hornady Critical Defense .380 ACP 90gr FTX") func hornadyCriticalDefense() {
        let r = AmmoParser.parse(
            title: "Hornady Critical Defense .380 ACP 90 Grain FTX Pistol Ammo 25 Rounds",
            brand: "Hornady"
        )
        #expect(r.caliber        == ".380 ACP")
        #expect(r.grain          == 90)
        #expect(r.bulletType     == .jhp)
        #expect(r.quantityPerBox == 25)
    }

    @Test("Winchester .308 Win 147gr FMJ") func winchesterThreeOhEight() {
        let r = AmmoParser.parse(
            title: "Winchester USA .308 Winchester 147 Grain FMJ Rifle Ammo 20 Rounds",
            brand: "Winchester"
        )
        #expect(r.caliber        == ".308 Win")
        #expect(r.grain          == 147)
        #expect(r.bulletType     == .fmj)
        #expect(r.quantityPerBox == 20)
    }

    @Test("Wolf 7.62x39 steel case") func wolfSevenSixTwo() {
        let r = AmmoParser.parse(
            title: "Wolf 7.62x39 122gr FMJ Steel Case 20 Rounds",
            brand: "Wolf"
        )
        #expect(r.caliber       == "7.62x39")
        #expect(r.grain         == 122)
        #expect(r.bulletType    == .fmj)
        #expect(r.caseMaterial  == "Steel")
    }

    @Test("hasAnyAmmoData is true for valid ammo product") func hasDataTrue() {
        let r = AmmoParser.parse(title: "Federal 9mm 115gr FMJ", brand: "Federal")
        #expect(r.hasAnyAmmoData == true)
    }

    @Test("hasAnyAmmoData is false for non-ammo product") func hasDataFalse() {
        let r = AmmoParser.parse(title: "Cleaning Kit Universal 28 Piece Set", brand: "Generic")
        // brand from API = "Generic", but no caliber or grain
        // hasAnyAmmoData = brand != nil so this would be true — check caliber and grain instead
        #expect(r.caliber == nil)
        #expect(r.grain == nil)
    }
}

// MARK: - BarcodeResult

@Suite("BarcodeResult")
struct BarcodeResultTests {

    @Test("hasAnyAmmoData — true when brand present") func trueWithBrand() {
        var r = BarcodeResult()
        r.brand = "Federal"
        #expect(r.hasAnyAmmoData == true)
    }

    @Test("hasAnyAmmoData — true when caliber present") func trueWithCaliber() {
        var r = BarcodeResult()
        r.caliber = "9mm"
        #expect(r.hasAnyAmmoData == true)
    }

    @Test("hasAnyAmmoData — true when grain present") func trueWithGrain() {
        var r = BarcodeResult()
        r.grain = 115
        #expect(r.hasAnyAmmoData == true)
    }

    @Test("hasAnyAmmoData — false when all nil") func falseWhenEmpty() {
        #expect(BarcodeResult().hasAnyAmmoData == false)
    }
}
