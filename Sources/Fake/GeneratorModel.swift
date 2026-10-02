import AppKit
import FakeCore
import SwiftUI

enum ValueKind { case registry, iban }
enum SexChoice: String, CaseIterable {
    case random = "Random"
    case female = "Female"
    case male = "Male"
}

@MainActor
final class GeneratorModel: ObservableObject {
    @Published private(set) var registry: RegistryNumber
    @Published private(set) var iban: BelgianIBAN
    @Published var sexChoice = SexChoice.random
    @Published var showsOptions = false
    @Published var randomBirthday = true
    @Published var customBirthday = BirthDate(year: 1995, month: 1, day: 1)!.date
    @Published var copyWithFormatting: Bool {
        didSet { preferences?.set(copyWithFormatting, forKey: "copyWithFormatting") }
    }
    @Published private(set) var copiedKind: ValueKind?
    @Published private(set) var clipboardError = false

    private let pasteboard: NSPasteboard
    private let preferences: UserDefaults?
    private var random = SystemRandomNumberGenerator()
    private var feedbackTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general, preferences: UserDefaults? = .standard) {
        self.pasteboard = pasteboard
        self.preferences = preferences
        copyWithFormatting = preferences?.object(forKey: "copyWithFormatting") as? Bool ?? false
        let birthday = RegistryNumber.randomBirthDate(through: Self.today, using: &random)
        registry = RegistryNumber.generate(birthDate: birthday,
                                          sex: Bool.random(using: &random) ? .female : .male, using: &random)
        iban = BelgianIBAN.generate(using: &random)
    }

    nonisolated static var today: BirthDate { BirthDate(date: Date())! }
    var registryCopyValue: String { copyWithFormatting ? registry.formatted : registry.rawValue }
    var ibanCopyValue: String { copyWithFormatting ? iban.formatted : iban.rawValue }

    func generateRegistry() {
        let birthday = randomBirthday
            ? RegistryNumber.randomBirthDate(through: Self.today, using: &random)
            : BirthDate(date: customBirthday)!
        let sex: EncodedSex = switch sexChoice {
        case .random: Bool.random(using: &random) ? .female : .male
        case .female: .female
        case .male: .male
        }
        // A click on New should always produce a different value, even with a fixed date and sex.
        var next: RegistryNumber
        repeat { next = RegistryNumber.generate(birthDate: birthday, sex: sex, using: &random) }
        while next == registry
        registry = next
        clearFeedback()
    }

    func generateIBAN() {
        var next: BelgianIBAN
        repeat { next = BelgianIBAN.generate(using: &random) } while next == iban
        iban = next
        clearFeedback()
    }

    func generateBoth() {
        generateRegistry()
        generateIBAN()
    }

    func generateAndCopy(_ kind: ValueKind) {
        switch kind {
        case .registry: generateRegistry()
        case .iban: generateIBAN()
        }
        copy(kind)
    }

    @discardableResult
    func copy(_ kind: ValueKind) -> Bool {
        clearFeedback()
        pasteboard.clearContents()
        let success = pasteboard.setString(kind == .registry ? registryCopyValue : ibanCopyValue, forType: .string)
        copiedKind = success ? kind : nil
        clipboardError = !success
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copiedKind = nil
            self?.clipboardError = false
        }
        return success
    }

    private func clearFeedback() {
        feedbackTask?.cancel()
        copiedKind = nil
        clipboardError = false
    }
}
