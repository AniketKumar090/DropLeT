import Charts
import SwiftUI

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
        if filteredRecords.isEmpty {
            if viewModel.useOunces {
                // Convert the default ml values to oz for empty state
                return (viewModel.mlToOz(100), viewModel.mlToOz(25))
            } else {
                return (100, 25) // Default ml values
            }
        }
        
        let maxQuantity = filteredRecords.map { $0.quantity }.max() ?? 0
        var maxValue = Double(maxQuantity)
        
        if viewModel.useOunces {
            // Convert maxValue to ounces
            maxValue = viewModel.mlToOz(maxValue)
        }
        
        let paddedMax = ceil(maxValue * 1.1)
        let roundedMax = ceil(paddedMax / 4) * 4
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
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color.gray)
                    
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
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
                        y: .value("Quantity", viewModel.useOunces ? viewModel.mlToOz(Double(record.quantity)) : Double(record.quantity))
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
                                     ? String(format: "%.1f oz", doubleValue)
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
                }).sensoryFeedback(.selection, trigger: isShowingAllData)
                .padding(.horizontal)
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
            viewModel.isScanning = false
        }
    }
}
