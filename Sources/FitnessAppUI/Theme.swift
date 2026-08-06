#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - DEL-102 Deltiq Design-System
//
// Zentrale Theme-Schicht: Color-Palette + Card-/Button-Modifier +
// Typografie-Helfer. Lebt im UI-Modul (nicht Core), damit der Fokus auf
// SwiftUI bleibt und Widget-/Watch-Targets unabhaengig eigene Themes
// fahren koennen.
//
// **Asset-Catalog-Entscheidung:** Wir definieren die dynamischen Farben
// direkt in Code statt im `.xcassets`-Bundle. SwiftPM-Resource-Catalogs
// sind moeglich, aber das Bundle-Path-Magic mit Localizable.xcstrings ist
// uns schon genug Komplexitaet — pure-Code-Farben sind testbar, lesbar
// und vermeiden Asset-Cache-Bugs in Codemagic.

// MARK: - 1. Color Palette

public extension Color {
    /// Cross-platform Helper: liefert eine Color, die je nach ColorScheme
    /// automatisch zwischen Light- und Dark-Variante umschaltet.
    /// Auf macOS faellt der Fallback auf die Light-Variante (oder Dark via
    /// `NSAppearance`-Check, falls jemand das Mac-Catalyst-mal-anschalten
    /// will). Heute genuegt iOS.
    init(deltiqLight: Color, deltiqDark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(deltiqDark)
                : UIColor(deltiqLight)
        })
        #else
        // macOS preview / Windows-Swift fallback.
        self = deltiqLight
        #endif
    }

    /// Deltiq-Branding-Namespace. Alle UI-Surfaces lesen ueber
    /// `Color.Deltiq.xxx` statt Hex-Codes oder System-Greys einzustreuen.
    enum Deltiq {

        /// **Primaerer Marken-Akzent.** Identisch zur Bestands-Konstante
        /// `Color.deltiqOrange` (#FF9F0A) — wird hier als Alias gespiegelt,
        /// damit neue Code-Sites das Namespace-Pattern nutzen koennen,
        /// ohne dass Welle-3-bis-16-Code refactored werden muss.
        public static let primary: Color = .deltiqOrange

        /// Hero-Gradient fuer Primary-Buttons + Top-Match-Cards. Subtiler
        /// Gradient vom satten Marken-Orange in ein leicht waermeres
        /// "deep amber" — gibt CTAs Tiefe ohne Disco-Effekt.
        public static let primaryGradient = LinearGradient(
            colors: [Color.deltiqOrange,
                     Color(red: 1.0, green: 0.45, blue: 0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Globaler App-Background. Light = sehr helles Off-White (HIG-
        /// Standard fuer Grouped-Backgrounds), Dark = tiefes Off-Black
        /// (warmer als #000 — verhindert OLED-Halos).
        public static let background = Color(
            deltiqLight: Color(red: 0.949, green: 0.949, blue: 0.969),  // #F2F2F7
            deltiqDark:  Color(red: 0.039, green: 0.039, blue: 0.039)   // #0A0A0A
        )

        /// Card-/Surface-Background. Sitzt EINE Stufe naeher am User als
        /// `background`. Light = reines Weiss (Card abhebend); Dark = das
        /// iOS-elevatedDark (#1C1C1E) — bekannt aus Settings-App, fuehlt
        /// sich premium an.
        public static let surface = Color(
            deltiqLight: Color.white,
            deltiqDark:  Color(red: 0.110, green: 0.110, blue: 0.118)   // #1C1C1E
        )

        /// Sekundaer-Text-Convenience — Alias auf System-`.secondary`,
        /// damit Caller nicht ueberlegen muessen, ob sie System-Defaults
        /// oder Brand-Tokens benutzen sollen.
        public static let textMuted: Color = .secondary

        // MARK: - UX-205 Semantic Color Roles
        //
        // Diese Aliases existieren damit Aufrufer NICHT raw `.green` /
        // `.red` / `.yellow` streuen — neue Code-Sites lesen ueber
        // `Color.Deltiq.success` etc. und drueck-knopf-konsistent
        // wechselt der Sweep das Token sobald sich die Palette weiter
        // entwickelt. Bestandscode wird nicht refactored (high risk,
        // low yield) — nur neue Surfaces nutzen die Tokens.

        /// "Geschafft / OK / Fertig". Default = iOS-Green, kann zu
        /// markenspezifischem Grun gemorpht werden ohne dass jeder
        /// Aufrufer geupdatet werden muss.
        public static let success: Color = .green

        /// "Achtung / Stop kurz nach". Default = iOS-Orange (NICHT
        /// Brand-Orange — das ist primary, semantically getrennt).
        public static let warning: Color = .yellow

        /// "Fehler / Destruktive Aktion". Default = iOS-Red.
        public static let error: Color = .red

        /// "Information / Neutral-Hinweis". Default = iOS-Blue.
        public static let info: Color = .blue
    }
}

// MARK: - UX-205 Design Tokens (Spacing + Radius)

/// Spacing-Skala fuer Padding/Margin in 4pt-Schritten. Apple-HIG-konform,
/// Halbschritte (z.B. 14 oder 18) bewusst NICHT enthalten — sie ruinieren
/// die Rhythmus-Konsistenz, weil Augen unbewusst auf 4-/8-/16-Schritt-
/// Vielfache eichen.
///
/// **Verwendung:** `.padding(Deltiq.Spacing.md)` statt `.padding(12)`.
/// Bestandscode bleibt unangetastet; neue Code-Sites lesen ueber das
/// Token.
public enum Deltiq {

    public enum Spacing {
        /// 4pt — minimale Trennung (zwischen Icon + Inline-Label).
        public static let xs: CGFloat = 4
        /// 8pt — kompakte Trennung (zwischen Stat-Label + Wert).
        public static let sm: CGFloat = 8
        /// 12pt — Standard-Spacing innerhalb einer Card.
        public static let md: CGFloat = 12
        /// 16pt — Card-Padding + Section-Spacing.
        public static let lg: CGFloat = 16
        /// 20pt — grosse Section-Trennung.
        public static let xl: CGFloat = 20
        /// 24pt — Hero-Section vs. Stats-Section.
        public static let xxl: CGFloat = 24
    }

    /// Corner-Radius-Skala. Definiert die Formensprache pro UI-Element.
    /// Bestandscode mit explizitem `cornerRadius: 8` etc. bleibt erstmal —
    /// neue Code-Sites lesen ueber `Deltiq.Radius.input` etc.
    public enum Radius {
        /// 6pt — Pills / kleine Inline-Badges.
        public static let pill: CGFloat = 6
        /// 8pt — Inputs (TextField), Icon-Squares (36x36) in Badges.
        public static let input: CGFloat = 8
        /// 10pt — kleine Cards / Tabs / Quick-Access-Buttons.
        public static let small: CGFloat = 10
        /// 12pt — mittlere Cards / Stat-Container.
        public static let medium: CGFloat = 12
        /// 16pt — Primary-Buttons + Active-Workout-Cards.
        public static let button: CGFloat = 16
        /// 20pt — Bento-Cards auf dem Dashboard (deltiqCardStyle-Default).
        public static let card: CGFloat = 20
    }
}

// MARK: - 2. Card Modifier (Bento Style)

/// DEL-102: Premium-Card-Pattern. Surface-Background + soft Corner +
/// extrem dezenter `.stroke` (statt fettem Border) + minimaler Shadow.
/// **Verwendung:** `.deltiqCardStyle()` auf jeden Card-Container im
/// Dashboard/Detail-Screen. Inneres Padding ueberschreibbar via Param.
public struct DeltiqCardModifier: ViewModifier {
    public var padding: CGFloat = 16
    public var cornerRadius: CGFloat = 20

    public init(padding: CGFloat = 16, cornerRadius: CGFloat = 20) {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Deltiq.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Premium-Edge: extrem dezenter Stroke (5% opacity), holt die
            // Card-Kontur sanft vom Background ab ohne sichtbaren Rahmen.
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            // Leichter Drop-Shadow — wirkt v.a. im Light-Mode, im Dark-Mode
            // praktisch unsichtbar (was korrekt ist).
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

public extension View {
    /// Premium-Card mit Deltiq-Bento-Style. Default-Padding 16pt,
    /// Corner-Radius 20pt — beides ueber Parameter justierbar.
    func deltiqCardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        modifier(DeltiqCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - 3. Typografie

public extension View {
    /// **Fuer alle Zahlen, Timer und Gewichte verwenden.** Erzwingt
    /// `.fontDesign(.rounded)` (sportlicher als San Francisco's Sans-Serif)
    /// und `.monospacedDigit()` (verhindert das Springen, wenn Timer hoch-
    /// zaehlen oder Volumen-Werte sich aendern).
    ///
    /// Bewusst KEIN explizites `.fontWeight` — Caller setzt das selbst,
    /// damit der gleiche Helper sowohl auf grossen Hero-Zahlen (`.bold`)
    /// als auch auf kleinen Stats-Labels (`.medium`) sitzen kann.
    func fitnessNumberStyle() -> some View {
        self
            .fontDesign(.rounded)
            .monospacedDigit()
    }
}

// MARK: - 4. Primary Button Modifier

/// DEL-102: Haupt-Aktions-Button-Style. Voller-Breite-CTA, gradient-
/// gefuellt, weiss text, runde Ecken. Verwendung als `.deltiqButtonStyle()`
/// auf einen plain Button label.
public struct DeltiqPrimaryButtonModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.Deltiq.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.deltiqOrange.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    /// Hero-Button-Style fuer primaere Aktionen (Training starten, Weiter,
    /// Speichern). Wendet automatisch DeltiqOrange-Gradient + Glow an.
    func deltiqButtonStyle() -> some View {
        modifier(DeltiqPrimaryButtonModifier())
    }
}

/// Handoff 1.9 (Button-Taxonomie, dritte Stufe "Sekundaer"): ruhige
/// Fill-Flaeche (`Deltiq.fill`) statt Gradient/Glow, Orange-Text statt
/// Weiss — fuer eine zweite, weniger dringliche Aktion direkt neben einem
/// `.deltiqButtonStyle()`-Primary (z.B. "Leerer Plan" neben "Aus Vorlage"
/// im Pläne-Leerzustand). Gleiche Hoehe/Rundung wie Primary, damit beide
/// als sichtbares Paar wirken.
public struct DeltiqSecondaryButtonModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.deltiqOrange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.Deltiq.fill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

public extension View {
    func deltiqSecondaryButtonStyle() -> some View {
        modifier(DeltiqSecondaryButtonModifier())
    }
}

// MARK: - 5. UX-205 Icon-Badge Modifier

/// UX-205: 36×36 Icon-Square mit gradientem Tint, hierarchical-rendering
/// und innerer Lichtkante. Wird von allen Reward-Badges (PRBadge,
/// AchievementBadge, ProgressionBadge) gleich aufgebaut — der Modifier
/// zieht die drei identischen 6-Zeilen-Snippets in eine Single Source of
/// Truth, sodass z.B. eine spaetere Frame-Size-Aenderung (36 → 40 für
/// barrierefreiere Touch-Targets) an genau einer Stelle passiert.
public struct DeltiqIconBadgeModifier: ViewModifier {
    public var tint: Color
    public var size: CGFloat = 36

    public init(tint: Color, size: CGFloat = 36) {
        self.tint = tint
        self.size = size
    }

    public func body(content: Content) -> some View {
        content
            .font(.title3)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient)
            .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input))
            .innerLightStroke(cornerRadius: Deltiq.Radius.input)
    }
}

public extension View {
    /// Wandelt ein `Image(systemName:)` in einen 36×36-Reward-Badge mit
    /// gradientem Tint, hierarchical-rendering und feiner Innenkante um.
    /// `tint` ist die Brand-/Status-Farbe (orange, green, yellow, ...).
    func deltiqIconBadge(tint: Color, size: CGFloat = 36) -> some View {
        modifier(DeltiqIconBadgeModifier(tint: tint, size: size))
    }
}

// MARK: - 6. Signature Screen-Gerüst (Design-Handoff Turn 2b)
//
// Acht Schichten, in jedem View identisch. `deltiqCardStyle`,
// `deltiqButtonStyle` und `fitnessNumberStyle` bleiben unveraendert und
// werden hier weiterbenutzt, nicht ersetzt.
//
// **Light Mode:** Das Handoff-Dokument spezifiziert ausschliesslich
// Dark-Werte. Alle unten neu eingefuehrten Farb-Tokens leiten ihre
// Light-Variante nach demselben Muster wie `InnerLightStrokeModifier`
// (DEL-066) ab: gleiche Opazitaet, Farbe kippt Weiss→Schwarz, damit der
// Kontrast zum jeweiligen Hintergrund symmetrisch bleibt. Das ist eine
// plausible Herleitung, keine Design-Vorgabe — noch nicht gegengeprueft.

public extension Color.Deltiq {
    /// Sekundaertext (Untertitel, Werte, Hinweise). Deckkraft 60%.
    static let textSecondary = Color(
        deltiqLight: Color.black.opacity(0.60),
        deltiqDark:  Color.white.opacity(0.60)
    )

    /// Tertiaertext (Platzhalter, Chevrons, inaktive Werte). Deckkraft 30%.
    static let textTertiary = Color(
        deltiqLight: Color.black.opacity(0.30),
        deltiqDark:  Color.white.opacity(0.30)
    )

    /// Zeilentrennlinie, volle Breite, kein Einzug. Deckkraft 6%.
    static let divider = Color(
        deltiqLight: Color.black.opacity(0.06),
        deltiqDark:  Color.white.opacity(0.06)
    )

    /// Neutrale Flaeche fuer Kopfzeilen-Knoepfe, Suchfeld, Eingaben.
    /// Deckkraft 7%.
    static let fill = Color(
        deltiqLight: Color.black.opacity(0.07),
        deltiqDark:  Color.white.opacity(0.07)
    )

    /// Haarlinie unter der Kontextzeile: Verlauf von Akzent 55% nach
    /// transparent. `deltiqOrange` ist Light/Dark identisch, daher keine
    /// Schema-Unterscheidung noetig.
    static let hairline = LinearGradient(
        colors: [Color.deltiqOrange.opacity(0.55), Color.deltiqOrange.opacity(0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Handoff 2.5: "Apple-Health-Hinweis bleibt in Health-Rot — das ist
    /// eine Fremdmarke, keine Deltiq-Farbe, und darf abweichen." Bisher
    /// stand an dieser Stelle System-`.pink`; das Geruest nennt explizit
    /// den Hex-Wert, daher als eigenes Token statt weiter `.pink` zu
    /// verwenden. Nur fuer den EINEN explizit genannten Hinweis gedacht
    /// (Gewichtsfeld-Badge "aus Apple Health uebernommen"), nicht fuer
    /// jedes HealthKit-Icon im Rest der App.
    static let health = Color(red: 1.0, green: 0.216, blue: 0.373)
}

// MARK: - 6.1 Signature-Icon-Quadrat (Abschnitt 1.6)

/// Eine Icon-Groesse fuer das gesamte Screen-Geruest: 32×32, Radius 8,
/// Akzent-Verlauf `#FF9F0A → #FF7300`, weisser Glyph. Loest die bisherigen
/// 30/36/38pt-Varianten mit ihren Sieben-Farben-Tints ab. Groesse bleibt
/// ueberschreibbar fuer Kachel-Faelle (Dashboard-Hero, Rechner-Kacheln),
/// die denselben Verlauf in anderen Massen brauchen.
public struct DeltiqAccentIconModifier: ViewModifier {
    public var size: CGFloat
    public var cornerRadius: CGFloat
    public var glyphSize: CGFloat

    public init(size: CGFloat = 32, cornerRadius: CGFloat = Deltiq.Radius.input, glyphSize: CGFloat = 14) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.glyphSize = glyphSize
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(size: glyphSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.Deltiq.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public extension View {
    func deltiqAccentIcon(size: CGFloat = 32, cornerRadius: CGFloat = Deltiq.Radius.input, glyphSize: CGFloat = 14) -> some View {
        modifier(DeltiqAccentIconModifier(size: size, cornerRadius: cornerRadius, glyphSize: glyphSize))
    }
}

// MARK: - 6.2 DeltiqScreen (Abschnitt 1.1)

/// Screen-Flaeche: randloser Hintergrund, `ScrollView` statt `List`/`Form`,
/// Seitenrand 16, Bottom-Inset 100 (140 bei zusaetzlicher Bottom-Bar, z. B.
/// aktives Training). Erwartet als Content i. d. R. einen
/// `VStack(alignment: .leading, spacing: 18)`.
///
/// Der Kopf (`DeltiqHeader`) sitzt ausserhalb — bleibt fix, scrollt nicht
/// mit. Zwischen Kopf und erstem Element liegen 12pt (siehe 1.3); das gilt
/// unabhaengig davon, ob eine `DeltiqContextRow` vorhanden ist.
public struct DeltiqScreenModifier: ViewModifier {
    public var extraBottomInset: Bool

    public init(extraBottomInset: Bool = false) {
        self.extraBottomInset = extraBottomInset
    }

    public func body(content: Content) -> some View {
        ScrollView {
            content
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, extraBottomInset ? 140 : 100)
        }
        .scrollContentBackground(.hidden)
        .background(Color.Deltiq.background.ignoresSafeArea())
    }
}

public extension View {
    func deltiqScreen(extraBottomInset: Bool = false) -> some View {
        modifier(DeltiqScreenModifier(extraBottomInset: extraBottomInset))
    }
}

// MARK: - 6.3 DeltiqHeader (Abschnitt 1.2)

/// Aktion in der Kopfzeile, maximal zwei pro `DeltiqHeader`. Entweder ein
/// direkter Tap (`action:`) oder ein Dropdown (`menu:`, z. B. Ellipsis mit
/// mehreren Optionen wie im aktiven Training oder beim Wasser-Tracker) —
/// visuell identisch, nur die Interaktion unterscheidet sich.
public struct DeltiqHeaderAction: Identifiable {
    // Nachtrag 6. August: eine frische UUID bei jedem Redraw liess ein
    // offenes Menu (siehe `menu:`-Initializer) spaetestens nach einer
    // Sekunde zufallen, sobald die Kopfzeile neu gezeichnet wurde - z.B.
    // durch den sekuendlich tickenden "LAEUFT · mm:ss"-Eyebrow im aktiven
    // Training. `ForEach(actions)` hielt die neue UUID fuer ein anderes
    // Element und das offene Menu gehoerte danach zu einer Ansicht, die es
    // nicht mehr gab. `systemImage` ist ueber Redraws stabil (kein Screen
    // im Repo hat zwei gleichzeitige Actions mit demselben Icon) und ersetzt
    // die UUID als Identitaet.
    public var id: String { systemImage }
    public let systemImage: String
    public let isHighlighted: Bool
    public let action: (() -> Void)?
    public let menuContent: (() -> AnyView)?

    public init(systemImage: String, isHighlighted: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.isHighlighted = isHighlighted
        self.action = action
        self.menuContent = nil
    }

    public init<MenuContent: View>(
        systemImage: String,
        isHighlighted: Bool = false,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.systemImage = systemImage
        self.isHighlighted = isHighlighted
        self.action = nil
        self.menuContent = { AnyView(menu()) }
    }
}

/// Ersetzt die native Navigationsleiste. Caller blendet sie zusaetzlich
/// aus (`.toolbar(.hidden, for: .navigationBar)`,
/// `.navigationBarBackButtonHidden(true)`) und haelt die Swipe-Back-Geste
/// ueber den System-Default am Leben — dieser View uebernimmt nur die
/// Darstellung, keine Navigationslogik.
public struct DeltiqHeader: View {
    public var eyebrow: String
    public var title: String
    public var onBack: (() -> Void)?
    public var actions: [DeltiqHeaderAction]

    public init(
        eyebrow: String,
        title: String,
        onBack: (() -> Void)? = nil,
        actions: [DeltiqHeaderAction] = []
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.onBack = onBack
        self.actions = Array(actions.prefix(2))
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.deltiqOrange)
                        .frame(width: 32, height: 32)
                        .background(Color.Deltiq.fill)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .accessibilityLabel(Text("common.back", bundle: .module))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.deltiqOrange)
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    // Ersetzt `.navigationTitle` auf allen Screens, die
                    // dieses Geruest nutzen — ohne eigenes Heading-Trait
                    // waere der Screen-Titel fuer VoiceOver nicht mehr als
                    // Ueberschrift erkennbar.
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer(minLength: 8)

            ForEach(actions) { headerAction in
                if let menuContent = headerAction.menuContent {
                    Menu {
                        menuContent()
                    } label: {
                        headerActionIcon(headerAction)
                    }
                } else if let action = headerAction.action {
                    Button(action: action) {
                        headerActionIcon(headerAction)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func headerActionIcon(_ headerAction: DeltiqHeaderAction) -> some View {
        Image(systemName: headerAction.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.deltiqOrange)
            .frame(width: 32, height: 32)
            .background(headerAction.isHighlighted ? Color.deltiqOrange.opacity(0.16) : Color.Deltiq.fill)
            .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
    }
}

// MARK: - 6.4 DeltiqPill + DeltiqContextRow (Abschnitt 1.3)

public enum DeltiqPillStyle {
    case accent
    case neutral
}

/// Kontextkapsel. `text` wird nicht automatisch grossgeschrieben — Caller
/// uebergibt bereits Grossbuchstaben (gleiche Begruendung wie bei
/// `deltiqLabel()`: unicode-spezifische Umlaute wie ß bleiben so korrekt).
public struct DeltiqPill: View {
    public var text: String
    public var style: DeltiqPillStyle

    public init(_ text: String, style: DeltiqPillStyle = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(style == .accent ? Color.deltiqOrange : Color.Deltiq.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(style == .accent ? Color.deltiqOrange.opacity(0.15) : Color.Deltiq.fill)
            .clipShape(Capsule())
    }
}

/// Ein Eintrag einer `DeltiqContextRow`.
public struct DeltiqContextItem: Identifiable {
    // Nachtrag 6. August: dieselbe Instabilitaet wie bei `DeltiqHeaderAction.id`
    // (siehe dort) - hier bisher folgenlos, weil an einer Kontextkapsel kein
    // offener Zustand haengt, aber derselbe fehleranfaellige Aufbau. `text`
    // ist innerhalb einer Zeile eindeutig und stabil ueber Redraws.
    public var id: String { text }
    public let text: String
    public let style: DeltiqPillStyle

    public init(_ text: String, style: DeltiqPillStyle = .neutral) {
        self.text = text
        self.style = style
    }
}

/// Kapselzeile + Haarlinie. Optional, aber wenn vorhanden immer als
/// erstes Element im Screen-Content (siehe `DeltiqScreen`).
public struct DeltiqContextRow: View {
    public var items: [DeltiqContextItem]

    public init(_ items: [DeltiqContextItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    DeltiqPill(item.text, style: item.style)
                }
            }
            Rectangle()
                .fill(Color.Deltiq.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - 6.5 DeltiqSection + DeltiqCard (Abschnitt 1.4)

/// Container-Variante "Sektion": Zeilenliste ohne Innenpadding, Header
/// (falls gesetzt) wandert als erste Zeile in die Karte (Abschnitt 1.5).
/// `accentEdge` markiert die eine Karte pro Screen, die die Hauptaussage
/// traegt — maximal eine pro Screen, siehe 1.4.
public struct DeltiqSection<Content: View>: View {
    public var title: String?
    public var accentEdge: Bool
    public var content: () -> Content

    public init(
        _ title: String? = nil,
        accentEdge: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accentEdge = accentEdge
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.deltiqOrange)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                    Rectangle()
                        .fill(Color.Deltiq.divider)
                        .frame(height: 1)
                }
                content()
            }
            if accentEdge {
                Color.deltiqOrange.frame(width: 2)
            }
        }
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

/// Container-Variante "Karte": freier Inhalt, Padding 16 rundum. Kleinere
/// Kacheln (Hero-Metrics, Wochen-Stats) duerfen `padding` auf 12
/// reduzieren — das Gerüst nennt dafuer keinen eigenen dritten
/// Container-Typ, das Padding bleibt aber der einzige Unterschied zur
/// vollen "Karte".
public struct DeltiqCard<Content: View>: View {
    public var padding: CGFloat
    public var accentEdge: Bool
    public var content: () -> Content

    public init(padding: CGFloat = 16, accentEdge: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.accentEdge = accentEdge
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
            if accentEdge {
                Color.deltiqOrange.frame(width: 2)
            }
        }
        .background(Color.Deltiq.surface)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - 6.6 DeltiqSegmentedPicker (Abschnitt 2.4 Erscheinungsbild-Picker)

/// Ein Segment fuer `DeltiqSegmentedPicker`.
public struct DeltiqSegmentedOption<Value: Hashable>: Identifiable {
    public var id: Value { value }
    public let value: Value
    public let label: String

    public init(_ value: Value, label: String) {
        self.value = value
        self.label = label
    }
}

/// Handoff 2.4: Ersatz fuer den System-Segmented-Picker (Systemgrau-
/// Segmente) - aktives Segment Orange mit dunkler #1A1A1A-Schrift, Spur
/// Weiss/Fill 7%. Eigenbau statt `UISegmentedControl.appearance()`-Proxy:
/// dieser gilt GLOBAL fuer jeden Segmented-Picker im Repo (siehe z.B.
/// ChartTimeRange, PlateCalculatorView, OnboardingView) - hier soll nur
/// dieser eine Picker das neue Aussehen bekommen.
public struct DeltiqSegmentedPicker<Value: Hashable>: View {
    public var options: [DeltiqSegmentedOption<Value>]
    @Binding public var selection: Value

    public init(options: [DeltiqSegmentedOption<Value>], selection: Binding<Value>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            option.value == selection
                                ? Color(red: 0.102, green: 0.102, blue: 0.102)
                                : Color.primary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(option.value == selection ? Color.deltiqOrange : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.Deltiq.fill)
        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input + 4, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

// MARK: - 6.7 DeltiqControlRow (Abschnitt 2.4 Einstellungen)

/// Zeile mit einem frei waehlbaren, rechtsbuendigen Control (Toggle,
/// Picker, TextField, ...) statt eines statischen Wert-Texts wie bei
/// `DeltiqRow` - fuer Einstellungs-Zeilen (Settings, Messung-Formulare),
/// die `DeltiqRow`s feste Icon/Label/Untertitel/Wert/Chevron-Form nicht
/// abdeckt. `icon` optional: Zeilen ohne sinnvolles Symbol lassen es weg
/// und ruecken den Text nach links auf den normalen 14pt-Zeilenrand
/// (siehe 2.4) - dafuer reicht der bedingte Icon-Slot unten, kein
/// zusaetzlicher Parameter noetig.
public struct DeltiqControlRow<Control: View>: View {
    public var icon: String?
    public var label: String
    public var showsDivider: Bool
    public var control: () -> Control

    public init(
        icon: String? = nil,
        label: String,
        showsDivider: Bool = true,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.icon = icon
        self.label = label
        self.showsDivider = showsDivider
        self.control = control
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .deltiqAccentIcon()
                }
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                    .layoutPriority(1)
                Spacer(minLength: 12)
                control()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - 6.8 DeltiqRow (Abschnitt 1.6)

/// Zeile innerhalb einer `DeltiqSection`. `icon` ist optional — Zeilen
/// ohne sinnvolles Symbol lassen es weg, statt einen leeren Platzhalter
/// zu zeigen (siehe 2.4). `showsDivider` steuert die Trennlinie am Fuss
/// der Zeile; die letzte Zeile einer Sektion setzt sie auf `false`, damit
/// die Karte nicht mit einer Linie direkt vor der Rundung abschliesst.
public struct DeltiqRow: View {
    public var icon: String?
    public var label: String
    public var subtitle: String?
    public var value: String?
    public var showsChevron: Bool
    public var showsDivider: Bool
    public var action: (() -> Void)?

    public init(
        icon: String? = nil,
        label: String,
        subtitle: String? = nil,
        value: String? = nil,
        showsChevron: Bool = false,
        showsDivider: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.label = label
        self.subtitle = subtitle
        self.value = value
        self.showsChevron = showsChevron
        self.showsDivider = showsDivider
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let action {
                Button(action: action) { rowBody }
                    .buttonStyle(.plain)
            } else {
                rowBody
            }
            if showsDivider {
                Rectangle()
                    .fill(Color.Deltiq.divider)
                    .frame(height: 1)
            }
        }
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .deltiqAccentIcon()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Deltiq.textSecondary)
                        .lineSpacing(4)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .fitnessNumberStyle()
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Deltiq.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - 6.9 [entfernt] DeltiqCentralActionButton (Abschnitt 1.11, Nachtrag Weg B)
//
// Design-Entscheidung 5. August (README.md, Nachtrag zu 1.11, Weg B): der
// ueberstehende, frei schwebende Aktionsknopf liess sich gegen die
// tatsaechliche Tab-Leiste (eine schwebende Kapsel mit eigenem Aussenabstand,
// nicht die Bildschirmkante) nicht robust positionieren - die Kapsel
// verteilt ihre vier sichtbaren Symbole neu, sobald der Platzhalter keine
// eigene Spalte bekommt, und ihre Oberkante laesst sich nicht aus dem
// sicheren Bereich ableiten. Ersetzt durch ein echtes fuenftes Tab-Symbol
// (Akzent-Kreis 34pt, Label "Start") in MainTabView/RootView.swift - siehe
// dort. `DeltiqCentralActionButton` und `.deltiqCentralActionButtonOverlay`
// sind damit ersatzlos entfallen.

// MARK: - 6.10 Swipe-Back-Fix (Bug-Report)

#if canImport(UIKit)
/// Bug-Fix: `.navigationBarBackButtonHidden(true)` deaktiviert auf iOS als
/// dokumentierte Nebenwirkung auch den `interactivePopGestureRecognizer`
/// der UINavigationController - obwohl das Verstecken des nativen Zurueck-
/// Buttons rein visuell gemeint war. Jeder Signature-Geruest-Screen
/// versteckt die native Leiste komplett (eigener Chevron in `DeltiqHeader`
/// uebernimmt die Optik) und will die Wisch-Geste trotzdem behalten - das
/// war von Anfang an so dokumentiert (`DeltiqHeader`: "haelt die Swipe-
/// Back-Geste ueber den System-Default am Leben"), lief aber durch diesen
/// UIKit-Quirk ins Leere.
///
/// Hostet einen unsichtbaren `UIViewController`, der sobald er im
/// Navigation-Stack sitzt den Pop-Gesture-Recognizer des umschliessenden
/// `UINavigationController` wieder aktiviert und sich selbst als Delegate
/// setzt (das Verfahren ist der etablierte Community-Standard fuer dieses
/// Problem).
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let navigationController = controller.parent?.navigationController {
                navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
#endif

public extension View {
    /// Stellt die Swipe-Back-Geste wieder her, nachdem
    /// `.navigationBarBackButtonHidden(true)` sie (iOS-Quirk) mit
    /// abgeschaltet hat. `enabled: false` fuer Screens, die den nativen
    /// Zurueck-Weg bewusst UND vollstaendig sperren wollen (z.B.
    /// WorkoutSummaryView im frischen Post-Finish-Modus, wo `onBack`
    /// ebenfalls `nil` ist). Auf Nicht-UIKit-Plattformen (macOS-Build fuer
    /// `swift test`) ein No-Op.
    func deltiqSwipeBackEnabled(_ enabled: Bool = true) -> some View {
        #if canImport(UIKit)
        background {
            if enabled {
                SwipeBackEnabler()
            }
        }
        #else
        self
        #endif
    }
}
#endif
