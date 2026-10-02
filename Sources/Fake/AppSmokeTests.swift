import AppKit
import FakeCore

enum SmokeTestFailure: Error { case failed(String) }

/// Integration checks use a private pasteboard and never replace the user's clipboard.
@MainActor
enum AppSmokeTests {
    static func run() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let model = GeneratorModel(pasteboard: pasteboard, preferences: nil)
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw SmokeTestFailure.failed(message) }
        }
        try check(RegistryNumber.decode(model.registry.rawValue) != nil, "Initial registry")
        try check(BelgianIBAN.isValid(model.iban.rawValue), "Initial IBAN")
        model.randomBirthday = false
        model.customBirthday = BirthDate(year: 2000, month: 2, day: 29)!.date
        for sex in [SexChoice.female, .male] {
            model.sexChoice = sex
            model.generateRegistry()
            try check(model.registry.birthDate.iso8601 == "2000-02-29", "Custom birthday")
            try check(model.registry.sex.rawValue == sex.rawValue, "Custom sex")
            try check(RegistryNumber.decode(model.registry.rawValue) == model.registry, "Decoded metadata")
        }
        for formatted in [false, true] {
            model.copyWithFormatting = formatted
            try check(model.copy(.registry), "Copy registry")
            try check(pasteboard.string(forType: .string) == (formatted ? model.registry.formatted : model.registry.rawValue),
                      "Registry clipboard contents")
            try check(model.copy(.iban), "Copy IBAN")
            try check(pasteboard.string(forType: .string) == (formatted ? model.iban.formatted : model.iban.rawValue),
                      "IBAN clipboard contents")
        }
        let oldRegistry = model.registry
        model.generateAndCopy(.registry)
        try check(model.registry != oldRegistry, "New registry differs with fixed options")
        try check(pasteboard.string(forType: .string) == model.registryCopyValue, "New & copy registry")
        let oldIBAN = model.iban
        model.generateAndCopy(.iban)
        try check(model.iban != oldIBAN, "New IBAN differs")
        try check(pasteboard.string(forType: .string) == model.ibanCopyValue, "New & copy IBAN")
        model.randomBirthday = true
        model.sexChoice = .random
        model.generateBoth()
        try check(model.registry.birthDate <= GeneratorModel.today, "Random birthday not in future")
        try check(model.copiedKind == nil, "Generation clears copy feedback")
        try check(RegistryNumber.decode(model.registry.rawValue) != nil && BelgianIBAN.isValid(model.iban.rawValue),
                  "New both outputs")
    }
}
