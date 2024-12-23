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
    @ObservedObject var vm: ViewModel
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
        
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
            vm.giveWater()
            onQuickAdd(amount, type) // Use the closure instead of direct manipulation
        }
    }
    var body: some View {
        NavigationView {
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
//                            VStack(spacing: 8) {
//                                Text("\(Int((todayProgress/dailyGoal) * 100))%")
//                                    .font(.system(size: 42, weight: .bold))
//                                    .foregroundColor(.white)
//                                Text("of daily goal")
//                                    .font(.subheadline)
//                                    .foregroundColor(.white.opacity(0.8))
//                            }
//                            .zIndex(1)
                            
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
                                    WaterWave(
                                        progress: CGFloat(todayProgress / dailyGoal),
                                        waveHeight: 0.01,
                                        offset: startAnimation
                                    )
                                    .fill(Color.blue.opacity(0.5))
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
                            VStack {
                                Spacer()
                                Image(vm.pet.happinessLevel == "Happy" ? "Happy" : "Sad")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .transition(.scale.combined(with: .opacity))
                                    .offset(y:20)
                                Spacer()
                                HStack {
                                    Label("Thirst: \(vm.pet.thirst)",systemImage: "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Label("Status: \(vm.pet.happinessLevel)",systemImage: "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 210)
                        
                       
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
                    .frame(height: 100)
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    .onReceive(timer){_ in
                        vm.saveData()
                    }

                
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

