#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import FitnessAppCore
import FitnessAppData

/// DEL-161: Globale Uebungsbibliothek — bildschirmfuellendes Nachschlagewerk
/// aller Templates (System + Custom), erreichbar aus dem "Mehr"-Tab.
///
///   * Durchsuchbar; Custom oben, danach nach Muskelgruppe gruppiert.
///   * Tap → `ExerciseLibraryEditorSheet` (Custom editierbar, System read-only).
///   * Toolbar-"+" → neue Custom-Uebung anlegen.
///   * Swipe-Delete (mit Confirm) NUR fuer Custom-Eintraege.
@available(iOS 17.0, macOS 14.0, *)
public struct ExerciseLibraryView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseTemplate.name) private var templates: [ExerciseTemplate]

    @State private var search: String = ""
    /// Tap auf eine Zeile → Editor-Sheet fuer dieses Template.
    @State private var selectedTemplate: ExerciseTemplate?
    /// Toolbar-"+" → Create-Sheet.
    @State private var showingCreate: Bool = false
    /// Swipe-Delete → Confirm-Gate.
    @State private var pendingDelete: ExerciseTemplate?

    public init() {}

    public var body: some View {
        List {
            customSection
            ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                muscleSection(muscle)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .searchable(text: $search,
                    prompt: Text("library.searchPlaceholder", bundle: .module))
        .navigationTitle(Text("library.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("library.newExercise", bundle: .module))
            }
        }
        .sheet(item: $selectedTemplate) { template in
            ExerciseLibraryEditorSheet(template: template)
        }
        .sheet(isPresented: $showingCreate) {
            ExerciseLibraryEditorSheet(template: nil)
        }
        .confirmationDialog(
            Text("editor.exercise.deleteConfirmTitle", bundle: .module),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let t = pendingDelete { deleteTemplate(t) }
                pendingDelete = nil
            } label: {
                Text("editor.exercise.deleteConfirmCta", bundle: .module)
            }
            Button(role: .cancel) { pendingDelete = nil } label: {
                Text("common.cancel", bundle: .module)
            }
        } message: {
            Text("editor.exercise.deleteConfirmMessage", bundle: .module)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var customSection: some View {
        let customs = filtered.filter(\.isCustom)
        if !customs.isEmpty {
            Section {
                ForEach(customs) { template in
                    row(template)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = template
                            } label: {
                                Label {
                                    Text("editor.exercise.delete", bundle: .module)
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                }
            } header: {
                Label {
                    Text("picker.exercise.section.customs", bundle: .module)
                } icon: {
                    Image(systemName: "star.fill")
                }
            }
        }
    }

    @ViewBuilder
    private func muscleSection(_ muscle: MuscleGroup) -> some View {
        let items = filtered.filter { !$0.isCustom && $0.primaryMuscle == muscle }
        if !items.isEmpty {
            Section {
                ForEach(items) { template in
                    row(template)
                }
            } header: {
                Text(muscle.localizedName)
            }
        }
    }

    // MARK: Row

    private func row(_ template: ExerciseTemplate) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            HStack(spacing: 12) {
                Image(systemName: equipmentIcon(template.equipment))
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.deltiqOrange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(template.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if template.isCustom {
                            Text("picker.exercise.customBadge", bundle: .module)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(String(localized: template.primaryMuscle.localizedName)) • \(String(localized: template.equipment.localizedName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Derived + actions

    /// Such-gefilterte Templates (Match ueber Display-Name + roher DE-Name).
    private var filtered: [ExerciseTemplate] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return templates }
        return templates.filter {
            $0.displayName.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }
    }

    /// Loescht ein Custom-Template (System-Eintraege erreichen den Swipe nicht).
    /// Safe: Exercise/Log halten keine Relationship aufs Template (Match by
    /// name, Felder kopiert) — es wird nichts kaskadiert.
    private func deleteTemplate(_ template: ExerciseTemplate) {
        guard template.isCustom else { return }
        modelContext.delete(template)
        try? modelContext.save()
    }

    /// Spiegelung von `ExercisePickerView.equipmentIcon` — bewusst dieselben
    /// (verifizierten) SF-Symbole, damit Bibliothek + Picker konsistent sind.
    private func equipmentIcon(_ e: Equipment) -> String {
        switch e {
        case .barbell:     return "scalemass"
        case .dumbbell:    return "dumbbell"
        case .bodyweight:  return "figure.walk"
        case .machine:     return "gearshape"
        case .cable:       return "cable.connector"
        case .kettlebell:  return "circle.grid.cross"
        case .band:        return "infinity"
        }
    }
}
#endif
