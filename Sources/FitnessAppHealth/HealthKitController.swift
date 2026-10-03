import Foundation
import Observation

/// `@MainActor`-bound `@Observable` facade over `HealthKitService` — this is what
/// SwiftUI views read via `@Environment(HealthKitController.self)`.
///
/// Cross-platform by design: on Windows (no HealthKit) every method is a no-op and
/// `isAvailable` reports `false`. On iOS the methods proxy to the actor service.
/// This keeps the UI layer free of `#if canImport(HealthKit)` litter — views just
/// branch on `isAvailable` / `authorizationStatus`.
///
/// **Thread model**: all observable mutations happen on the main actor (so SwiftUI
/// reads are safe). Heavy lifting lives in the underlying `HealthKitService` actor.
@MainActor
@Observable
public final class HealthKitController {

    public private(set) var authorizationStatus: HealthKitAuthorizationStatus = .unavailable
    public private(set) var isAvailable: Bool = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastError: (any Error)?

    #if canImport(HealthKit)
    private let service: HealthKitService?
    #endif

    public init() {
        #if canImport(HealthKit)
        if let s = try? HealthKitService() {
            self.service = s
            self.isAvailable = true
            self.authorizationStatus = .notDetermined
        } else {
            self.service = nil
        }
        #endif
    }

    // MARK: Authorization

    /// Pulls the current write-side authorization status from HealthKit. Cheap to call
    /// — view code can run this on `.task` without worrying about cost.
    public func refreshAuthorizationStatus() async {
        #if canImport(HealthKit)
        guard let service else { return }
        authorizationStatus = await service.currentAuthorizationStatus()
        #endif
    }

    /// Triggers the native HealthKit permission sheet. After the user responds,
    /// `authorizationStatus` reflects the new state.
    public func requestAuthorization() async {
        #if canImport(HealthKit)
        guard let service else { return }
        do {
            try await service.requestAuthorization()
            authorizationStatus = await service.currentAuthorizationStatus()
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }

    /// Narrow, separate request just for reading other apps' workouts (e.g.
    /// Adidas Running). Kept out of `requestAuthorization()` on purpose — see
    /// `HealthKitService.requestWorkoutReadAuthorization`. Errors land in
    /// `lastError`; there is no status to reflect afterwards, since HealthKit
    /// never discloses read-grant/deny.
    public func requestWorkoutReadAuthorization() async {
        #if canImport(HealthKit)
        guard let service else { return }
        do {
            try await service.requestWorkoutReadAuthorization()
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }

    // MARK: Reads

    /// Latest body-mass sample, in kg. Returns `nil` when HealthKit isn't authorized
    /// or has no data — never throws (errors land in `lastError`).
    public func latestWeightKg() async -> Double? {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return nil }
        do {
            return try await service.latestWeight()?.weightKg
        } catch {
            lastError = error
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Latest body-fat percent (0..100). Same nil-on-failure semantics.
    public func latestBodyFatPercent() async -> Double? {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return nil }
        do {
            return try await service.latestBodyFatPercent()
        } catch {
            lastError = error
            return nil
        }
        #else
        return nil
        #endif
    }

    /// DEL-132 (Phase 3): Letzter Ruhepuls aus HealthKit, in BPM. Identische
    /// nil-on-failure-Semantik wie die Body-Composition-Reader. Fehler
    /// landen in `lastError`, der Caller kriegt nil — die UI rendert dann
    /// "—" als Card-Wert.
    public func latestRestingHeartRateBPM() async -> Double? {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return nil }
        do {
            return try await service.latestRestingHeartRateBPM()
        } catch {
            lastError = error
            return nil
        }
        #else
        return nil
        #endif
    }

    /// DEL-132 (Phase 3): Heutige Schritte aus HealthKit (cumulative sum
    /// von startOfDay bis jetzt). nil-on-failure.
    public func stepCountToday() async -> Double? {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return nil }
        do {
            return try await service.stepCountToday()
        } catch {
            lastError = error
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Aggregate pull used by the onboarding HealthKit-step. Fetches DOB, sex,
    /// height, and weight in parallel. Returns `OnboardingHealthSnapshot.empty`
    /// when HealthKit is unavailable / unauthorized — caller checks individual
    /// optionals and falls back to manual entry per field.
    public func loadOnboardingSnapshot() async -> OnboardingHealthSnapshot {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else {
            return .empty
        }

        // Run the four reads in parallel — none depends on another.
        async let dob = service.dateOfBirth()
        async let sexHK = service.biologicalSex()
        async let height: Double? = {
            do { return try await service.latestHeightCm() } catch { return nil }
        }()
        async let weight: Double? = {
            do { return try await service.latestWeight()?.weightKg } catch { return nil }
        }()

        let mappedSex: BiologicalSex
        switch await sexHK {
        case .male:    mappedSex = .male
        case .female:  mappedSex = .female
        case .other:   mappedSex = .other
        case .notSet:  mappedSex = .notSet
        @unknown default: mappedSex = .notSet
        }

        return OnboardingHealthSnapshot(
            dateOfBirth: await dob,
            sex: mappedSex,
            heightCm: await height,
            weightKg: await weight
        )
        #else
        return .empty
        #endif
    }

    /// Pulls running/cycling workouts written by OTHER apps since `since`
    /// (all-time when `nil`). Empty on any failure — same nil/empty-on-failure
    /// contract as the other reads, errors land in `lastError`. Does NOT gate
    /// on `authorizationStatus` (that only reflects the WRITE-side status —
    /// see `HealthKitAuthorizationStatus` — and would incorrectly block this
    /// read even when workout-read was separately granted).
    public func fetchExternalWorkouts(since: Date?) async -> [ExternalWorkoutSample] {
        #if canImport(HealthKit)
        guard let service else { return [] }
        do {
            return try await service.fetchExternalWorkouts(since: since)
        } catch {
            lastError = error
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: Writes

    /// Best-effort write of a complete body-composition snapshot. Each metric is
    /// written independently — if body-fat fails (e.g., user revoked sharing for
    /// that type only), weight may still go through. Errors accumulate into
    /// `lastError` but don't propagate out.
    ///
    /// Pass nil for `bodyFatPct` / `fatFreeMassKg` to skip those writes (use when
    /// the user only entered weight).
    public func saveMeasurement(
        weightKg: Double,
        bodyFatPct: Double?,
        fatFreeMassKg: Double?,
        date: Date
    ) async {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return }
        var firstError: (any Error)?

        do { try await service.saveWeight(weightKg, on: date) }
        catch { firstError = firstError ?? error }

        if let bf = bodyFatPct {
            do { try await service.saveBodyFatPercent(bf, on: date) }
            catch { firstError = firstError ?? error }
        }
        if let ffm = fatFreeMassKg {
            do { try await service.saveLeanBodyMass(ffm, on: date) }
            catch { firstError = firstError ?? error }
        }

        if let firstError {
            lastError = firstError
        } else {
            lastSyncDate = Date()
            lastError = nil
        }
        #endif
    }

    /// Best-effort push of a completed strength-training workout to Apple Health.
    /// Fills the Activity rings and shows up in the Fitness app like a watch-
    /// recorded session. Errors land in `lastError`; the caller's main flow
    /// (saving the SwiftData session, navigating to summary) is never blocked.
    public func saveWorkout(
        startDate: Date,
        endDate: Date,
        totalSets: Int,
        totalVolumeKg: Double
    ) async {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return }
        do {
            try await service.saveStrengthTrainingWorkout(
                startDate: startDate,
                endDate: endDate,
                totalSets: totalSets,
                totalVolumeKg: totalVolumeKg
            )
            lastSyncDate = Date()
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }

    /// DEL-063: Best-effort push einer Cardio-Session (Hybrid-Lauftag) als
    /// `.running`, mit angehaengtem Distanz-Sample wenn der User dessen
    /// Typ freigegeben hat (sonst ohne). Wenn der User Apple Health nicht
    /// autorisiert hat, ist das ein No-Op — Caller-Flow wird nicht
    /// blockiert.
    public func saveRunningWorkout(
        startDate: Date,
        endDate: Date,
        totalDistanceKm: Double,
        averagePaceMinPerKm: Double?
    ) async {
        #if canImport(HealthKit)
        guard let service, authorizationStatus == .sharingAuthorized else { return }
        do {
            try await service.saveRunningWorkout(
                startDate: startDate,
                endDate: endDate,
                totalDistanceKm: totalDistanceKm,
                averagePaceMinPerKm: averagePaceMinPerKm
            )
            lastSyncDate = Date()
            lastError = nil
        } catch {
            lastError = error
        }
        #endif
    }
}
