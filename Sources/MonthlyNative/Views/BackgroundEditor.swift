import SwiftUI
import WallpaperCore

@MainActor struct BackgroundEditor: View {
    @ObservedObject var state: AppState
    private var choice: BackgroundChoice { state.preferences.draft.backgroundChoice }
    private func change(_ body: (inout BackgroundChoice) -> Void) {
        var value = choice; body(&value); state.edit { $0.background = value }
    }
    private func binding<T>(_ key: WritableKeyPath<BackgroundChoice, T>) -> Binding<T> {
        Binding(get: { choice[keyPath: key] }, set: { value in change { $0[keyPath: key] = value } })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                FieldHeading(title: "Background colour")
                Spacer()
                Text(choice.mode == .seasonal ? "Follows the month" : "Stays until you change it")
                    .font(.system(size: 11)).foregroundStyle(Design.muted)
            }
            ChoiceRow(options: BackgroundMode.allCases, title: { $0.title }, selection: binding(\.mode))
            switch choice.mode {
            case .preset: presets
            case .custom: custom
            case .seasonal:
                Text("Use the original seasonal colours automatically. Choose Presets or Custom to keep a colour independently of the date.")
                    .font(.system(size: 12)).foregroundStyle(Design.muted)
            }
            HStack {
                Text("Text colour").font(.system(size: 12))
                Spacer()
                Picker("Text colour", selection: binding(\.ink)) {
                    ForEach(InkStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 135)
            }
        }.padding(16).background(Design.wash).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var presets: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 9) {
            ForEach(GradientPreset.all) { preset in
                Button {
                    change { $0.mode = .preset; $0.presetID = preset.id }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        LinearGradient(colors: [Color(hex: preset.start), Color(hex: state.preferences.draft.fill == .solid ? preset.start : preset.end)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 34).clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(choice.presetID == preset.id ? Design.ink : .clear, lineWidth: 2))
                        Text(preset.name).font(.system(size: 11)).foregroundStyle(Design.ink)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Background \(preset.name)")
                    .accessibilityAddTraits(choice.presetID == preset.id ? [.isSelected] : [])
            }
        }
    }
    private var custom: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorHexControl(title: state.preferences.draft.fill == .solid ? "Colour" : "First colour", hex: binding(\.firstHex))
            if state.preferences.draft.fill == .gradient {
                ColorHexControl(title: "Second colour", hex: binding(\.secondHex))
                HStack {
                    Text("Angle").font(.system(size: 12))
                    Slider(value: binding(\.angle), in: 0...360).accessibilityLabel("Gradient angle")
                    Text("\(Int(choice.angle.isFinite ? choice.angle : 132))°").monospacedDigit().font(.system(size: 11)).frame(width: 36)
                }
                Button("Swap colours") { change { let first = $0.firstHex; $0.firstHex = $0.secondHex; $0.secondHex = first } }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Design.muted)
            }
        }
    }
}

private struct ColorHexControl: View {
    let title: String
    @Binding var hex: String
    @State private var input = ""
    private var color: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
            hex = String(format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
                         Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
        })
    }
    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack {
                ColorPicker(title, selection: color, supportsOpacity: false).font(.system(size: 12))
                Text("#").foregroundStyle(Design.muted)
                TextField(title + " hex", text: $input).textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced)).frame(width: 82)
                    .onChange(of: input) { _, value in
                        if let normalized = BackgroundChoice.normalizedHex(value), hex != normalized { hex = normalized }
                    }
            }
            if BackgroundChoice.normalizedHex(input) == nil {
                Text("Enter six hex digits, such as B9DDDD.").font(.system(size: 10)).foregroundStyle(.red)
            }
        }.onAppear { input = hex }.onChange(of: hex) { _, value in input = value }
    }
}
