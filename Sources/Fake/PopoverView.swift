import AppKit
import FakeCore
import SwiftUI

private let fakeAccent = Color(red: 0.48, green: 0.39, blue: 0.88)

struct PopoverView: View {
    @ObservedObject var model: GeneratorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            VStack(spacing: 12) {
                registryCard
                ibanCard
            }
            HStack {
                Toggle("Copy with formatting", isOn: $model.copyWithFormatting)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .help("Off: plain digits / compact IBAN. On: dots, dashes and spaces as displayed.")
                Spacer()
                Button("New both", systemImage: "arrow.clockwise") { model.generateBoth() }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Generate both values (⌘R)")
            }
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(fakeAccent)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "die.face.5.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(fakeAccent)
                .frame(width: 44, height: 44)
                .background(fakeAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fake").font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Fresh values. Ready to paste.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("BE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
    }

    private var registryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Rijksregisternummer", icon: "person.text.rectangle")
            valueButton(model.registry.formatted, kind: .registry)
            HStack(spacing: 12) {
                Label(model.registry.birthDate.iso8601, systemImage: "calendar")
                Label(model.registry.sex.rawValue, systemImage: "person")
                Spacer(minLength: 0)
            }
            .font(.system(size: 12)).foregroundStyle(.secondary)
            .accessibilityLabel("Born \(model.registry.birthDate.iso8601), encoded sex \(model.registry.sex.rawValue)")
            actions(for: .registry)
            Divider()
            Button {
                model.showsOptions.toggle()
            } label: {
                HStack {
                    Text("Customize date & sex")
                    Spacer()
                    Image(systemName: model.showsOptions ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(model.showsOptions ? "Expanded" : "Collapsed")
            if model.showsOptions { customOptions }
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
    }

    private var customOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
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
    }

    private var ibanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Bank IBAN", icon: "building.columns")
            valueButton(model.iban.formatted, kind: .iban)
            Text("Belgium · domestic + IBAN checksums")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            actions(for: .iban)
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
    }

    private func cardTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold))
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green).font(.system(size: 12))
                .help("Valid format and checksums")
                .accessibilityLabel("Valid format and checksums")
        }
    }

    private func valueButton(_ value: String, kind: ValueKind) -> some View {
        Button { model.copy(kind) } label: {
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Image(systemName: model.copiedKind == kind ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundStyle(model.copiedKind == kind ? .green : fakeAccent)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to copy \(kind == .registry ? "rijksregisternummer" : "IBAN")")
        .accessibilityLabel("Copy \(kind == .registry ? "rijksregisternummer" : "IBAN"): \(value)")
    }

    private func actions(for kind: ValueKind) -> some View {
        HStack(spacing: 8) {
            Button("New", systemImage: "arrow.clockwise") {
                kind == .registry ? model.generateRegistry() : model.generateIBAN()
            }
            .keyboardShortcut(kind == .registry ? "1" : "2", modifiers: .command)
            .help("Generate a new \(kind == .registry ? "rijksregisternummer (⌘1)" : "IBAN (⌘2)")")
            Button(model.copiedKind == kind ? "Copied" : "Copy",
                   systemImage: model.copiedKind == kind ? "checkmark" : "doc.on.doc") {
                model.copy(kind)
            }
            .keyboardShortcut("c", modifiers: kind == .registry ? [.command] : [.command, .shift])
            .help("Copy current value (\(kind == .registry ? "⌘C" : "⇧⌘C"))")
            Spacer(minLength: 0)
            Button("New & copy") { model.generateAndCopy(kind) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(kind == .registry ? "1" : "2", modifiers: [.command, .shift])
                .help("Generate and copy (⇧⌘\(kind == .registry ? "1" : "2"))")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.system(size: 11, weight: .medium))
    }

    private var footer: some View {
        HStack {
            Label(model.clipboardError ? "Couldn’t copy. Try again." : "Generated locally for testing",
                  systemImage: model.clipboardError ? "exclamationmark.circle" : "sparkles")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .help("Synthetic values with valid checksums. They may coincide with assigned numbers.")
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// Keep the date picker aligned with the core's timezone, regardless of the Mac's locale.
private enum DateRange {
    static var allowed: ClosedRange<Date> {
        BirthDate(year: 1900, month: 1, day: 1)!.date...GeneratorModel.today.date
    }
}
