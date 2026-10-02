import Foundation

public enum EncodedSex: String, CaseIterable, Sendable {
    case female = "Female"
    case male = "Male"
}

/// A complete Gregorian birth date. Unknown dates and BIS numbers are outside this generator's scope.
public struct BirthDate: Equatable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    public init?(year: Int, month: Int, day: Int) {
        guard (1900...2099).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self.calendar.component(.year, from: date) == year,
              Self.calendar.component(.month, from: date) == month,
              Self.calendar.component(.day, from: date) == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(date: Date) {
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public var iso8601: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public struct RegistryNumber: Equatable, Sendable {
    public let birthDate: BirthDate
    public let sex: EncodedSex
    public let sequence: Int
    public let rawValue: String

    public init?(birthDate: BirthDate, sequence: Int) {
        guard (1...998).contains(sequence) else { return nil }
        let body = String(format: "%02d%02d%02d%03d", birthDate.year % 100,
                          birthDate.month, birthDate.day, sequence)
        let checksumInput = Int64(body)! + (birthDate.year >= 2000 ? 2_000_000_000 : 0)
        self.birthDate = birthDate
        self.sex = sequence.isMultiple(of: 2) ? .female : .male
        self.sequence = sequence
        self.rawValue = body + String(format: "%02d", 97 - checksumInput % 97)
    }

    public var formatted: String {
        let d = Array(rawValue)
        return "\(String(d[0...1])).\(String(d[2...3])).\(String(d[4...5]))-\(String(d[6...8])).\(String(d[9...10]))"
    }

    /// Decodes ordinary 1900–2099 numbers and checks the century, date, series, and checksum.
    public static func decode(_ value: String) -> Self? {
        let raw: String
        if value.range(of: #"^[0-9]{2}\.[0-9]{2}\.[0-9]{2}-[0-9]{3}\.[0-9]{2}$"#,
                       options: .regularExpression) != nil {
            raw = value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "")
        } else { raw = value }
        guard raw.utf8.count == 11, raw.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        let d = Array(raw)
        let shortYear = Int(String(d[0...1]))!
        let month = Int(String(d[2...3]))!
        let day = Int(String(d[4...5]))!
        let sequence = Int(String(d[6...8]))!
        for century in [1900, 2000] {
            if let date = BirthDate(year: century + shortYear, month: month, day: day),
               let result = Self(birthDate: date, sequence: sequence), result.rawValue == raw {
                return result
            }
        }
        return nil
    }

    public static func generate<R: RandomNumberGenerator>(birthDate: BirthDate, sex: EncodedSex,
                                                         using random: inout R) -> Self {
        let sequence = Int.random(in: 0..<499, using: &random) * 2 + (sex == .male ? 1 : 2)
        return Self(birthDate: birthDate, sequence: sequence)!
    }

    public static func randomBirthDate<R: RandomNumberGenerator>(through upper: BirthDate,
                                                                using random: inout R) -> BirthDate {
        let lower = min(BirthDate(year: 1940, month: 1, day: 1)!, upper)
        let days = BirthDate.calendar.dateComponents([.day], from: lower.date, to: upper.date).day!
        let offset = Int.random(in: 0...days, using: &random)
        return BirthDate(date: BirthDate.calendar.date(byAdding: .day, value: offset, to: lower.date)!)!
    }
}

public struct BelgianIBAN: Equatable, Sendable {
    public let rawValue: String

    /// Uses bank prefix 539 from the SWIFT registry's Belgian example, with a synthetic account body.
    /// Correct checksums do not establish whether an account exists.
    public init?(account: Int) {
        guard (0...9_999_999).contains(account) else { return nil }
        let body = "539" + String(format: "%07d", account)
        let remainder = Self.mod97(body)
        let bban = body + String(format: "%02d", remainder == 0 ? 97 : remainder)
        // Move BE00 to the end; B = 11 and E = 14.
        let check = 98 - Self.mod97(bban + "111400")
        rawValue = "BE" + String(format: "%02d", check) + bban
    }

    public var formatted: String {
        stride(from: 0, to: rawValue.count, by: 4).map { offset in
            let start = rawValue.index(rawValue.startIndex, offsetBy: offset)
            let end = rawValue.index(start, offsetBy: 4)
            return String(rawValue[start..<end])
        }.joined(separator: " ")
    }

    public static func generate<R: RandomNumberGenerator>(using random: inout R) -> Self {
        var account: Int
        // Do not emit the published reference IBAN.
        repeat { account = Int.random(in: 0...9_999_999, using: &random) } while account == 75_470
        return Self(account: account)!
    }

    /// Checks Belgian length/characters, the international MOD 97 check, and the domestic BBAN check.
    public static func isValid(_ value: String) -> Bool {
        let raw: String
        if value.range(of: #"^BE[0-9]{2} [0-9]{4} [0-9]{4} [0-9]{4}$"#,
                       options: .regularExpression) != nil {
            raw = value.replacingOccurrences(of: " ", with: "")
        } else { raw = value }
        guard raw.utf8.count == 16, raw.hasPrefix("BE"),
              raw.dropFirst(2).utf8.allSatisfy({ (48...57).contains($0) }),
              let internationalCheck = Int(raw.dropFirst(2).prefix(2)),
              (2...98).contains(internationalCheck) else { return false }
        let bban = String(raw.dropFirst(4))
        let remainder = mod97(String(bban.prefix(10)))
        guard Int(bban.suffix(2)) == (remainder == 0 ? 97 : remainder) else { return false }
        return mod97(bban + "1114" + raw.dropFirst(2).prefix(2)) == 1
    }

    private static func mod97(_ digits: String) -> Int {
        digits.utf8.reduce(0) { ($0 * 10 + Int($1 - 48)) % 97 }
    }
}
