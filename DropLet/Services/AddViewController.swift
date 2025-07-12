import AVFoundation
import Combine
import SwiftUI

class AddViewController: NSObject, AVCaptureMetadataOutputObjectsDelegate, ObservableObject {
    var isProcessingBarcode = false
    var lastScannedBarcode: String?
    var lastScanTime: Date?
    let scanCooldown: TimeInterval = 2.0
    var onBarcodeScanned: ((String) -> Void)?
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = metadataObject.stringValue else {
            return
        }
        
        guard !isProcessingBarcode else { return }
        
        if let lastBarcode = lastScannedBarcode,
           let lastTime = lastScanTime,
           lastBarcode == barcode && Date().timeIntervalSince(lastTime) < scanCooldown {
            return
        }
        
        isProcessingBarcode = true
        lastScannedBarcode = barcode
        lastScanTime = Date()
        
        onBarcodeScanned?(barcode)
    }
}
