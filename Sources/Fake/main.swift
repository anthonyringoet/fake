import FakeCore
import Foundation

// The native menu bar interface is added in the next implementation step.
var random = SystemRandomNumberGenerator()
let birthday = RegistryNumber.randomBirthDate(through: BirthDate(date: Date())!, using: &random)
let registry = RegistryNumber.generate(birthDate: birthday, sex: .female, using: &random)
print("\(registry.formatted) · \(birthday.iso8601) · \(registry.sex.rawValue)")
print(BelgianIBAN.generate(using: &random).formatted)
