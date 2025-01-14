import SwiftUI
import Charts
import WidgetKit
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var dailyGoal: Double
    @Binding var todayProgress: Double
    @Binding var showingAddDrink: Bool
    @State private var startAnimation: CGFloat = 0
    @State private var animateContent = false
    @ObservedObject var vm: ViewModel
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    let totalDuration = 3.0
    
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
            onQuickAdd(amount, type)
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
                            PetView(happinessLevel: vm.pet.happinessLevel, totalDuration: totalDuration)
                            
                            Spacer()
                            HStack {
                                Label("Thirst: \(vm.pet.thirst)", systemImage: "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Label("Status: \(vm.pet.happinessLevel)", systemImage: "")
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
                .onReceive(timer) { _ in
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

struct PetView: View {
    let happinessLevel: String
    let totalDuration: Double
    
    var body: some View {
        ZStack {
            if happinessLevel == "Happy" {
                HappyPetView(duration: totalDuration)
            }
            
            if happinessLevel == "Unhappy" {
                UnhappyPetView(duration: totalDuration)
            }
        }
    }
}

struct HappyPetView: View {
    let duration: Double
    
    var body: some View {
        Image("Happy")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .transition(.scale.combined(with: .opacity))
            .offset(y: 30)
            .keyframeAnimator(
                initialValue: AnimationProperties(),
                repeating: true
            ) { content, value in
                content
                    .scaleEffect(y: value.bounceScale, anchor: .bottom)
                    .offset(x: value.xTranslation, y: value.yTranslation)
                    .scaleEffect(x: value.flipRotation < 0.5 ? 1 : -1, y: 1)
            } keyframes: { _ in
                KeyframeTrack(\.xTranslation) {
                    SpringKeyframe(-8, duration: duration * 0.15, spring: .bouncy)
                    SpringKeyframe(8, duration: duration * 0.15, spring: .bouncy)
                    SpringKeyframe(0, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.5)
                }
                
                KeyframeTrack(\.yTranslation) {
                    SpringKeyframe(-3, duration: duration * 0.15)
                    SpringKeyframe(0, duration: duration * 0.15)
                    SpringKeyframe(-3, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.5)
                }
                
                KeyframeTrack(\.bounceScale) {
                    SpringKeyframe(1.1, duration: duration * 0.15)
                    SpringKeyframe(0.95, duration: duration * 0.15)
                    SpringKeyframe(1.05, duration: duration * 0.2)
                    SpringKeyframe(1.0, duration: duration * 0.5)
                }
                
                KeyframeTrack(\.flipRotation) {
                    LinearKeyframe(0.0, duration: duration * 0.3)
                    LinearKeyframe(1.0, duration: duration * 0.2)
                    LinearKeyframe(0.0, duration: duration * 0.3)
                    LinearKeyframe(1.0, duration: duration * 0.2)
                }
            }
    }
}

struct UnhappyPetView: View {
    let duration: Double
    
    var body: some View {
        Image("Sad")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .transition(.scale.combined(with: .opacity))
            .offset(y: 30)
            .keyframeAnimator(
                initialValue: AnimationProperties(),
                repeating: true
            ) { content, value in
                content
                    .scaleEffect(y: value.verticalStretch, anchor: .bottom)
                    .offset(y: value.yTranslation)
            } keyframes: { _ in
                KeyframeTrack(\.verticalStretch) {
                    SpringKeyframe(0.9, duration: duration * 0.2)
                    SpringKeyframe(1.2, duration: duration * 0.2)
                    SpringKeyframe(0.95, duration: duration * 0.2)
                    SpringKeyframe(1.0, duration: duration * 0.4)
                }
                
                KeyframeTrack(\.yTranslation) {
                    SpringKeyframe(0, duration: duration * 0.2)
                    SpringKeyframe(-25, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.2)
                }
            }
    }
}

struct AnimationProperties {
    var xTranslation = 0.0
    var yTranslation = 0.0
    var verticalStretch = 1.0
    var bounceScale: Double = 1
    var flipRotation = 0.0
}
