import Foundation
import FitnessAppCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules + cancels recurring local notifications fuer Wasser- und Mess-
/// Reminder (DEL-028). Cross-platform-safe: auf Plattformen ohne
/// `UserNotifications` (Linux/Windows-Tests) sind alle Methoden no-ops.
///
/// **Spam-Schutz**: Vor jedem `schedule…` wird `removePending…` fuer die
/// gleiche Identifier-Praefix-Range gerufen, damit Settings-Toggle-Spam
/// nicht 500 Duplicate-Trigger im System hinterlaesst (User's Tipp).
///
/// **Identifier-Schema**:
///   - `water.NN` (00..23) — Stuendliche Slots, gefiltert nach Frequenz.
///   - `measurement.weekly` — wochentaeglicher Termin via Calendar-Trigger.
///
/// **Payload-Konvention**: `userInfo["reminder_type"]` enthaelt entweder
/// `"water"` oder `"measurement"`. AppDelegate's UNUC-Delegate liest das
/// fuer's NotificationRouter-Routing.
public enum ReminderScheduler {

    // MARK: - Payload-Keys

    public static let reminderTypeKey = "reminder_type"
    public static let waterPayload = "water"
    public static let measurementPayload = "measurement"

    // MARK: - Water reminders

    /// Schedules Wasser-Reminder im Bereich 08:00–20:00 alle `intervalHours`
    /// Stunden (z.B. 2 → 08:00/10:00/12:00/14:00/16:00/18:00/20:00).
    /// Wiederholend ueber `UNCalendarNotificationTrigger` mit repeats=true.
    public static func scheduleWaterReminders(everyHours intervalHours: Int) async {
        #if canImport(UserNotifications)
        guard await isAuthorized() else { return }

        // Spam-Schutz: alle existing Wasser-Trigger erst loeschen.
        await cancelWaterReminders()

        guard intervalHours > 0 else { return }
        let center = UNUserNotificationCenter.current()

        for hour in stride(from: 8, through: 20, by: intervalHours) {
            let content = UNMutableNotificationContent()
            content.title = "Wasser-Erinnerung"
            content.body = "Zeit für ein Glas Wasser 💧"
            content.sound = .default
            content.userInfo = [reminderTypeKey: waterPayload]

            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "water.\(String(format: "%02d", hour))",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
        #endif
    }

    public static func cancelWaterReminders() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let waterIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("water.") }
        center.removePendingNotificationRequests(withIdentifiers: waterIDs)
        #endif
    }

    // MARK: - Measurement reminder

    /// Schedules genau einen wochentaeglichen Mess-Reminder.
    ///
    /// - Parameters:
    ///   - weekday: 1=Sonntag, 2=Montag, ..., 7=Samstag (Apple-Convention)
    ///   - hour:    0..23
    ///   - minute:  0..59
    public static func scheduleMeasurementReminder(weekday: Int, hour: Int, minute: Int) async {
        #if canImport(UserNotifications)
        guard await isAuthorized() else { return }
        await cancelMeasurementReminder()

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Mess-Erinnerung"
        content.body = "Trag deine wöchentlichen Messwerte ein 📏"
        content.sound = .default
        content.userInfo = [reminderTypeKey: measurementPayload]

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "measurement.weekly",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
        #endif
    }

    public static func cancelMeasurementReminder() async {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["measurement.weekly"])
        #endif
    }

    // MARK: - DEL-204 Rest-Timer-Ende (Background-Feedback)

    /// Identifier des einen Rest-Timer-Slots. Es läuft immer maximal ein
    /// Pausen-Timer (DEL-044-Invariante) — ein fester Identifier genügt
    /// und macht das Cancel trivial.
    private static let restTimerIdentifier = "rest.timer.end"

    /// Plant die "Pause vorbei"-Notification für das Timer-Ende.
    ///
    /// In-App übernimmt die RestTimerBar Sound + Haptik; diese Notification
    /// ist NUR für den Background-Fall (Handy gesperrt / andere App) — der
    /// AppDelegate unterdrückt sie im Vordergrund explizit. Title/Body
    /// kommen lokalisiert vom Caller, weil dieses Modul kein eigenes
    /// String-Catalog-Bundle hat.
    public static func scheduleRestTimerEnd(
        after seconds: Int,
        title: String,
        body: String
    ) async {
        #if canImport(UserNotifications)
        guard seconds > 0, await isAuthorized() else { return }
        await cancelRestTimerEnd()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: restTimerIdentifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    /// Räumt die geplante Rest-Timer-Notification ab — sowohl pending
    /// (Timer wurde geskippt/neu gestartet) als auch delivered (Timer lief
    /// im Background ab, User kommt zurück → Banner soll nicht im
    /// Notification-Center gammeln).
    public static func cancelRestTimerEnd() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restTimerIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [restTimerIdentifier])
        #endif
    }

    /// True wenn die Notification-Identifier zum Rest-Timer gehört —
    /// der AppDelegate nutzt das, um Foreground-Banner zu unterdrücken
    /// (In-App-Feedback übernimmt dann die RestTimerBar).
    public static func isRestTimerNotification(identifier: String) -> Bool {
        identifier == restTimerIdentifier
    }

    // MARK: - Zeitformate: EMOM Hintergrund-Signal (README 2.9, Phase 4)

    /// Identifier-Praefix fuer die EMOM-Minutentrigger (`emom.minute.01` ...).
    private static let emomIdentifierPrefix = "emom.minute."

    /// Plant EIN Signal pro Minutenwechsel im Voraus, inklusive Abschluss-
    /// Signal fuer die letzte Minute.
    ///
    /// Anders als `scheduleRestTimerEnd` (ein einzelner, bei jedem Reset neu
    /// gesetzter Slot) braucht EMOM ALLE `totalMinutes` Trigger auf einmal:
    /// `Timer.publish` im Player pausiert, sobald die App backgrounded wird,
    /// es gibt also keine Gelegenheit, waehrend des Trainings neu zu planen.
    /// In-App uebernehmen TimerSoundPlayer + Haptik das Feedback; diese
    /// Notifications sind NUR fuers Background-/Lock-Screen-Feedback -
    /// der AppDelegate unterdrueckt sie im Vordergrund (kein Doppel-Feedback,
    /// gleiche Logik wie beim Rest-Timer).
    ///
    /// Die Signale haengen am START des Laufs, nicht an "jetzt" (`EMOMSignalSchedule`):
    /// Wer mitten im Lauf neu plant (Tab-Rueckkehr, "Training fortsetzen"), gibt die
    /// schon verstrichene Zeit mit - sonst verschoeben sich alle Signale um sie.
    ///
    /// - Parameters:
    ///   - totalMinutes: Gesamtzahl EMOM-Minuten (== Rundenanzahl).
    ///   - elapsedSeconds: Seit dem Start verstrichene Sekunden (0 beim Start).
    ///   - minuteTitle: Titel fuer jeden Minutenwechsel VOR der letzten Minute.
    ///   - minuteBodyFormat: lokalisiertes Format mit einem `%lld`-Platzhalter
    ///     fuer die kommende Minutennummer (z.B. "Minute %lld beginnt").
    ///   - finishTitle/finishBody: Text fuer den letzten Trigger (EMOM komplett).
    public static func scheduleEMOMSignals(
        totalMinutes: Int,
        elapsedSeconds: Int = 0,
        minuteTitle: String,
        minuteBodyFormat: String,
        finishTitle: String,
        finishBody: String
    ) async {
        #if canImport(UserNotifications)
        guard totalMinutes > 0, await isAuthorized() else { return }
        await cancelEMOMSignals()

        let center = UNUserNotificationCenter.current()
        for signal in EMOMSignalSchedule.signals(totalMinutes: totalMinutes, elapsedSeconds: elapsedSeconds) {
            let content = UNMutableNotificationContent()
            content.title = signal.isFinal ? finishTitle : minuteTitle
            content.body = signal.isFinal ? finishBody : String(format: minuteBodyFormat, signal.minute + 1)
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(signal.delaySeconds),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(emomIdentifierPrefix)\(String(format: "%02d", signal.minute))",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
        #endif
    }

    /// Raeumt alle geplanten UND bereits zugestellten EMOM-Trigger ab -
    /// analog zu `cancelRestTimerEnd`. Muss in JEDEM Pfad laufen, der die
    /// EMOM-Session beendet/verlaesst (Finish, Discard, Zurueck-Chevron),
    /// sonst poppen spaeter Banner fuer eine laengst verlassene Session auf.
    public static func cancelEMOMSignals() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        // Geplante UND schon zugestellte getrennt abfragen: Eine zugestellte
        // Benachrichtigung steht nicht mehr in der Liste der geplanten, ihre Kennung
        // laesst sich daraus also nicht ableiten - die Banner blieben sonst in der
        // Mitteilungszentrale liegen.
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let pendingIDs = pending.map(\.identifier).filter { $0.hasPrefix(emomIdentifierPrefix) }
        let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(emomIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        #endif
    }

    /// True wenn die Notification-Identifier zu einem EMOM-Minutentrigger
    /// gehoert - der AppDelegate nutzt das, um Foreground-Banner zu
    /// unterdruecken (In-App-Feedback uebernimmt dann TimerSoundPlayer).
    public static func isEMOMNotification(identifier: String) -> Bool {
        identifier.hasPrefix(emomIdentifierPrefix)
    }

    // MARK: - Helpers

    /// Checkt aktuelle Authorization-Status. Reminder-Scheduling nur wenn
    /// `authorized | provisional | ephemeral` — sonst silenter no-op.
    private static func isAuthorized() async -> Bool {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
        #else
        return false
        #endif
    }

    /// Debug-Helper: zaehlt aktuelle pending Reminder-Slots. Settings-View
    /// kann das zeigen ("X Reminder aktiv") als Sanity-Feedback.
    public static func pendingReminderCount() async -> Int {
        #if canImport(UserNotifications)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending
            .filter { $0.identifier.hasPrefix("water.") || $0.identifier == "measurement.weekly" }
            .count
        #else
        return 0
        #endif
    }
}
