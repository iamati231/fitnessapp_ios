import Foundation

/// Nachbesserung (Task #197, zweite Runde): ersetzt einen leeren `catch {}`
/// in `OnboardingView.finishOnboarding()` - "Onboarding nicht mit leerem
/// catch abschliessen". Das Profil wurde zu diesem Zeitpunkt bereits
/// gespeichert (der Onboarding-Abschluss selbst haengt daran, nicht an der
/// Plan-Erzeugung); scheitert NUR der anschliessende initiale
/// `PlanGeneratorInstantiator.createPlan(...)`-Aufruf, bleibt sonst kein
/// sichtbarer Hinweis, dass der Nutzer ohne Plan dasteht.
///
/// Reine Zustandsmarkierung ohne eigene Fehlerdetails: der Fehler selbst ist
/// zum Zeitpunkt des Lesens (Dashboard, nach Verlassen des Onboardings)
/// nicht mehr relevant - wichtig ist nur "es wurde ohne Plan fortgesetzt,
/// das muss jetzt sichtbar erklaert werden". `UserDefaults` statt
/// SwiftData: dieser Zustand gehoert nicht zu einem bestimmten Modellobjekt
/// und muss schon lesbar sein, bevor irgendein `ModelContext` existiert.
///
/// `consumeIfPending` liest UND loescht in einem Schritt, damit der Hinweis
/// im Dashboard GENAU EINMAL erscheint, nicht bei jedem weiteren
/// Dashboard-Aufruf erneut (gleiches Prinzip wie ein "einmaliger" Toast,
/// nur ueber App-Starts hinweg haltbar).
public enum OnboardingPlanCreationNotice {

    static let pendingKey = "onboardingInitialPlanCreationFailed"

    public static func markFailed(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: pendingKey)
    }

    @discardableResult
    public static func consumeIfPending(in defaults: UserDefaults = .standard) -> Bool {
        let wasPending = defaults.bool(forKey: pendingKey)
        if wasPending {
            defaults.removeObject(forKey: pendingKey)
        }
        return wasPending
    }
}
