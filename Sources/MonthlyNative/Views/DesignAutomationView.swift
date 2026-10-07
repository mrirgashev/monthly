import SwiftUI
import WallpaperCore

@MainActor struct DesignAutomationView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    private var plan: DesignPlan { state.preferences.draftPlan ?? DesignPlan() }
    private func binding<T>(_ key: WritableKeyPath<DesignPlan, T>) -> Binding<T> {
        Binding(get: { plan[keyPath: key] }, set: { value in state.editPlan { $0[keyPath: key] = value } })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your designs, on your time.").font(.system(size: 25, weight: .light))
                    Text("Save the current preview, choose when it appears, then Apply.")
                        .font(.system(size: 12)).foregroundStyle(Design.muted)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ChoiceRow(options: DesignTiming.allCases, title: { $0.title }, selection: binding(\.timing))
            Text(explanation).font(.system(size: 12)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
            if plan.timing == .hourlyCycle || plan.timing == .dailyCycle {
                DatePicker("Start with the first design", selection: binding(\.startDate), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.field).font(.system(size: 12))
            }
            HStack {
                FieldHeading(title: "Saved designs · \(plan.designs.count) / 24")
                Spacer()
                Button { state.saveDesign() } label: { Label("Add current preview", systemImage: "plus") }
                    .disabled(plan.designs.count >= 24)
            }
            ScrollView {
                VStack(spacing: 10) {
                    if plan.designs.isEmpty {
                        Text("Choose colours and a layout in the editor, then add that preview here. Each saved design remembers its colours, layout, numeral, and calendar display options.")
                            .font(.system(size: 13)).foregroundStyle(Design.muted).padding(30)
                    }
                    ForEach(plan.designs) { design in row(design) }
                }.padding(2)
            }.frame(maxHeight: .infinity)
            if let error = plan.validationError { Text(error).font(.system(size: 12)).foregroundStyle(.red) }
            Divider()
            Text("Dates and today's events refresh at midnight independently of your designs. Keep Monthly Native running in the menu bar; after sleep, it catches up to the correct design. All times use your Mac's time zone.")
                .font(.system(size: 11)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Changes stay in draft until you Apply.").font(.system(size: 11)).foregroundStyle(Design.muted)
                Spacer()
                Button("Apply designs & schedule") { state.applyDraft(); if state.errorMessage == nil { dismiss() } }
                    .buttonStyle(QuietButtonStyle(selected: true)).frame(width: 205)
                    .disabled(state.busy || plan.validationError != nil)
            }
        }.padding(26).frame(width: 710, height: 630)
            .foregroundStyle(Design.ink).background(Design.paper).preferredColorScheme(.light)
    }
    private var explanation: String {
        switch plan.timing {
        case .off: return "Use the current editor design. Your saved designs remain available."
        case .dailyTimes: return "Each design starts at its selected time every day and stays until the next one. Before the first time today, the last design from yesterday is used."
        case .hourlyCycle: return "Show these designs in list order, one every 60 minutes from the start time, then repeat. Nothing is shuffled. Before the start, use the editor design."
        case .dailyCycle: return "Show these designs in list order, one each day at the start time, then repeat. Nothing is shuffled. Before the start, use the editor design."
        }
    }
    private func update(_ id: UUID, _ body: (inout SavedDesign) -> Void) {
        state.editPlan { plan in
            guard let index = plan.designs.firstIndex(where: { $0.id == id }) else { return }
            body(&plan.designs[index])
        }
    }
    private func row(_ design: SavedDesign) -> some View {
        let index = plan.designs.firstIndex(where: { $0.id == design.id }) ?? 0
        let appearance = design.settings.backgroundChoice.resolved(month: state.current.month,
            hemisphere: design.settings.hemisphere.resolved(in: .current), fill: design.settings.fill)
        return HStack(spacing: 13) {
            LinearGradient(colors: [Color(hex: appearance.start), Color(hex: appearance.end)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 48, height: 57).clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 6) {
                TextField("Design name", text: Binding(get: { design.name }, set: { name in update(design.id) { $0.name = name } }))
                    .textFieldStyle(.plain).font(.system(size: 13, weight: .medium))
                Text("\(design.settings.layout.title) · \(design.settings.numeral.title) · Events \(design.settings.schedule.title.lowercased())")
                    .font(.system(size: 10)).foregroundStyle(Design.muted)
                HStack(spacing: 12) {
                    Button("Edit in preview") { state.beginEditingDesign(design); dismiss() }
                    Button("Replace with preview") { update(design.id) { $0.settings = state.preferences.draft } }
                }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Design.muted)
            }
            Spacer(minLength: 0)
            if plan.timing == .dailyTimes {
                DatePicker("Time for \(design.name)", selection: Binding(get: {
                    Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 15,
                        hour: design.minuteOfDay / 60, minute: design.minuteOfDay % 60)) ?? Date()
                }, set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    update(design.id) { $0.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
                }), displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field).frame(width: 102)
            } else {
                VStack(spacing: 5) {
                    Button { state.editPlan { $0.designs.swapAt(index, index - 1) } } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0).help("Move design earlier")
                    Button { state.editPlan { $0.designs.swapAt(index, index + 1) } } label: { Image(systemName: "chevron.down") }
                        .disabled(index + 1 >= plan.designs.count).help("Move design later")
                }.buttonStyle(.plain)
            }
            Button { state.editPlan { $0.designs.removeAll { $0.id == design.id } } } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain).foregroundStyle(Design.muted).help("Remove \(design.name)")
        }.padding(12).background(Design.wash).clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
