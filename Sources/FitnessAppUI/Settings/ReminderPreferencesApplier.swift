import Foundation
import FitnessAppCore
import FitnessAppActivities

/// Gleicht die System-Benachrichtigungen (Wasser + Messung) mit den
/// gespeicherten Erinnerungs-Praeferenzen ab: Schalter an → planen, aus →
/// abraeumen. Der `ReminderScheduler` raeumt vor jedem Planen selbst auf und
/// ist ohne Benachrichtigungs-Erlaubnis ein stiller No-Op — der Aufruf ist
/// damit idempotent und braucht keine eigene Berechtigungslogik.
///
/// Aufgerufen wird er an jeder Stelle, an der die Schalter gespeichert, die
/// Benachrichtigungen im System aber noch nicht (oder nicht mehr) vorhanden
/// sein koennen: nach dem Onboarding, nach einem Backup-Import, nach einem
/// Settings-Import und bei jedem App-Start (Neuinstallation und
/// Geraete-Wiederherstellung nehmen die geplanten Benachrichtigungen mit).
enum ReminderPreferencesApplier {

    static func applyStoredSchedules() async {
        let prefs = ReminderPreferences.load()

        if prefs.waterEnabled {
            await ReminderScheduler.scheduleWaterReminders(everyHours: prefs.waterIntervalHours)
        } else {
            await ReminderScheduler.cancelWaterReminders()
        }

        if prefs.measurementEnabled {
            await ReminderScheduler.scheduleMeasurementReminder(
                weekday: prefs.measurementWeekday,
                hour: prefs.measurementHour,
                minute: 0
            )
        } else {
            await ReminderScheduler.cancelMeasurementReminder()
        }
    }
}
