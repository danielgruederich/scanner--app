import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {

    var onBarcodeScanned: ((String) -> Void)?
    let captureSession = AVCaptureSession()

    func setup(useFrontCamera: Bool = false) {
        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.pdf417, .qr, .code128, .ean13, .ean8]
        }
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func stop() {
        captureSession.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              value.isValidCardID else { return }
        stop()
        onBarcodeScanned?(value)
    }
}
