#if canImport(SwiftUI)
import SwiftUI

/// DEL-104: Form-Section-Container im Deltiq-Bento-Stil. Ersatz fuer
/// `Section { ... } header: {} footer: {}` aus `SwiftUI.Form`, damit die
/// Settings-/Profile-/Measurement-Screens vom Standard-iOS-Grouped-
/// Background loskommen und das selbe Premium-Theme tragen wie das
/// Dashboard.
///
/// **Verwendungs-Pattern:**
///
/// ```swift
/// ScrollView {
///     VStack(spacing: 16) {
///         DeltiqFormSection(header: "Profil") {
///             DeltiqFormRow(label: "Geschlecht") {
///                 Picker(...) { ... }
///             }
///             DeltiqFormRow(label: "Geburtsdatum") {
///                 DatePicker(...)
///             }
///         } footer: {
///             Text("Wird fuer KFA-Berechnung benoetigt.")
///         }
///     }
/// }
/// ```
///
/// Header + Footer-Texte sitzen AUSSERHALB der Bento-Card, damit das
/// Visuelle den iOS-Form-Konventionen entspricht (Header dezent ueber,
/// Footer dezent unter der Card).
@available(iOS 17.0, macOS 14.0, *)
public struct DeltiqFormSection<Content: View, Footer: View>: View {

    let header: String?
    let content: Content
    let footer: Footer

    public init(
        header: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = header
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header — kleines Caps-Label oberhalb der Card, identisch zur
            // Apple-Form-Section-Header-Konvention.
            if let header, !header.isEmpty {
                Text(header.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }

            // Bento-Card mit den eigentlichen Form-Rows. Dividers werden
            // automatisch zwischen direkten Children eingezogen (siehe unten).
            VStack(spacing: 0) {
                content
            }
            .deltiqCardStyle(padding: 0)   // padding pro-Row, nicht container-weit

            // Footer — Caption-Text unter der Card, identisch zur Apple-
            // Form-Section-Footer-Konvention.
            FormSectionFooterView(content: footer)
        }
    }
}

/// Conditional-Footer-Renderer. SwiftUI ViewBuilder accepts EmptyView und
/// produziert dann ein Layout-Loch — diese Brücke versteckt den Caption-
/// Padding-Bereich, wenn der Caller `EmptyView()` zurückgibt.
@available(iOS 17.0, macOS 14.0, *)
private struct FormSectionFooterView<Footer: View>: View {
    let content: Footer
    var body: some View {
        content
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }
}

// MARK: - DeltiqFormSection convenience init (no footer)

@available(iOS 17.0, macOS 14.0, *)
public extension DeltiqFormSection where Footer == EmptyView {
    init(
        header: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(header: header, content: content, footer: { EmptyView() })
    }
}

// MARK: - DeltiqFormRow

/// DEL-104: Einzelne Form-Zeile in einer `DeltiqFormSection`. Linkes Label
/// + rechts ausgerichteter Control-Slot. Divider unter der Zeile (sofern
/// nicht letzte) per Modifier.
///
/// **Layout:**
///   * Label linksbuendig, `.body`-Font
///   * Control rechtsbuendig im verbleibenden Platz
///   * 14pt horizontal + 12pt vertikal Padding (sportlich-kompakt vs.
///     Form-Default 11pt)
@available(iOS 17.0, macOS 14.0, *)
public struct DeltiqFormRow<Control: View>: View {

    let label: String
    let control: Control

    public init(label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                // DEL-138: Label-Layout-Hardening. Label nimmt seine
                // intrinsische Breite, `.layoutPriority(1)` damit es im
                // Squeeze NICHT shrinkt — stattdessen wird der Control-
                // Slot rechts angepasst.
                .layoutPriority(1)
            Spacer(minLength: 12)
            control
                .multilineTextAlignment(.trailing)
                // DEL-138: Layout-Fix fuer Picker-Werte wie "Alle 2 Stunden"
                // / "Every 2 hours" / "Her 2 saatte bir". Vorher wrappte
                // der Picker-Label-Text in 2 Zeilen, was die Cell-Hoehe
                // sprang.
                //   * `.lineLimit(1)` zwingt EINE Zeile — iOS's native
                //     Truncation kicks in (z.B. "Alle 2 Stu...")
                //   * `.minimumScaleFactor(0.85)` skaliert vor dem
                //     Truncating leicht runter, sodass typische 2-Zeilen-
                //     Werte bei 13.6pt statt 11pt-ellipsized rendern
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            // Hairline-Divider, automatisch zwischen Rows. Letzte Zeile
            // hat dank `.padding(0)` auf dem Container keine Last-Border.
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
    }
}

// MARK: - Convenience: Zeile ohne separates Control (z.B. NavigationLink-Row)

/// DEL-104: Form-Row ohne separates Control. Fuer NavigationLinks oder
/// Buttons, die die ganze Row aktivieren — der Caller liefert einfach
/// den fertigen Inhalt.
@available(iOS 17.0, macOS 14.0, *)
public struct DeltiqFormFullRow<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
            }
    }
}
#endif
