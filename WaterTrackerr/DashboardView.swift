import SwiftUI
import Charts
import WidgetKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var dailyGoal: Double
    @Binding var todayProgress: Double
    @Binding var showingAddDrink: Bool
    @State private var startAnimation: CGFloat = 0
    @State private var animateContent = false
    let recentDrinks: [DrinkRecord]
    let onQuickAdd: (Double, DrinkType) -> Void
    
    public var todaysDrinks: [DrinkRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        return recentDrinks
            .filter {
                Calendar.current.isDate($0.timestamp, inSameDayAs: today) &&
                !($0.isQuickAdd ?? false)
            }
            .reversed()
    }
    private func quickAddDrink(_ amount: Double, type: DrinkType) {
            withAnimation(.spring()) {
                onQuickAdd(amount, type) // Use the closure instead of direct manipulation
            }
        }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
              
                    HStack(spacing: 15) {
                        StatCard(
                            title: "Goal",
                            value: "\(Int(dailyGoal))ml",
                            icon: "target",
                            color: .red
                        )
                        
                        StatCard(
                            title: "Progress",
                            value: "\(Int(todayProgress))ml",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    
                    VStack(spacing: 15) {
                        Text("Today's Progress")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ZStack {
                            VStack(spacing: 8) {
                                Text("\(Int((todayProgress/dailyGoal) * 100))%")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundColor(.white)
                                Text("of daily goal")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .zIndex(1)
                            
                            GeometryReader { proxy in
                                let size = proxy.size
                                ZStack {
                                    Image(systemName: "drop.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.indigo.opacity(0.1))
                                        .scaleEffect(x: 1.1, y: 1)
                                    
                                    WaterWave(
                                        progress: CGFloat(todayProgress / dailyGoal),
                                        waveHeight: 0.05,
                                        offset: startAnimation
                                    )
                                    .fill(Color.blue)
                                    .overlay(BubblesOverlay())
                                    .mask {
                                        Image(systemName: "drop.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .padding(.vertical, 15)
                                    }
                                }
                                .frame(width: size.width, height: size.height)
                                .onAppear {
                                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                        startAnimation = size.width
                                    }
                                }
                            }
                        }
                        .frame(height: 220)
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.blue.opacity(0.1))
                    }
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                  
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Quick Add")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 15) {
                            ForEach(displayedQuickAddDrinks, id: \.id) { record in
                                
                                Button(action: {
                                    quickAddDrink(record.amount, type: record.type)
                                }) {
                                    RecentDrink(recentRecords: record)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.indigo.opacity(0.1))
                                }
                            }
                        }
                    }
                    .frame(height: 110)
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    
                
                    Button(action: { showingAddDrink = true }) {
                        Label("Add Drink", systemImage: "plus.circle.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(.indigo)
                            }
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Hydration Tracker")
            .onAppear {
                withAnimation(.spring(response: 0.8)) {
                    animateContent = true
                }
            }
        }
    }
}

extension DashboardView {
    var displayedQuickAddDrinks: [DrinkRecord] {
        let actualDrinks = Array(todaysDrinks.prefix(3))
        
        if actualDrinks.count >= 3 {
            return Array(actualDrinks.prefix(3))
        }
       
        let remainingSlots = 3 - actualDrinks.count
        let sampleDrinks = Array(DefaultDrinks.sampleDrinks.prefix(remainingSlots))
    
        return actualDrinks + sampleDrinks
    }
}

struct RecentDrink: View{
    let recentRecords: DrinkRecord
    var body: some View {
        VStack(alignment: .center){
            Image(systemName: recentRecords.type.icon)
                .font(.title2)
                .foregroundColor(recentRecords.type.color)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.blue.opacity(0.1))
                }
            
            
                Text("\(Int(recentRecords.amount)) ml")
                    .font(.body)
                    .fontWeight(.medium)
                
             
            
        }
    }
}

struct WaterWave: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var offset: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        return Path { path in
            path.move(to: .zero)
            
            let progressHeight: CGFloat = (1 - progress) * rect.height
            let height = waveHeight * rect.height
            
            for value in stride(from: 0, to: rect.width, by: 2) {
                let x: CGFloat = value
                let sine: CGFloat = sin(Angle(degrees: value + offset).radians)
                let y: CGFloat = progressHeight + (height * sine)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.1))
        }
    }
}

struct BubblesOverlay: View {
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: [15, 15, 25, 25, 10, 10][i],
                          height: [15, 15, 25, 25, 10, 10][i])
                    .offset(x: [-20, 40, -30, 50, 40, -40][i],
                           y: [0, 30, 80, 70, 100, 50][i])
            }
        }
    }
}
