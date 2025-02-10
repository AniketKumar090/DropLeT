import SwiftUI
import Charts
import Combine
import Foundation
import UserNotifications
import UserNotificationsUI
import SimpleCameraLibrary


struct DrinkTypeData {
    let type: String
    let amount: Double
}

struct CircleData: Identifiable, Codable, Equatable {
    let id: Int
    var drinkType: DrinkType?
}


struct DrinkRecords: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let drinkType: DrinkType
    let quantity: Int
}


class NotificationManager: ObservableObject {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // This method will schedule notifications
    func scheduleNotifications() {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't Forget to Get Hydrated"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let request = UNNotificationRequest(identifier: "hydration-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notifications: \(error.localizedDescription)")
            } else {
                print("Notification scheduled.")
            }
        }
    }

    // This method will remove all scheduled notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // This method handles toggling notifications on/off
    func toggleNotifications(_ isEnabled: Bool) {
        notificationsEnabled = isEnabled
        
        if isEnabled {
            scheduleNotifications()
        } else {
            removeAllNotifications()
        }
    }
}


@Observable class DrinkViewModel: ObservableObject {
    private let updateQueue = DispatchQueue(label: "com.drink.updates", qos: .userInitiated)
    private let saveQueue = DispatchQueue(label: "com.drink.saveData", qos: .background)

    // MARK: - Properties
    var circles: [CircleData] {
        didSet {
            saveCircles()
        }
    }

    var totalDrinks: Int = 0
    var drinkRecords: [DrinkRecords] = [] {
        didSet {
            saveDrinkRecords()
        }
    }

    var chartViewEntry: Bool = false
    var addScreen: Bool = false

    var goal: Int = 3000 {
        didSet {
            saveGoal()
        }
    }

    var consumed: Int = 0 {
        didSet {
            saveConsumed()
        }
    }

    var percentageFilled: Double {
        guard goal > 0 else { return 0 } // Avoid division by zero
        return (Double(consumed) / Double(goal)) * 100
    }

    var leftGoal: Int {
        let leftInMl = max((goal - consumed), 0)
        return useOunces ? Int(mlToOz(Double(leftInMl))) : leftInMl
    }

    var hasShownCongratulations: Bool = false {
        didSet {
            saveHasShownCongratulations()
        }
    }

    var useOunces: Bool = false {
        didSet {
            saveUseOunces()
        }
    }

    private let queue = DispatchQueue(label: "com.drink.fillCircles", qos: .userInitiated)
    var waveOffset: Double = 0 {
        didSet {
            if waveOffset >= 2 * .pi {
                waveOffset = 0
            }
        }
    }

    var plusRotation: Double = 0
    var contentOffset: CGFloat = 0
    var keyboardOffset: CGFloat = 0
    var customVolume: String = ""
    var selectedVolume: CGFloat? = nil
    private var cancellables = Set<AnyCancellable>()
    var selectedQuickSelections: [QuickSelection] = []
    var isScanning = false
    var displayedText: String = ""

    // MARK: - Initialization
    init() {
        self.circles = Self.loadCircles()
        self.drinkRecords = Self.loadDrinkRecords()
        self.goal = Self.loadGoal()
        self.consumed = Self.loadConsumed()
        self.totalDrinks = self.circles.filter { $0.drinkType != nil }.count
        self.hasShownCongratulations = Self.loadHasShownCongratulations()
        self.useOunces = Self.loadUseOunces()

        setupKeyboardObservers()
        let initialSelections = [
            QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
            QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
            QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
            QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
            QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
            QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
            QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
            QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true)
        ]
        selectedQuickSelections = initialSelections
    }

    // MARK: - Persistence Methods
    private func saveCircles() {
        saveQueue.async {
            if let encoded = try? JSONEncoder().encode(self.circles) {
                UserDefaults.standard.set(encoded, forKey: "circles")
            }
        }
    }

    private static func loadCircles() -> [CircleData] {
        if let data = UserDefaults.standard.data(forKey: "circles"),
           let decoded = try? JSONDecoder().decode([CircleData].self, from: data) {
            return decoded
        }
        return Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
    }

    private func saveDrinkRecords() {
        saveQueue.async {
            if let encoded = try? JSONEncoder().encode(self.drinkRecords) {
                UserDefaults.standard.set(encoded, forKey: "drinkRecords")
            }
        }
    }

    private static func loadDrinkRecords() -> [DrinkRecords] {
        if let data = UserDefaults.standard.data(forKey: "drinkRecords"),
           let decoded = try? JSONDecoder().decode([DrinkRecords].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveGoal() {
        saveQueue.async {
            UserDefaults.standard.set(self.goal, forKey: "goal")
        }
    }

    private static func loadGoal() -> Int {
        return UserDefaults.standard.integer(forKey: "goal")
    }

    private func saveConsumed() {
        saveQueue.async {
            UserDefaults.standard.set(self.consumed, forKey: "consumed")
        }
    }

    private static func loadConsumed() -> Int {
        return UserDefaults.standard.integer(forKey: "consumed")
    }

    private func saveHasShownCongratulations() {
        saveQueue.async {
            UserDefaults.standard.set(self.hasShownCongratulations, forKey: "hasShownCongratulations")
        }
    }

    private static func loadHasShownCongratulations() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasShownCongratulations")
    }

    private func saveUseOunces() {
        saveQueue.async {
            UserDefaults.standard.set(self.useOunces, forKey: "useOunces")
        }
    }

    private static func loadUseOunces() -> Bool {
        return UserDefaults.standard.bool(forKey: "useOunces")
    }

    // MARK: - Helper Methods
    func mlToOz(_ ml: Double) -> Double {
        return ml * 0.033814
    }

    func ozToMl(_ oz: Double) -> Double {
        return oz / 0.033814
    }

    func fillCircles(count: Int, with drinkType: DrinkType, volume: Int) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            var updatedCircles = self.circles
            var newTotalDrinks = self.totalDrinks
            let newConsumed = self.consumed + volume

            if let firstEmptyIndex = updatedCircles.lastIndex(where: { $0.drinkType == nil }) {
                for i in 0..<min(count, updatedCircles.count - firstEmptyIndex) {
                    let index = firstEmptyIndex + i
                    updatedCircles[index].drinkType = drinkType
                    newTotalDrinks += 1
                }
            }

            let record = DrinkRecords(
                id: UUID(),
                timestamp: Date(),
                drinkType: drinkType,
                quantity: volume
            )

            DispatchQueue.main.async {
                self.circles = updatedCircles
                self.totalDrinks = newTotalDrinks
                self.consumed = newConsumed
                self.drinkRecords.append(record)
            }
        }
    }

    func reset() {
        drinkRecords = []
        circles = Array(0..<(23 * 15)).map { CircleData(id: $0, drinkType: nil) }
        totalDrinks = 0
        goal = 3000
        consumed = 0
        hasShownCongratulations = false
        useOunces = false

        UserDefaults.standard.removeObject(forKey: "hasShownCongratulations")
        saveDrinkRecords()
        saveCircles()
        saveGoal()
        saveConsumed()
        saveUseOunces()

        selectedQuickSelections = [
            QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
            QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
            QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
            QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
            QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
            QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
            QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
            QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true)
        ]
    }

    // MARK: - Keyboard Observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.keyboardWillShow(notification: notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.keyboardWillHide(notification: notification)
            }
            .store(in: &cancellables)
    }

    private func removeKeyboardObservers() {
        cancellables.forEach { $0.cancel() }
    }

    private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height

        withAnimation(.spring()) {
            self.keyboardOffset = -keyboardHeight / 2
        }
    }

    private func keyboardWillHide(notification: Notification) {
        withAnimation(.spring()) {
            self.keyboardOffset = 0
        }
    }

    deinit {
        removeKeyboardObservers()
    }
}
class ProductStore: ObservableObject {
    @Published var scannedProducts: [ProductInfo] = []
    
    func addProduct(_ product: ProductInfo) {
        scannedProducts.append(product)
    }
}

struct CongratulationsToast: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            if isVisible {
                Text("🎉 Goal Completed !!!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                    .cornerRadius(25)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            withAnimation {
                                isVisible = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(), value: isVisible)
    }
}

struct Home: View {
    @StateObject var viewModel: DrinkViewModel
    let totalCircles = 23.0 * 15.0
    @State private var volume: CGFloat = 0
    @State private var showCongratulations = false
    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 15), count: 24)
    @GestureState private var dragOffset = CGSize.zero
    @StateObject private var notificationManager = NotificationManager()
    @FocusState var isCustomVolumeFieldFocused: Bool
    @StateObject private var scannerService = ProductScannerService()
    
    
    func isCircleColored(row: Int, column: Int, percentageFilled: Double, totalRows: Int, totalColumns: Int) -> Bool {
        let totalCircles = totalRows * totalColumns
        let circlesToFill = Int(Double(totalCircles) * (percentageFilled / 100))
        
        // Convert the 2D grid position (row, column) into a 1D index, starting from the bottom
        let reversedRow = totalRows - row - 1 // Reverse the row index
        let index = reversedRow * totalColumns + column
        
        return index < circlesToFill
    }
    
   var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let circleCountPerRow: CGFloat = 15
                let totalPadding: CGFloat = 64
                let availableWidth = screenWidth - totalPadding
                let dynamicSpacing = availableWidth / circleCountPerRow - 4
                ZStack {
                    Color.black.ignoresSafeArea()
                       
                    VStack {
                        Spacer()
                       // Percentage and remaining amount
                        HStack(alignment: .lastTextBaseline) {
                            Text("\(Int(viewModel.percentageFilled))%")
                                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.leading, 32)
                            Spacer()
                            Text("\(viewModel.leftGoal)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)

                            Text(viewModel.useOunces ? "oz left" : "ml left")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.trailing, 32)
                        }
                        .padding(.bottom, 42)
                        // Circle grid with simplified coloring
                        LazyVStack(spacing: 18) {
                            ForEach(0..<23) { row in
                                LazyHStack(spacing: dynamicSpacing) {
                                    ForEach(0..<15, id: \.self) { column in
                                        //  let index = row * 15 + column
                                        Circle()
                                            .fill(isCircleColored(row: row, column: column, percentageFilled: viewModel.percentageFilled, totalRows: 23, totalColumns: 15)
                                                                ? Color(red: 0.00, green: 0.63, blue: 1.00)
                                                                : staticColors[row][column])
                                            .frame(width: 4)
                                    }
                                }
                            }
                        }
                        // Bottom buttons
                        HStack {
                            Button(action: {
                                viewModel.chartViewEntry.toggle()
                            }) {
                                Image(systemName: "drop.fill")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Circle().fill(Color.white.opacity(0.07)))
                            }
                            .padding(.trailing, 40)
                            .padding(.leading, 20)
                            
                            Button(action: {
                                isCustomVolumeFieldFocused = false
                                viewModel.isScanning = false
                                scannerService.stopScanning()
                                withAnimation(.spring()) {
                                    viewModel.addScreen.toggle()
                                    viewModel.plusRotation += 45
                                    viewModel.contentOffset = viewModel.addScreen ? -geometry.size.height * 0.4 : 0
                                    volume = 0
                                    viewModel.customVolume = ""
                                    viewModel.selectedVolume = nil
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 24.5)
                                        .fill(viewModel.addScreen ? Color.white : Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                                        .frame(width: 138, height: 52)
                                    
                                    Image(systemName: "plus")
                                        .bold()
                                        .foregroundColor(viewModel.addScreen ? .black : .white)
                                        .frame(width: 50, height: 20)
                                        .rotationEffect(.degrees(viewModel.plusRotation))
                                }
                            }
                            
                            NavigationLink(destination: ChartView(viewModel: viewModel, percentageFilled: viewModel.percentageFilled)
                                .transition(.move(edge: .trailing))
                                .animation(.easeInOut(duration: 0.3), value: true)
                                .navigationBarBackButtonHidden(true)) {
                                    Image("Tabview")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Circle().fill(Color.white.opacity(0.07)))
                                        .shadow(color: .black, radius: 8)
                                }
                                .padding(.trailing, 20)
                                .padding(.leading, 40)
                        }
                        .padding(.top, 48)
                    }
                    .offset(y: viewModel.contentOffset + viewModel.keyboardOffset * 1.4)
                    .animation(.spring(), value: viewModel.contentOffset)
                     VStack {
                        CongratulationsToast(isVisible: $showCongratulations)
                            .padding(.top, 20)
                        Spacer()
                    }
                  
                    // Bottom Sheet
                    AddView(viewModel: viewModel, volume: $volume, isCustomVolumeFieldFocused: $isCustomVolumeFieldFocused, scannerService: scannerService)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.35)
                        .transition(.move(edge: .bottom))
                        .animation(.spring(), value: viewModel.addScreen)
                        .offset(y: viewModel.addScreen ? geometry.size.height * 0.3 : geometry.size.height)
                       
                }.overlay{VStack{
                    Color.black.frame(height:50).ignoresSafeArea()
                    Spacer()}}
                SettingView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.chartViewEntry)
                    .offset(x: viewModel.chartViewEntry ? 0 : -UIScreen.main.bounds.width)
                    .frame(width: UIScreen.main.bounds.width)
            }
        }
       
        .onChange(of: viewModel.percentageFilled) { newValue in
            if newValue >= 100 && !viewModel.hasShownCongratulations {
                withAnimation {
                    showCongratulations = true
                    viewModel.hasShownCongratulations = true
                }
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error {
                    print(error.localizedDescription)
                }
            }
            
            if viewModel.goal > 0 {
                notificationManager.scheduleNotifications()
            }
        }
        .accentColor(.gray)
        .onChange(of: viewModel.goal) { newValue in
            if newValue <= 0 {
                notificationManager.removeAllNotifications()
            } else {
                notificationManager.scheduleNotifications()
            }
        }
       
    }
}

struct AddView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @Binding var volume: CGFloat
    @FocusState.Binding var isCustomVolumeFieldFocused: Bool
    @ObservedObject var scannerService: ProductScannerService
    private let gridHeight: CGFloat = 140
    
    private func convertToMilliliters(_ input: String) -> Int? {
        let cleanInput = input.lowercased().trimmingCharacters(in: .whitespaces)
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
    
    private func extractVolume(from volumeString: String) -> Int? {
        if let convertedVolume = convertToMilliliters(volumeString) {
            return convertedVolume
        }
        let numericString = volumeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numericString)
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 24) {
                    // Custom Volume Input
                    HStack(spacing: 16) {
                        ZStack {
                            TextField(viewModel.useOunces ? "Custom Volume (oz)" : "Custom Volume (ml)", text: $viewModel.customVolume)
                                .keyboardType(.numberPad)
                                .focused($isCustomVolumeFieldFocused)
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .onChange(of: viewModel.customVolume) { newValue in
                                        if let convertedVolume = viewModel.useOunces
                                            ? viewModel.ozToMl(Double(newValue) ?? 0)
                                            : Double(newValue) {
                                            volume = CGFloat(convertedVolume)
                                        }
                                    }
                        }
                        .overlay {
                            HStack {
                                Spacer()
                                Button(action: {
                                    isCustomVolumeFieldFocused = false
                                    viewModel.isScanning.toggle()
                                    if viewModel.isScanning {
                                        scannerService.startScanning()
                                    } else {
                                        scannerService.stopScanning()
                                    }
                                }, label: {
                                    Image(systemName: viewModel.isScanning ? "xmark" : "barcode.viewfinder")
                                        .foregroundColor(.white)
                                        .background(RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.25))
                                            .frame(width: 30, height: 30))
                                        .padding(.trailing, 20)
                                })
                            }
                        }
                    }.padding(.horizontal, 8)
                    
                    if viewModel.isScanning {
                        BarcodeScannerPreviewView(scannerService: scannerService)
                            .frame(height: gridHeight)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.6),
                                        Color.blue.opacity(0.2),
                                        Color.blue.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .mask(
                                RoundedRectangle(cornerRadius: 12)
                                    .padding(.horizontal, 8)
                            )
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 0) {
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
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(height: gridHeight)
                        .padding(.horizontal, 8)
                    }
                    
                    Button(action: {
                        isCustomVolumeFieldFocused = false
                        scannerService.stopScanning()
                        viewModel.addScreen = false
                        viewModel.plusRotation += 45
                        viewModel.contentOffset = viewModel.addScreen ? -geometry.size.height * 0.4 : 0
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
                        Text(volume == 0 ? "Enter Volume" : viewModel.useOunces ? String(format: "Add %.0f oz", viewModel.mlToOz(Double(volume)))
                             : "Add \(Int(volume)) ml")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(volume == 0 ? Color.gray.opacity(0.5) : Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5))
                            )
                    }
                    .disabled(volume == 0)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 24)
                .background(Color.black)
                .offset(y: viewModel.keyboardOffset * 1.15)
            }
        }
        .onAppear {
            scannerService.metadataOutput.setMetadataObjectsDelegate(scannerService, queue: DispatchQueue.main)
        }
        .onChange(of: scannerService.productInfo) { product in
            if let product = product {
                if let volumeInt = extractVolume(from: product.volume) {
                    print(volumeInt)
                    viewModel.customVolume = String(volumeInt)
                    volume = CGFloat(volumeInt)
                    viewModel.isScanning = false
                    scannerService.stopScanning()
                }
            }
        }
        .onTapGesture {
            isCustomVolumeFieldFocused = false
        }
    }
}
struct QuickSelection: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let volume: Int
    var isSelected: Bool
}

struct SettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: DrinkViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("wavesEnabled") private var waveMotion = true
    @State private var temporaryGoal: String = ""
    @State private var showInvalidGoalAlert = false
    @State private var showConfirmationAlert = false
    @FocusState private var isGoalFieldFocused: Bool
    var showCongratulations: Bool { viewModel.percentageFilled >= 100 }
    @State private var showAlert = false
    @State private var alertMessage = ""
    // Create an instance of NotificationManager
    @StateObject private var notificationManager = NotificationManager()
    @State private var quickSelections: [QuickSelection] = [
            QuickSelection(icon: "wineglass.fill", label: "Half Glass", volume: 150, isSelected: true),
            QuickSelection(icon: "cup.and.saucer.fill", label: "Cup", volume: 200, isSelected: true),
            QuickSelection(icon: "bubbles.and.sparkles.fill", label: "Glass", volume: 250, isSelected: true),
            QuickSelection(icon: "waterbottle.fill", label: "Bottle", volume: 500, isSelected: true),
            QuickSelection(icon: "drop.fill", label: "Small Sip", volume: 50, isSelected: true),
            QuickSelection(icon: "drop.triangle.fill", label: "Medium Sip", volume: 100, isSelected: true),
            QuickSelection(icon: "drop.circle.fill", label: "Large Sip", volume: 350, isSelected: true),
            QuickSelection(icon: "flame.fill", label: "Shot", volume: 30, isSelected: true),
            // Set remaining items as not selected by default
            QuickSelection(icon: "mug.fill", label: "Mug", volume: 400, isSelected: false),
            QuickSelection(icon: "thermometer.snowflake", label: "Cold Drink", volume: 200, isSelected: false),
            QuickSelection(icon: "thermometer.sun.fill", label: "Hot Drink", volume: 250, isSelected: false),
            QuickSelection(icon: "staroflife.fill", label: "Energy Drink", volume: 300, isSelected: false),
            QuickSelection(icon: "leaf.fill", label: "Herbal Tea", volume: 200, isSelected: false),
            QuickSelection(icon: "cloud.fill", label: "Smoothie", volume: 350, isSelected: false),
            QuickSelection(icon: "drop.circle.fill", label: "Juice", volume: 250, isSelected: false),
            QuickSelection(icon: "fork.knife", label: "Soup", volume: 300, isSelected: false),
            QuickSelection(icon: "snowflake", label: "Ice Water", volume: 150, isSelected: false),
            QuickSelection(icon: "sun.max.fill", label: "Lemonade", volume: 200, isSelected: false),
            QuickSelection(icon: "moon.fill", label: "Nightcap", volume: 50, isSelected: false),
            QuickSelection(icon: "heart.fill", label: "Health Drink", volume: 100, isSelected: false)
        ]

        // Add this function to handle selection changes
    private func handleSelectionChange(for selection: QuickSelection) {
        let currentlySelected = quickSelections.filter { $0.isSelected }.count
        
        if !selection.isSelected && currentlySelected >= 8 {
            alertMessage = "You can only select up to 8 items. Please deselect an item before selecting a new one."
            showAlert = true
            return
        }
        
        if let index = quickSelections.firstIndex(where: { $0.id == selection.id }) {
            quickSelections[index].isSelected.toggle()
        }
    }
    

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .lastTextBaseline) {
                Text("Settings")
                    .font(.system(size: 35,weight: .semibold,design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.leading)
                Spacer()
                Button(action: {
                    viewModel.chartViewEntry = false
                    isGoalFieldFocused = false
                }) {
                    Image(systemName: "x.circle.fill")
                        .font(.title2)
              }.padding(.trailing)
                    .padding(.bottom, 20)
                    .foregroundColor(Color(.systemGray))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily Goal")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))

                HStack {
                    TextField(viewModel.useOunces ? "Enter your goal in oz" : "Enter your goal in ml", text: $temporaryGoal)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .keyboardType(.numberPad)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                        .focused($isGoalFieldFocused)
                    Button("Set") {
                        if let newGoal = Int(temporaryGoal), newGoal > 0 {
                            viewModel.goal = viewModel.useOunces ? Int(viewModel.ozToMl(Double(newGoal))) : newGoal
                            temporaryGoal = ""
                            isGoalFieldFocused = false
                            dismiss()
                            withAnimation(.easeInOut(duration: 1.5)) {
                                viewModel.chartViewEntry = false
                            }
                        } else {
                            showInvalidGoalAlert = true
                        }
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(10)
                }
                .alert("Invalid Goal", isPresented: $showInvalidGoalAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please enter a valid number greater than 0")
                }

                Text("Current goal: \(viewModel.useOunces ? Int(viewModel.mlToOz(Double(viewModel.goal))) : viewModel.goal) \(viewModel.useOunces ? "oz" : "ml")")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .padding()
            .background(Color.white.opacity(0.1).onTapGesture {
                isGoalFieldFocused = false
            })
            .cornerRadius(15)
            .padding(.horizontal)
            
            
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                        Text("Notifications")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5)))
                .onChange(of: notificationsEnabled) { newValue in
                    // Use the NotificationManager to toggle notifications
                    notificationManager.toggleNotifications(newValue)
                }

               
                Toggle(isOn: $viewModel.useOunces) {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                        Text("Ounce")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.00, green: 0.63, blue: 1.00).opacity(0.5)))
                .onChange(of: viewModel.useOunces) { newValue in
                    // Optionally trigger updates when the unit changes
                }
            }
            .padding()
            .background(Color.white.opacity(0.1).onTapGesture {
                isGoalFieldFocused = false
            })
            .cornerRadius(15)
            .padding(.horizontal)
            
           
            // Quick Selections Section
            VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quick Selections")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Spacer()
                        Button(action: {
                            let selectedCount = quickSelections.filter { $0.isSelected }.count
                            if selectedCount != 8 {
                                alertMessage = "You must select exactly 8 items to save."
                                showAlert = true
                            } else {
                                viewModel.selectedQuickSelections = quickSelections.filter { $0.isSelected }
                                viewModel.chartViewEntry = false 
                                dismiss() // Dismiss the settings view after saving
                            }
                          
                        }) {
                            Text("Save")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(10)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: Array(repeating: GridItem(.flexible()), count: 2), alignment: .center, spacing: 12) {
                            ForEach($quickSelections) { $selection in
                                Button(action: {
                                    handleSelectionChange(for: selection)
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: selection.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selection.isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.15))
                                            )
                                        Text(selection.label)
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                }
                .padding()
                .background(Color.white.opacity(0.1).onTapGesture {
                    isGoalFieldFocused = false
                })
                .cornerRadius(15)
                .padding(.horizontal)
                .alert(alertMessage, isPresented: $showAlert) {
                    Button("OK", role: .cancel) {  }
                }

                       
            Spacer()
            
            if showCongratulations {
                VStack(alignment: .center) {
                    Text("🎉 Congratulations!")
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("You have completed your Goal")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding()
                .frame(width: UIScreen.main.bounds.width)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: showCongratulations)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.hasShownCongratulations = true
                    }
                }
            }

            Button(action: {
                showConfirmationAlert = true
            }) {
                Text("Reset all Data")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
            .alert("Are you Sure?", isPresented: $showConfirmationAlert) {
                Button("OK", role: .cancel) {
                    viewModel.chartViewEntry = false
                    viewModel.reset()
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.black
            .onTapGesture {
                isGoalFieldFocused = false
            })
    }
}


extension LinearGradient {
    static func gradientBackground() -> LinearGradient {
        return LinearGradient(gradient: Gradient(colors: [Color.black, Color.black]), startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    static func randomMetallicGray() -> Color {
        let baseGray = 0.5 + .random(in: -0.1...0.1)
        let variation = 0.1 + .random(in: -0.05...0.05)

        return .init(
            red: baseGray + variation,
            green: baseGray + variation,
            blue: baseGray + variation
        )
    }
    static func randomBlue() -> Color{
        return Color(hue: 0.583 + .random(in: -0.1...0.1) , saturation: 0.85, brightness: 0.68)
    }
    static func randomTea() -> Color{
        return Color(hue: 0.333 + .random(in: -0.1...0.1), saturation: 0.8 + .random(in: -0.1...0.1), brightness: 0.7 + .random(in: -0.1...0.1))
    }
    static func randomCoffee() -> Color{
        return Color(hue: 0.083 + .random(in: -0.1...0.1), saturation: 0.7 + .random(in: -0.1...0.1), brightness: 0.6 + .random(in: -0.1...0.1))
    }
    static func randomSoda() -> Color{
        return Color(hue: 0.95 + .random(in: -0.1...0.1), saturation: 0.75 + .random(in: -0.1...0.1), brightness: 0.9 + .random(in: -0.1...0.1))
    }
    func adjustHue(by offset: CGFloat) -> Color {
        var h: CGFloat = 0.0
        var s: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        let uiColor = UIColor(self)
        let success = uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        
        if success {
            let adjustedHue = (h + offset).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: adjustedHue, saturation: Double(s), brightness: Double(b))
        } else {
            return self
        }
    }
}
extension String {
    func extractNumericValue() -> Double? {
        let numbers = self.components(separatedBy: CharacterSet.letters.union(CharacterSet.whitespaces))
            .joined()
            .replacingOccurrences(of: ",", with: ".")
        return Double(numbers)
    }
}

enum DrinkType: String, CaseIterable, Codable {
    case water, tea, coffee, soda

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .tea: return "leaf.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .soda: return "bubbles.and.sparkles"
        }
    }

    var color: Color {
        switch self {
        case .water: return Color.blue
        case .tea: return Color.green
        case .coffee: return Color.orange
        case .soda: return Color.pink
        }
    }
    func colorHighlight() -> Color {
        switch self {
        case .water: return Color.randomBlue()
        case .tea: return Color.randomTea()
        case .coffee: return Color.randomCoffee()
        case .soda: return Color.randomSoda()
        }
    }

}

struct CustomSegmentedControl: View {
    @Binding var preselectedIndex: Int
    var options: [String]
    // this color is coming theme library
    let color = Color.gray

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id:\.self) { index in
                ZStack {
                    Rectangle()
                        .fill(color.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .cornerRadius(20)
                        .padding(2)
                        .opacity(preselectedIndex == index ? 0.2 : 0.01)
                        .onTapGesture {
                                withAnimation(.interactiveSpring()) {
                                    preselectedIndex = index
                                }
                            }
                }
                .overlay(
                    Text(options[index])
                        .font(.system(size: 16,weight: .regular,design: .monospaced))
                )
            }
        }
        .frame(height: 40)
        .cornerRadius(20)
    }
}

struct ChartView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DrinkViewModel
    var percentageFilled: Double
    @State private var selectedTimeframeIndex: Int = 0
    @State private var isShowingAllData: Bool = false
    @State private var responseText: String = ""
    @State private var fullResponse: String = ""
    @State private var typingIndex: Int = 0
    
    let responses: [String] = [
        "Drinking water helps maintain hydration, which is essential for overall health. It also supports digestion and improves skin health.",
        "Water supports digestion by helping break down food and absorb nutrients. Staying hydrated also boosts energy levels and prevents fatigue.",
        "Staying hydrated improves skin health, making it look more radiant and youthful. It also helps regulate body temperature during exercise.",
        "Water boosts energy levels by preventing dehydration, which can cause fatigue. It also aids in weight loss by increasing satiety.",
        "Drinking water aids in weight loss by increasing satiety and reducing calorie intake. It also helps flush out toxins from the body.",
        "Water helps flush out toxins from the body through urine and sweat. Proper hydration also improves cognitive function and concentration.",
        "Proper hydration improves cognitive function and concentration. It also lubricates joints, reducing the risk of joint pain and arthritis.",
        "Water lubricates joints, reducing the risk of joint pain and arthritis. It also regulates body temperature, especially during exercise.",
        "Drinking water regulates body temperature, especially during exercise. It also prevents headaches and migraines caused by dehydration.",
        "Water prevents headaches and migraines, which are often caused by dehydration. Staying hydrated also improves physical performance.",
        "Staying hydrated improves physical performance during workouts. It also supports kidney function by helping filter waste from the blood.",
        "Water supports kidney function by helping filter waste from the blood. Drinking water can also improve mood and reduce stress levels.",
        "Drinking water can improve mood and reduce stress levels. It also helps maintain blood pressure by keeping blood volume stable.",
        "Water helps maintain blood pressure by keeping blood volume stable. Hydration is crucial for maintaining electrolyte balance in the body.",
        "Hydration is crucial for maintaining electrolyte balance in the body. Water also reduces the risk of urinary tract infections.",
        "Water reduces the risk of urinary tract infections by flushing out bacteria. It can also prevent constipation by keeping the digestive system active.",
        "Drinking water can prevent constipation by keeping the digestive system active. It also helps transport nutrients and oxygen to cells.",
        "Water helps transport nutrients and oxygen to cells throughout the body. Staying hydrated can also reduce the risk of kidney stones.",
        "Staying hydrated can reduce the risk of kidney stones. Water also improves circulation, ensuring organs receive adequate oxygen.",
        "Water improves circulation, ensuring organs receive adequate oxygen. Drinking water can also help reduce acne and improve skin clarity.",
        "Drinking water can help reduce acne and improve skin clarity. It also supports the immune system by keeping mucous membranes moist.",
        "Water supports the immune system by keeping mucous membranes moist. Hydration can also reduce the risk of muscle cramps and spasms.",
        "Hydration can reduce the risk of muscle cramps and spasms. Water also helps maintain a healthy metabolism, aiding in weight management.",
        "Water helps maintain a healthy metabolism, aiding in weight management. It also improves skin elasticity and reduces signs of aging."
    ]
    
    enum Timeframe: String, CaseIterable {
        case hour = "Hourly"
        case daily = "Daily"
        case week = "Weekly"
    }

    private var selectedTimeframe: Timeframe {
        Timeframe.allCases[selectedTimeframeIndex]
    }

    private var filteredRecords: [DrinkRecords] {
        let now = Date()
        switch selectedTimeframe {
        case .hour:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 3600
            }
        case .daily:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 86400
            }
        case .week:
            return viewModel.drinkRecords.filter {
                now.timeIntervalSince($0.timestamp) <= 604800
            }
        }
    }

    private var xAxisDomain: ClosedRange<Date> {
        let now = Date()
        switch selectedTimeframe {
        case .hour:
            return now.addingTimeInterval(-3600)...now.addingTimeInterval(120)
        case .daily:
            return now.addingTimeInterval(-86400)...now.addingTimeInterval(4600)
        case .week:
            return now.addingTimeInterval(-604800)...now.addingTimeInterval(22500)
        }
    }
    
    // Simplified askAI function
    private func askAI() {
        // Randomly select a response
        fullResponse = responses.randomElement() ?? "No response available."
        
        // Start the typing effect
        startTypingEffect()
    }
    
    private func startTypingEffect() {
        typingIndex = 0
        viewModel.displayedText = ""
        
        // Create a timer to simulate typing
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if typingIndex < fullResponse.count {
                viewModel.displayedText += String(fullResponse[fullResponse.index(fullResponse.startIndex, offsetBy: typingIndex)])
                typingIndex += 1
            } else {
                timer.invalidate() // Stop the timer when typing is complete
            }
        }
    }
    private var yAxisConfig: (max: Double, stride: Double) {
        // Find the maximum value in the filtered records
        let maxQuantity = filteredRecords.map { $0.quantity }.max() ?? 0
        let maxValue =  Double(maxQuantity)
        
        // Add 10% padding to the max value
        let paddedMax = ceil(maxValue * 1.1)
        
        // Round up to a number that's cleanly divisible by 4
        let roundedMax = ceil(paddedMax / 4) * 4
        
        // Calculate the stride (distance between marks)
        let stride = roundedMax / 4
        
        return (roundedMax, stride)
    }

    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.smooth(duration: 2.3)) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectedTimeframeIndex = 0 // Reset to hourly view
                            }
                            dismiss()
                        }
                    }, label: {
                        Image(systemName: "arrowtriangle.left.circle.fill")
                            .font(.title2)
                    })
                    .padding(.leading)
                    .padding(.bottom, 20)
                    .foregroundColor(Color(.systemGray))
                    
                    Spacer()
                }
                HStack {
                    Text("Drink Insights Trends")
                        .font(.system(size: 22,weight: .semibold,design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.leading)
                    Spacer()
                }
                
                Chart(filteredRecords) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", record.quantity)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.gray)

                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", record.quantity)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.7),
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", record.quantity)
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color.white)
                }
                .chartXAxis {
                    switch selectedTimeframe {
                    case .hour:
                        AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                            AxisValueLabel(format: .dateTime.hour().minute(), anchor: .top)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.gray)
                        }
                    case .daily:
                        AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                            AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                                .font(.system(size: 14, weight: .thin, design: .monospaced))
                                .foregroundStyle(Color.gray)
                        }
                    case .week:
                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                            AxisValueLabel {
                                Text(value.as(Date.self)?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                            }
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.gray)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: yAxisConfig.stride)) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(viewModel.useOunces
                                     ? String(format: "%.1f oz", viewModel.mlToOz(doubleValue))
                                     : "\(Int(doubleValue)) ml")
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color.gray)
                            }
                        }
                        
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
                .padding(.leading)
                .chartXScale(domain: xAxisDomain)
                .chartScrollPosition(x: .constant(Date()))
                .chartScrollableAxes(.horizontal)
                .chartYScale(domain: 0...yAxisConfig.max)
                .frame(width: UIScreen.main.bounds.width, height: 350)
                .padding(.bottom, 25)
                
                CustomSegmentedControl(
                    preselectedIndex: $selectedTimeframeIndex,
                    options: Timeframe.allCases.map { $0.rawValue }
                )
                .foregroundColor(.white)
                .padding(.horizontal,40)
                .padding(.bottom, 30)
                
                Button(action: {
                    isShowingAllData = true
                }, label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24.5)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height:50)
                        
                        HStack{
                            Image(systemName: "widget.large")
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.gray.opacity(0.2)))
                            Text("Show All Data")
                                .font(.system(size: 16,weight: .regular,design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrowtriangle.right.circle.fill")
                                .font(.title2)
                        }.padding(.horizontal)
                    }
                }).padding(.horizontal)
                    .fullScreenCover(isPresented: $isShowingAllData, content: {
                        DrinkLogSheet(viewModel: viewModel)
                    })
                
                Text(viewModel.displayedText)
                    .font(.system(size: 16,weight: .semibold,design: .monospaced))
                    .padding(.top,30)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .ignoresSafeArea()
                    .lineLimit(nil)
                Spacer()
            }
        }
        .onAppear {
            askAI() // Call the simplified askAI function
        }
    }
}
struct DrinkLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DrinkViewModel
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleRecords = Set<UUID>() // Track individual records instead of dates
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yy, h:mm a"
        return formatter.string(from: date)
    }
    
    private var groupedRecords: [(String, [DrinkRecords])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.drinkRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        return grouped.map { (date, records) in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return (dateFormatter.string(from: date), records.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.0 > $1.0 }
    }
    
    private func findQuickSelection(for volume: Int) -> QuickSelection? {
        return viewModel.selectedQuickSelections.first { $0.volume == volume }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Drink Log")
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                    .padding()
                    
                    if viewModel.drinkRecords.isEmpty {
                        VStack(alignment: .center, spacing: 16) {
                            Spacer()
                            Image("Droplet")
                                .resizable()
                                .opacity(0.5)
                                .frame(width: 45, height: 50)
                                .transition(.scale.combined(with: .opacity))
                            Text("No drinks logged yet")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(groupedRecords, id: \.0) { date, records in
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(records) { record in
                                            HStack {
                                                if let quickSelection = findQuickSelection(for: record.quantity) {
                                                    Image(systemName: quickSelection.icon)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .frame(width: 40, height: 40)
                                                } else {
                                                    Image(systemName: record.drinkType.icon)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .frame(width: 40, height: 40)
                                                }
                                                
                                                HStack(alignment: .lastTextBaseline) {
                                                    Text(viewModel.useOunces ? String(format: "%.1f", viewModel.mlToOz(Double(record.quantity))) : "\(record.quantity)")
                                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(.white)

                                                    Text(viewModel.useOunces ? "oz" : "ml")
                                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                        .foregroundColor(.white)

                                                    Spacer()
                                                    Text(formatDate(record.timestamp))
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                            .scaleEffect(visibleRecords.contains(record.id) ? 1.0 : 0.8)
                                            .opacity(visibleRecords.contains(record.id) ? 1.0 : 0.5)
                                            .onScrollVisibilityChange { isVisible in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if isVisible {
                                                        visibleRecords.insert(record.id)
                                                    } else {
                                                        visibleRecords.remove(record.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .animation(.bouncy, value: visibleRecords)
                        .scrollTargetLayout()
                        .onScrollTargetVisibilityChange(idType: UUID.self, threshold: 0.3) { records in
                            visibleRecords = Set(records)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
    }
}
#Preview{
    Home(viewModel: DrinkViewModel())
}
