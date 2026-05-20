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
#endif
