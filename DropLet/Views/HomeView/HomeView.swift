import SwiftUI

struct Home: View {
    @StateObject var viewModel: DrinkViewModel
    let totalCircles = 23.0 * 15.0
    @State private var volume: CGFloat = 0
    @State private var showCongratulations = false
    @State private var staticColors: [[Color]] = Array(repeating: Array(repeating: Color.randomMetallicGray(), count: 15), count: 24)
    @GestureState private var dragOffset = CGSize.zero
    @StateObject private var notificationManager = NotificationManager()
    @FocusState var isCustomVolumeFieldFocused: Bool
   
    // Track keyboard height
    @State private var keyboardHeight: CGFloat = 0
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
                        ScrollView {
                            VStack(spacing: 18) {
                                ForEach(0..<23) { row in
                                    HStack(spacing: dynamicSpacing) {
                                        ForEach(0..<15, id: \.self) { column in
                                            Circle()
                                                .fill(isCircleColored(row: row, column: column, percentageFilled: viewModel.percentageFilled, totalRows: 23, totalColumns: 15)
                                                ? Color(red: 0.00, green: 0.63, blue: 1.00)
                                                : staticColors[row][column])
                                                .frame(width: 4)
                                        }
                                    }
                                }
                            }
                        }.disabled(true)
                        .frame(height: geometry.size.height * 0.6) // Limit the height of the circle grid
                        
                        // Bottom buttons
                        HStack {
                            Button(action: {
                                viewModel.chartViewEntry.toggle()
                                isCustomVolumeFieldFocused = false
                                viewModel.isScanning = false
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
                               // scannerService.stopScanning()
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
                            }.sensoryFeedback(.success, trigger: viewModel.addScreen)
                            
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
                    .offset(y: viewModel.contentOffset)
                    .offset(y: -keyboardHeight / 8) // Adjust the offset based on keyboard height
                    .animation(.snappy(), value: keyboardHeight)
                    
                    VStack {
                        CongratulationsToast(isVisible: $showCongratulations)
                            .padding(.top, 20)
                        Spacer()
                    }
                    
                    // Bottom Sheet
                    AddView(viewModel: viewModel, volume: $volume, isCustomVolumeFieldFocused: $isCustomVolumeFieldFocused)//, scannerService: scannerService)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.35)
                        .transition(.move(edge: .bottom))
                        .animation(.spring(), value: viewModel.addScreen)
                        .offset(y: viewModel.addScreen ? geometry.size.height * 0.3 : geometry.size.height)
                }
                .overlay {
                    VStack {
                        Color.black.frame(height: 50).ignoresSafeArea()
                        Spacer()
                    }
                }
                
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
}
