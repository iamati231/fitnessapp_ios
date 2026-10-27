#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI

#if os(iOS)
import Foundation
import VisionKit
import AVFoundation

/// Task: Barcode-Scan ergänzen. Live camera scanner using VisionKit's
/// `DataScannerViewController` (iOS 16+; deployment target here is iOS 17,
/// see `project.yml`), restricted to the product-barcode symbologies the
/// brief asks for. UPC-A has no distinct `VNBarcodeSymbology` case — Vision
/// reports UPC-A as EAN-13 with a leading zero, so `.ean13` alone already
/// covers it; `.upce` covers the separate UPC-E compact format.
///
/// NOTE: this file could not be compiled or run on this (Windows, no Xcode/
/// VisionKit SDK) machine — only parsed for balanced syntax. The exact
/// VisionKit API surface (enum case names, delegate signature,
/// `DataScannerViewController` initializer parameters) is written from
/// documented Apple API knowledge and needs confirming on the first real
/// Xcode/Codemagic build.
@available(iOS 17.0, *)
struct BarcodeScannerSheet: View {
    let onDetect: (String) -> Void
    let onCancel: () -> Void

    @State private var permission: CameraPermissionState = .notDetermined
    @State private var permissionChecked: Bool = false

    private var isDeviceSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("nutrition.barcode.scanAction", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            onCancel()
                        } label: {
                            Text("common.cancel", bundle: .module)
                        }
                    }
                }
                .task {
                    await checkPermission()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch barcodeScanAvailability(isDeviceSupported: isDeviceSupported, permission: permissionChecked ? permission : .notDetermined) {
        case .unsupportedDevice:
            statusView(message: "nutrition.barcode.unsupportedDevice")
        case .permissionDenied:
            statusView(message: "nutrition.barcode.permissionDenied", showsOpenSettings: true)
        case .permissionNotDetermined:
            ProgressView()
        case .ready:
            ZStack(alignment: .top) {
                DataScannerRepresentable(onDetect: onDetect)
                Text("nutrition.barcode.instructions", bundle: .module)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 12)
            }
        }
    }

    private func statusView(message: String, showsOpenSettings: Bool = false) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 36))
                .foregroundStyle(Color.Deltiq.textSecondary)
            Text(message, bundle: .module)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Deltiq.textSecondary)
            if showsOpenSettings {
                Button {
                    AppSettingsLink.open()
                } label: {
                    Text("settings.reminders.permission.openSettings", bundle: .module)
                }
            }
        }
        .padding()
    }

    private func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .deniedOrRestricted
        default:
            permission = .deniedOrRestricted
        }
        permissionChecked = true
    }
}

@available(iOS 17.0, *)
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onDetect: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .accurate,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !uiViewController.isScanning else { return }
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDetect: onDetect)
    }

    /// Owns the "process at most one barcode per scan" guard at the UI
    /// layer — `BarcodeLookupController.hasStartedLookup` guards the NETWORK
    /// call itself, this guards the delegate callback from even firing
    /// `onDetect` twice while a SwiftUI update cycle is in flight.
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onDetect: (String) -> Void
        private var didFire = false

        init(onDetect: @escaping (String) -> Void) {
            self.onDetect = onDetect
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didFire, let item = addedItems.first, case .barcode(let barcode) = item,
                  let payload = barcode.payloadStringValue else { return }
            didFire = true
            onDetect(payload)
        }
    }
}

#else

/// Non-iOS fallback — compiled on macOS so `swift test` can build/run this
/// file's module at all (`AddMealView` references `BarcodeScannerSheet`
/// unconditionally). Also doubles as the real "not supported on this
/// platform" UI, matching the brief's "nicht unterstütztes Gerät darf nicht
/// abstürzen" requirement for any non-scanning-capable target.
@available(iOS 17.0, macOS 14.0, *)
struct BarcodeScannerSheet: View {
    let onDetect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("nutrition.barcode.unsupportedDevice", bundle: .module)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .padding()
            .navigationTitle(Text("nutrition.barcode.scanAction", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
    }
}

#endif
#endif
