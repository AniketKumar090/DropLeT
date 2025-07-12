import SwiftUI
import AVFoundation

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @Binding var volume: CGFloat
    @FocusState.Binding var isCustomVolumeFieldFocused: Bool
    @StateObject private var cameraService = CameraService()
    private let gridHeight: CGFloat = 140
    @State private var onTapSelection = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingScanResult = false
    
    // Create a controller instance for handling barcode scanning
    @StateObject private var barcodeController = AddViewController()
    private let metadataOutput = AVCaptureMetadataOutput()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 24) {
                    // TextField section
                    HStack(spacing: 20) { // Increased spacing for better visual balance
                        // Custom Volume TextField
                        TextField(viewModel.useOunces ? "Custom Volume (oz)" : "Custom Volume (ml)",
                                  text: $viewModel.customVolume)
                            .keyboardType(.decimalPad)
                            .focused($isCustomVolumeFieldFocused)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced)) // Slightly larger, modern font
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.15)))
                            .onChange(of: viewModel.customVolume) { newValue in
                                if let convertedVolume = viewModel.useOunces
                                    ? viewModel.ozToMl(Double(newValue) ?? 0)
                                    : Double(newValue) {
                                    volume = CGFloat(convertedVolume)
                                }
                            }
                        
                        // Barcode Scan Button
                        Button(action: {
                            isCustomVolumeFieldFocused = false
                            viewModel.isScanning.toggle()
                            if viewModel.isScanning {
                                setupBarcodeScanning()
                                print("Starting camera...")
                                cameraService.startCamera()
                            } else {
                                print("Stopping camera...")
                                cameraService.stopCamera()
                            }
                        }, label: {
                            Image(systemName: viewModel.isScanning ? "xmark" : "barcode.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28) // Slightly larger, better fit
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.25)) // Different color based on scan state
                                        .frame(width: 50, height: 50)
                                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3) // Subtle shadow for depth
                                )
                                .padding(.trailing, 12) // Reduced padding to balance
                        }).sensoryFeedback(.impact, trigger: viewModel.isScanning)
                    }
                    .padding(.horizontal, 20)
                   // .padding(.vertical, 10) // Extra vertical padding for better spacing

                    // Camera/Grid section
                    if viewModel.isScanning {
                        CameraPreviewView(cameraService: cameraService)
                            .frame(height: gridHeight)
                            .overlay(ScannerShimmerView())
                            .mask(
                                RoundedRectangle(cornerRadius: 12)
                                    .padding(.horizontal, 24)
                            )
                            .overlay(
                                Group {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.5)
                                    }
                                }
                            )
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 0) {
                            ForEach(viewModel.selectedQuickSelections, id: \.id) { selection in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if viewModel.selectedVolume == CGFloat(selection.volume) {
                                            viewModel.selectedVolume = nil
                                            volume = 0
                                            viewModel.customVolume = ""
                                        } else {
                                            viewModel.selectedVolume = CGFloat(selection.volume)
                                            volume = CGFloat(selection.volume)
                                            viewModel.customVolume = String(viewModel.useOunces ? Int(viewModel.mlToOz(Double(selection.volume))) : selection.volume)
                                        }
                                        isCustomVolumeFieldFocused = false
                                        onTapSelection.toggle()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: selection.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .frame(width: 45, height: 45)
                                            .background(
                                                Circle()
                                                    .fill(viewModel.selectedVolume == CGFloat(selection.volume) ? Color.blue.opacity(0.5) : Color.gray.opacity(0.15))
                                            )
                                        
                                        Text("\(viewModel.useOunces ? Int(viewModel.mlToOz(Double(selection.volume))) : selection.volume) \(viewModel.useOunces ? "oz" : "ml")")
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    }
                                }.sensoryFeedback(.selection, trigger: onTapSelection)
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(height: gridHeight)
                        .padding(.horizontal, 8)
                    }
                                            
                    // Add button
                    Button(action: {
                        isCustomVolumeFieldFocused = false
                        cameraService.stopCamera()
                        viewModel.addScreen = false
                        viewModel.plusRotation += 45
                        viewModel.contentOffset = viewModel.addScreen ? -geometry.size.height * 0.5 : 0
                        viewModel.fillCircles(
                            count: Int(volume / 1000 * CGFloat(23 * 15)),
                            with: .water,
                            volume: Int(volume)
                        )
                        volume = 0
                        viewModel.customVolume = ""
                        viewModel.selectedVolume = nil
                        dismiss()
                    }) {
                        Text(volume == 0 ? "Input Volume" : viewModel.useOunces ? String(format: "Add %.0f oz", viewModel.mlToOz(Double(volume)))
                            : "Add \(Int(volume)) ml")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                // Add ShimmerView here
                                ZStack {
                                    if volume == 0 {
                                        ShimmerView()// Apply shimmer effect when volume is 0
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                                    }
                                }
                            )
                    }
                    .disabled(volume == 0)
                    .padding(.horizontal, 20)
                    
                }
                .padding(.vertical, 24)
                .background(Color.black)
                .offset(y: viewModel.keyboardOffset * 0.6)
            }
        }
        .onAppear {
            setupBarcodeScanning()
            barcodeController.onBarcodeScanned = { barcode in
                lookupProductInformation(barcode: barcode)
            }
        }
        .onDisappear {
            cameraService.stopCamera()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onTapGesture {
            isCustomVolumeFieldFocused = false
        }
    }
    
    private func setupBarcodeScanning() {
        guard cameraService.isSessionConfigured else { return }
        
        DispatchQueue.main.async {
            cameraService.session.beginConfiguration()
            metadataOutput.setMetadataObjectsDelegate(barcodeController, queue: .main)
            if cameraService.session.canAddOutput(metadataOutput) {
                cameraService.session.addOutput(metadataOutput)
                metadataOutput.metadataObjectTypes = [.ean8, .ean13, .qr, .code128, .code39, .code93, .upce]
            }
            cameraService.session.commitConfiguration()
        }
    }
    
    private func lookupProductInformation(barcode: String) {
        isLoading = true
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
        guard let url = URL(string: urlString) else {
            handleError("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    handleError(error.localizedDescription)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    handleError("No product data received")
                }
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
                guard let product = apiResponse.product else {
                    DispatchQueue.main.async {
                        handleError("No product found")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if let volumeString = product.quantity,
                       let extractedVolume = extractVolume(from: volumeString) {
                        if viewModel.useOunces {
                            let volumeInOz = viewModel.mlToOz(Double(extractedVolume))
                            viewModel.customVolume = String(Int(volumeInOz))
                            volume = CGFloat(extractedVolume)
                        } else {
                            viewModel.customVolume = String(extractedVolume)
                            volume = CGFloat(extractedVolume)
                        }
                        viewModel.isScanning = false
                        cameraService.stopCamera()
                    } else {
                        handleError("Could not determine volume from product")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    handleError("Failed to decode product information")
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                barcodeController.isProcessingBarcode = false
            }
        }.resume()
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        isLoading = false
        barcodeController.isProcessingBarcode = false
        viewModel.isScanning = false
        cameraService.stopCamera()
    }
    private func extractVolume(from volumeString: String) -> Int? {
        let cleanInput = volumeString.lowercased().trimmingCharacters(in: .whitespaces)
        let regex = try? NSRegularExpression(pattern: "([0-9.]+)\\s*(ml|l|cl|oz|fl oz|floz)")
        if let match = regex?.firstMatch(in: cleanInput, range: NSRange(cleanInput.startIndex..., in: cleanInput)) {
            if let numberRange = Range(match.range(at: 1), in: cleanInput),
               let unitRange = Range(match.range(at: 2), in: cleanInput) {
                let numberStr = String(cleanInput[numberRange])
                let unit = String(cleanInput[unitRange])
                if let number = Double(numberStr) {
                    switch unit {
                    case "l": return Int(number * 1000)
                    case "cl": return Int(number * 10)
                    case "oz", "fl oz", "floz": return Int(number * 29.5735)
                    case "ml": return Int(number)
                    default: return nil
                    }
                }
            }
        }
        if let number = Double(cleanInput) {
            return Int(number)
        }
        return nil
    }
}
