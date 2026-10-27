/// Mirrors `AVAuthorizationStatus` (video) without importing AVFoundation
/// into this type, so the decision logic below is plain Swift — testable on
/// any platform `swift test` runs on, same reasoning as every other
/// cross-platform controller in this file family. `BarcodeScannerSheet`
/// (iOS-only, VisionKit/AVFoundation) maps the real system status into this
/// enum at the one call site that actually touches the camera.
enum CameraPermissionState: Equatable {
    case authorized
    case notDetermined
    case deniedOrRestricted
}

/// What the barcode-scan UI should show, given whether the device supports
/// live scanning at all and the current camera permission. Pure function —
/// no crash path exists because every input combination maps to a defined
/// case; "nicht unterstütztes Gerät"/"Kamerazugriff verweigert" (brief,
/// section 3) are exactly `.unsupportedDevice`/`.permissionDenied` here.
enum BarcodeScanAvailability: Equatable {
    case ready
    case unsupportedDevice
    case permissionNotDetermined
    case permissionDenied
}

func barcodeScanAvailability(isDeviceSupported: Bool, permission: CameraPermissionState) -> BarcodeScanAvailability {
    guard isDeviceSupported else { return .unsupportedDevice }
    switch permission {
    case .authorized: return .ready
    case .notDetermined: return .permissionNotDetermined
    case .deniedOrRestricted: return .permissionDenied
    }
}
