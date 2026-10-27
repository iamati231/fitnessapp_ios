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

    /// UX-Katalog-Erweiterung (Spec 2.7): "Barcode manuell eingeben" nutzt
    /// DENSELBEN `onDetect`-Callback wie die Kamera — dieselbe Verarbeitung,
    /// derselbe Double-Lookup-Guard (`BarcodeLookupController.hasStartedLookup`
    /// in `AddMealView`), keine zweite Lookup-Implementierung.
    @State private var showingManualEntry: Bool = false
    @State private var manualBarcodeText: String = ""
    @State private var manualBarcodeError: String?

    private var isDeviceSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Spec 2.7 Punkt 1: eigener, Deltiq-gestalteter Kopfbereich
                // statt der nativen Navigationsleiste — gleiches Geruest wie
                // `AddMealView`s eigener Header.
                DeltiqHeader(
                    eyebrow: String(localized: "tab.nutrition", bundle: .module).uppercased(),
                    title: String(localized: "nutrition.barcode.scanAction", bundle: .module),
                    onBack: onCancel
                )
                Text("nutrition.barcode.instructions", bundle: .module)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Deltiq.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                manualEntrySection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .background(Color.Deltiq.background.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationBarBackButtonHidden(true)
            .task {
                await checkPermission()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch barcodeScanAvailability(isDeviceSupported: isDeviceSupported, permission: permissionChecked ? permission : .notDetermined) {
        case .unsupportedDevice:
            statusCard(message: "nutrition.barcode.unsupportedDevice")
        case .permissionDenied:
            statusCard(message: "nutrition.barcode.permissionDenied", showsOpenSettings: true)
        case .permissionNotDetermined:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            VStack(spacing: 10) {
                // Spec 2.7 Punkt 2/3: grosse, aber klar begrenzte,
                // abgerundete Live-Kamerakarte statt einer unstrukturierten
                // Vollflaeche — Scan-Rahmen ist rein dekorativ
                // (`allowsHitTesting(false)`), die tatsaechliche
                // Erkennungsflaeche des Scanners ist technisch NICHT auf den
                // sichtbaren Rahmen eingeschraenkt.
                ZStack {
                    RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous)
                        .fill(Color.black)
                    DataScannerRepresentable(onDetect: onDetect)
                        .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.card, style: .continuous))
                    ScanFrameCorners()
                        .allowsHitTesting(false)
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(.horizontal, 16)

                Text("nutrition.barcode.autoDetectHint", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Deltiq.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func statusCard(message: LocalizedStringKey, showsOpenSettings: Bool = false) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Spec 2.7 Punkt 5: sekundaere, immer erreichbare Alternative zur
    /// Kamera — auch im Berechtigungs-/Nichtverfuegbar-Zustand sichtbar
    /// (`content` oben zeigt dort nur die Kamerakarte nicht; dieser Bereich
    /// bleibt unabhaengig davon bestehen).
    @ViewBuilder
    private var manualEntrySection: some View {
        if showingManualEntry {
            VStack(alignment: .leading, spacing: 8) {
                TextField(String(localized: "nutrition.barcode.manualPlaceholder", bundle: .module), text: $manualBarcodeText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.Deltiq.fill)
                    .clipShape(RoundedRectangle(cornerRadius: Deltiq.Radius.input, style: .continuous))

                if let manualBarcodeError {
                    Text(manualBarcodeError)
                        .font(.caption)
                        .foregroundStyle(Color.Deltiq.error)
                }

                Button {
                    submitManualBarcode()
                } label: {
                    Text("nutrition.barcode.manualSubmit", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Button {
                showingManualEntry = true
            } label: {
                Text("nutrition.barcode.manualEntry", bundle: .module)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.deltiqOrange)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    /// Gleicher Guard wie `OpenFoodFactsBarcodeLookupClient` (nur Ziffern,
    /// nicht leer) — EAN-13/EAN-8/UPC sind per Konstruktion rein numerisch,
    /// genau die Symbologien, auf die der Scanner beschraenkt ist. Barcode
    /// bleibt durchgehend ein `String` (fuehrende Nullen bleiben erhalten);
    /// bei Erfolg derselbe `onDetect`-Callback wie ein Kamera-Treffer.
    private func submitManualBarcode() {
        let trimmed = manualBarcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else {
            manualBarcodeError = String(localized: "nutrition.barcode.manualInvalid", bundle: .module)
            return
        }
        manualBarcodeError = nil
        onDetect(trimmed)
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

/// Rein dekorative Eckmarkierungen ueber der Live-Kamerakarte — visuelle
/// Orientierung, keine technische Scanflaechen-Begrenzung (siehe Aufrufer-
/// Kommentar). `allowsHitTesting(false)` wird vom Aufrufer gesetzt.
@available(iOS 17.0, *)
private struct ScanFrameCorners: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let length: CGFloat = 28
            Path { path in
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))

                path.move(to: CGPoint(x: width - length, y: 0))
                path.addLine(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: length))

                path.move(to: CGPoint(x: 0, y: height - length))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: length, y: height))

                path.move(to: CGPoint(x: width - length, y: height))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: width, y: height - length))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .padding(18)
        }
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
