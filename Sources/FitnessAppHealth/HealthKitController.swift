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
}
