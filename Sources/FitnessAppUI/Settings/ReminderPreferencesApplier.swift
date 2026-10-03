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
/// sein koennen: am Ende des Onboardings, nach einem Backup-Import im
/// Onboarding, nach dem Daten-Import und der Backup-Wiederherstellung in den
/// Einstellungen sowie bei jedem App-Start (eine Geraete-Wiederherstellung
/// bringt die Schalter zurueck, nicht aber die geplanten Benachrichtigungen).
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
