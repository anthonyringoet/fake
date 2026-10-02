import Testing
@testable import FakeCore

struct BelgianValuesTests {
    @Test func testOfficialRegistryExample() throws {
        let number = try #require(RegistryNumber.decode("42.01.22-051.81"))
        #expect(number.birthDate.iso8601 == "1942-01-22")
        #expect(number.sex == .male)
        #expect(number.formatted == "42.01.22-051.81")
        #expect(RegistryNumber.decode(number.rawValue) == number)
    }

    @Test func testCenturyAndLeapDay() throws {
        // Independent arithmetic fixtures around the century boundary.
        let old = try #require(RegistryNumber(birthDate: BirthDate(year: 1999, month: 12, day: 31)!, sequence: 998))
        let new = try #require(RegistryNumber(birthDate: BirthDate(year: 2000, month: 1, day: 1)!, sequence: 1))
        #expect(old.rawValue == "991231998" + String(format: "%02d", 97 - 991_231_998 % 97))
        #expect(new.rawValue == "000101001" + String(format: "%02d", 97 - 2_000_101_001 % 97))
        #expect(RegistryNumber.decode(old.rawValue)?.birthDate.year == 1999)
        #expect(RegistryNumber.decode(new.rawValue)?.birthDate.year == 2000)
        #expect(BirthDate(year: 1900, month: 2, day: 29) == nil)
        #expect(BirthDate(year: 2000, month: 2, day: 29) != nil)
        #expect(BirthDate(year: 2025, month: 2, day: 29) == nil)
        #expect(BirthDate(year: 2024, month: 4, day: 31) == nil)
    }

    @Test func testRegistryRejectsMalformedAndInvalidValues() {
        for value in ["42.01.22-051.82", "42012205100", "42012205198", "42a01b22-051.81",
                      "42012205181x", "４２０１２２０５１８１", "", "42013205181"] {
            #expect(RegistryNumber.decode(value) == nil, "Rejected: \(value)")
        }
        let date = BirthDate(year: 2000, month: 1, day: 1)!
        #expect(RegistryNumber(birthDate: date, sequence: 0) == nil)
        #expect(RegistryNumber(birthDate: date, sequence: 999) == nil)
    }

    @Test func testOfficialIBANExample() throws {
        let iban = try #require(BelgianIBAN(account: 75_470))
        #expect(iban.rawValue == "BE68539007547034")
        #expect(iban.formatted == "BE68 5390 0754 7034")
        #expect(BelgianIBAN.isValid(iban.rawValue))
        #expect(BelgianIBAN.isValid(iban.formatted))
        #expect(BelgianIBAN.isValid("BE62510007547061")) // Febelfin example; another bank prefix.
    }

    @Test func testIBANRejectsBadDomesticCheckEvenWithValidInternationalCheck() {
        let bban = "539007547035" // Domestic check must be 34.
        let check = 98 - Int64(bban + "111400")! % 97
        #expect(!BelgianIBAN.isValid("BE" + String(format: "%02d", check) + bban))
        for value in ["BE69539007547034", "BE68539007547035", "NL68539007547034", "BE685390075470",
                      "BE68 5390 0754 7034x", "BE68-5390-0754-7034", "be68539007547034", ""] {
            #expect(!BelgianIBAN.isValid(value), "Rejected: \(value)")
        }
        #expect(BelgianIBAN(account: -1) == nil)
        #expect(BelgianIBAN(account: 10_000_000) == nil)
    }

    @Test func testDomesticZeroRemainderUses97() throws {
        // Find an account body for which the national checksum has zero remainder.
        let base = Int64(5_390_000_000)
        let account = Int((97 - base % 97) % 97)
        let iban = try #require(BelgianIBAN(account: account))
        #expect(iban.rawValue.hasSuffix("97"))
        #expect(BelgianIBAN.isValid(iban.rawValue))
    }

    @Test func testTenThousandGeneratedPairsWithIndependentChecks() throws {
        var random = SeededRandom(seed: 42)
        let upper = BirthDate(year: 2026, month: 10, day: 2)!
        var centuries = Set<Int>()
        var sexes = Set<String>()
        for i in 0..<10_000 {
            let date = RegistryNumber.randomBirthDate(through: upper, using: &random)
            #expect(date <= upper)
            let sex: EncodedSex = i.isMultiple(of: 2) ? .female : .male
            let registry = RegistryNumber.generate(birthDate: date, sex: sex, using: &random)
            let body = Int64(registry.rawValue.prefix(9))! + (date.year >= 2000 ? 2_000_000_000 : 0)
            #expect(Int(registry.rawValue.suffix(2)) == Int(97 - body % 97))
            #expect(registry.sequence % 2 == (sex == .male ? 1 : 0))
            #expect(RegistryNumber.decode(registry.formatted) == registry)
            centuries.insert(date.year / 100)
            sexes.insert(registry.sex.rawValue)

            let iban = BelgianIBAN.generate(using: &random)
            let bban = String(iban.rawValue.dropFirst(4))
            let nationalRemainder = Int64(bban.prefix(10))! % 97
            #expect(Int64(bban.suffix(2)) == (nationalRemainder == 0 ? 97 : nationalRemainder))
            let rearranged = Int64(bban + "1114" + iban.rawValue.dropFirst(2).prefix(2))!
            #expect(rearranged % 97 == 1)
            #expect(BelgianIBAN.isValid(iban.formatted))
            #expect(iban.rawValue != "BE68539007547034")
        }
        #expect(centuries == [19, 20])
        #expect(sexes == ["Female", "Male"])
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed &+= 0x9e3779b97f4a7c15
        var value = seed
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}
