import XCTest
@testable import FitnessAppCore

/// DEL-228: Ein Fehler in Richtung "nie faellig" ist der teure: der User
/// glaubt dann, Backups zu haben, und hat keine.
final class BackupScheduleTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_770_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    func testFirstEverBackupIsDueWhenDataExists() {
        XCTAssertTrue(BackupSchedule.shouldCreateBackup(
            lastBackupAt: nil, now: now, hasData: true
        ))
    }

    /// Frische Installation: keine leeren Generationen anlegen, die spaeter
    /// die Rotation belegen und echte Backups verdraengen.
    func testNoBackupWithoutData() {
        XCTAssertFalse(BackupSchedule.shouldCreateBackup(
            lastBackupAt: nil, now: now, hasData: false
        ))
        XCTAssertFalse(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-10 * day), now: now, hasData: false
        ))
    }

    func testNotDueWithinInterval() {
        XCTAssertFalse(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-3600), now: now, hasData: true
        ))
    }

    func testDueExactlyAtInterval() {
        XCTAssertTrue(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-day), now: now, hasData: true
        ))
    }

    func testDueAfterInterval() {
        XCTAssertTrue(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-5 * day), now: now, hasData: true
        ))
    }

    func testCustomIntervalIsHonored() {
        let hour: TimeInterval = 3600
        XCTAssertFalse(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-1800), now: now, interval: hour, hasData: true
        ))
        XCTAssertTrue(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(-7200), now: now, interval: hour, hasData: true
        ))
    }

    /// Der wichtigste Randfall: ein Zeitstempel in der ZUKUNFT. Entsteht bei
    /// manueller Uhr-Umstellung, Zeitzonen-Reisen oder einem Restore mit
    /// fremdem Stempel. Ohne Sonderbehandlung waere nie wieder ein Backup
    /// faellig, bis die echte Zeit den falschen Stempel eingeholt hat — im
    /// Extremfall jahrelang.
    func testFutureTimestampIsTreatedAsDue() {
        XCTAssertTrue(BackupSchedule.shouldCreateBackup(
            lastBackupAt: now.addingTimeInterval(365 * day), now: now, hasData: true
        ))
    }

    func testDefaultIntervalIsOneDay() {
        XCTAssertEqual(BackupSchedule.defaultInterval, 24 * 60 * 60, accuracy: 0.5)
    }
}
