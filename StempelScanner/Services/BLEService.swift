import CoreBluetooth
import Combine

/// Manages the BLE connection to the NETUM C750 in BLE mode.
///
/// IMPORTANT: The scanner MUST be set to BLE mode (not HID).
/// HID mode causes iOS to treat the device as a keyboard, hiding the
/// on-screen keyboard and making the POS system unusable.
///
/// NETUM C750 BLE GATT profile (most common firmware):
///   Service:        FFF0  (0000FFF0-0000-1000-8000-00805F9B34FB)
///   Notify char:    FFF1  (0000FFF1-0000-1000-8000-00805F9B34FB)
///   Write char:     FFF2  (0000FFF2-0000-1000-8000-00805F9B34FB)
///
/// If your firmware uses different UUIDs, update the constants below.
final class BLEService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isBluetoothReady = false
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var scannerName: String = "Kein Scanner"
    @Published var statusMessage = "Bluetooth wird initialisiert…"
    @Published var lastScannedCardID: String?

    // MARK: - Callback

    /// Called on the main thread whenever a complete barcode string arrives.
    var onCodeScanned: ((String) -> Void)?

    // MARK: - BLE UUIDs (NETUM C750)

    /// Primary service UUID for NETUM BLE mode
    private let primaryServiceUUID = CBUUID(string: "FFF0")
    /// Fallback service UUID (some firmware revisions)
    private let fallbackServiceUUID = CBUUID(string: "18F0")

    private let notifyCharUUID = CBUUID(string: "FFF1")
    private let fallbackCharUUID = CBUUID(string: "2AF1")

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private var dataBuffer = Data()
    private var reconnectTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main,
                                          options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        guard !isConnected else { return }
        isScanning = true
        statusMessage = "Suche nach NETUM Scanner…"
        centralManager.scanForPeripherals(
            withServices: [primaryServiceUUID, fallbackServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        isConnected = false
        scannerName = "Kein Scanner"
    }

    // MARK: - Private helpers

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.startScanning()
        }
    }

    private func handleIncomingData(_ data: Data) {
        dataBuffer.append(data)

        let terminators: [UInt8] = [0x0D, 0x0A] // CR, LF
        while let termIdx = dataBuffer.firstIndex(where: { terminators.contains($0) }) {
            let codeData = dataBuffer[dataBuffer.startIndex..<termIdx]
            var nextIdx = dataBuffer.index(after: termIdx)
            if dataBuffer[termIdx] == 0x0D &&
               nextIdx < dataBuffer.endIndex &&
               dataBuffer[nextIdx] == 0x0A {
                nextIdx = dataBuffer.index(after: nextIdx)
            }
            dataBuffer = Data(dataBuffer[nextIdx...])

            guard let code = String(data: codeData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty else { continue }

            if code.isValidCardID {
                lastScannedCardID = code
                onCodeScanned?(code)
            }
        }

        // Safety: discard buffer if it grows unreasonably (corrupt stream)
        if dataBuffer.count > 512 {
            dataBuffer.removeAll()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
            statusMessage = "Bluetooth bereit. Verbinde Scanner…"
            startScanning()
        case .poweredOff:
            isBluetoothReady = false
            isConnected = false
            statusMessage = "Bluetooth ist deaktiviert. Bitte aktivieren."
        case .unauthorized:
            statusMessage = "Bluetooth-Berechtigung fehlt. Bitte in Einstellungen erlauben."
        case .unsupported:
            statusMessage = "Bluetooth LE wird auf diesem Gerät nicht unterstützt."
        default:
            statusMessage = "Bluetooth nicht verfügbar."
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        let name = peripheral.name ?? "Unbekanntes Gerät"
        statusMessage = "Verbinde mit \(name)…"
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        scannerName = peripheral.name ?? "NETUM Scanner"
        statusMessage = "Verbunden mit \(scannerName)"
        reconnectTimer?.invalidate()
        dataBuffer.removeAll()
        peripheral.discoverServices([primaryServiceUUID, fallbackServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        statusMessage = "Verbindungsfehler. Versuche erneut…"
        scheduleReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        scannerName = "Kein Scanner"
        statusMessage = "Scanner getrennt. Verbinde erneut…"
        scheduleReconnect()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            statusMessage = "Service-Erkennung fehlgeschlagen: \(error?.localizedDescription ?? "")"
            return
        }
        for service in services {
            peripheral.discoverCharacteristics([notifyCharUUID, fallbackCharUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
                dataCharacteristic = characteristic
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            statusMessage = "Notify-Fehler: \(error.localizedDescription)"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        handleIncomingData(data)
    }
}
