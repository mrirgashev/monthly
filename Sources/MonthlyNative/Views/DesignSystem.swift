import SwiftUI

enum Design {
    static let ink = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let muted = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255)
    static let paper = Color.white
    static let wash = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
}

struct QuietButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(selected ? .white : Design.ink)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selected ? Design.ink : configuration.isPressed ? Design.border : .white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Design.ink : Design.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ChoiceRow<Value: Hashable>: View {
    let options: [Value]
    let title: (Value) -> String
    @Binding var selection: Value
    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button(title(option)) { selection = option }
                    .buttonStyle(QuietButtonStyle(selected: option == selection))
                    .accessibilityAddTraits(option == selection ? [.isSelected] : [])
            }
        }
    }
}

struct FieldHeading: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .medium)).tracking(1.7).foregroundStyle(Design.muted)
    }
}

extension Color {
    init(hex: String) { self.init(cgColor: WallpaperRenderer.color(hex)) }
}
