import AppKit
import FakeCore
import SwiftUI

private let actionBlue = Color(nsColor: .systemBlue)

struct PopoverView: View {
    @ObservedObject var model: GeneratorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            registrySection
            ibanSection
            preferences
        }
        .padding(24)
        .frame(width: 384)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(actionBlue)
    }

    private var header: some View {
        HStack {
            Text("Fake")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            Button("New both") { model.generateBoth() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .keyboardShortcut("r", modifiers: .command)
                .help("Generate both values (⌘R)")
        }
    }

    private var registrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Rijksregisternummer")
            valueButton(model.registry.formatted, kind: .registry)
            Text("\(model.registry.birthDate.iso8601) · \(model.registry.sex.rawValue)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Born \(model.registry.birthDate.iso8601), encoded sex \(model.registry.sex.rawValue)")
            actions(for: .registry)
                .padding(.top, 2)
            if model.showsOptions {
                customOptions.padding(.top, 4)
            }
        }
    }

    private var customOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Encoded sex", selection: $model.sexChoice) {
                ForEach(SexChoice.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.sexChoice) { model.generateRegistry() }
            Toggle("Random birthday", isOn: $model.randomBirthday)
                .toggleStyle(.checkbox)
                .onChange(of: model.randomBirthday) { model.generateRegistry() }
            if !model.randomBirthday {
                DatePicker("Birthday", selection: $model.customBirthday,
                           in: DateRange.allowed, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .environment(\.calendar, BirthDate.calendar)
                    .environment(\.timeZone, BirthDate.calendar.timeZone)
                    .onChange(of: model.customBirthday) { model.generateRegistry() }
            }
        }
        .font(.system(size: 12))
        .controlSize(.small)
    }

    private var ibanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Belgian IBAN")
            valueButton(model.iban.formatted, kind: .iban)
            actions(for: .iban)
                .padding(.top, 2)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func valueButton(_ value: String, kind: ValueKind) -> some View {
        Button { model.copy(kind) } label: {
            HStack(spacing: 12) {
                Text(value)
                    .font(.system(size: 22))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: model.copiedKind == kind ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(model.copiedKind == kind ? actionBlue : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("c", modifiers: kind == .registry ? [.command] : [.command, .shift])
        .help(model.copiedKind == kind ? "Copied" : "Click to copy (\(kind == .registry ? "⌘C" : "⇧⌘C"))")
        .accessibilityLabel("Copy \(kind == .registry ? "rijksregisternummer" : "IBAN"): \(value)")
        .accessibilityValue(model.copiedKind == kind ? "Copied" : "")
    }

    private func actions(for kind: ValueKind) -> some View {
        HStack(spacing: 8) {
            if kind == .registry {
                Button {
                    model.showsOptions.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: model.showsOptions ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Date & sex")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Customize date & sex")
                .accessibilityValue(model.showsOptions ? "Expanded" : "Collapsed")
            }
            Spacer(minLength: 8)
            Button("New") {
                kind == .registry ? model.generateRegistry() : model.generateIBAN()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .foregroundStyle(.primary)
            .keyboardShortcut(kind == .registry ? "1" : "2", modifiers: .command)
            .help("Generate a new \(kind == .registry ? "rijksregisternummer (⌘1)" : "IBAN (⌘2)")")
            Button("New & copy") { model.generateAndCopy(kind) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(kind == .registry ? "1" : "2", modifiers: [.command, .shift])
                .help("Generate and copy (⇧⌘\(kind == .registry ? "1" : "2"))")
        }
        .controlSize(.small)
        .font(.system(size: 12))
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Copy with formatting", isOn: $model.copyWithFormatting)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help("Off: compact values. On: punctuation and spaces as displayed.")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q", modifiers: .command)
            }
            if model.clipboardError {
                Text("Couldn’t copy. Try again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Keep the date picker aligned with the core's timezone, regardless of the Mac's locale.
private enum DateRange {
    static var allowed: ClosedRange<Date> {
        BirthDate(year: 1900, month: 1, day: 1)!.date...GeneratorModel.today.date
    }
}
