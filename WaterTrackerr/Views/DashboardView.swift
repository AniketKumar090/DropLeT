import SwiftUI
import Charts
import WidgetKit
import UIKit

//struct DashboardView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Binding var dailyGoal: Double
//    @Binding var todayProgress: Double
//    @Binding var showingAddDrink: Bool
//    @State private var startAnimation: CGFloat = 0
//    @State private var animateContent = false
//    @ObservedObject var vm: ViewModel
//    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
//    let totalDuration = 2.0
//   
//    let recentDrinks: [DrinkRecord]
//    let onQuickAdd: (Double, DrinkType) -> Void
//    
//    
//    public var todaysDrinks: [DrinkRecord] {
//        let today = Calendar.current.startOfDay(for: Date())
//        return recentDrinks
//            .filter {
//                Calendar.current.isDate($0.timestamp, inSameDayAs: today) &&
//                !($0.isQuickAdd ?? false)
//            }
//            .reversed()
//    }
//    private func quickAddDrink(_ amount: Double, type: DrinkType) {
//        withAnimation(.spring()) {
//            vm.giveWater()
//            onQuickAdd(amount, type) // Use the closure instead of direct manipulation
//        }
//    }
//    
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 25) {
//                
//                HStack(spacing: 15) {
//                    StatCard(
//                        title: "Goal",
//                        value: "\(Int(dailyGoal))ml",
//                        icon: "target",
//                        color: .red
//                    )
//                    
//                    StatCard(
//                        title: "Progress",
//                        value: "\(Int(todayProgress))ml",
//                        icon: "chart.line.uptrend.xyaxis",
//                        color: .green
//                    )
//                }
//                .padding(.horizontal)
//                .opacity(animateContent ? 1 : 0)
//                .offset(y: animateContent ? 0 : 20)
//                
//                VStack(spacing: 15) {
//                    Text("Today's Progress")
//                        .font(.title3)
//                        .fontWeight(.semibold)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                    
//                    ZStack {
//                        //                            VStack(spacing: 8) {
//                        //                                Text("\(Int((todayProgress/dailyGoal) * 100))%")
//                        //                                    .font(.system(size: 42, weight: .bold))
//                        //                                    .foregroundColor(.white)
//                        //                                Text("of daily goal")
//                        //                                    .font(.subheadline)
//                        //                                    .foregroundColor(.white.opacity(0.8))
//                        //                            }
//                        //                            .zIndex(1)
//                        
//                        GeometryReader { proxy in
//                            let size = proxy.size
//                            ZStack {
//                                Image(systemName: "drop.fill")
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fit)
//                                    .foregroundColor(.indigo.opacity(0.1))
//                                    .scaleEffect(x: 1.1, y: 1)
//                                
//                                WaterWave(
//                                    progress: CGFloat(todayProgress / dailyGoal),
//                                    waveHeight: 0.05,
//                                    offset: startAnimation
//                                )
//                                .fill(Color.blue)
//                                .overlay(BubblesOverlay())
//                                .mask {
//                                    Image(systemName: "drop.fill")
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fit)
//                                        .padding(.vertical, 15)
//                                }
//                                WaterWave(
//                                    progress: CGFloat(todayProgress / dailyGoal),
//                                    waveHeight: 0.01,
//                                    offset: startAnimation
//                                )
//                                .fill(Color.blue.opacity(0.5))
//                                .overlay(BubblesOverlay())
//                                .mask {
//                                    Image(systemName: "drop.fill")
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fit)
//                                        .padding(.vertical, 15)
//                                }
//                            }
//                            .frame(width: size.width, height: size.height)
//                            .onAppear {
//                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
//                                    startAnimation = size.width
//                                }
//                            }
//                        }
//                        VStack {
//                            Spacer()
//                            ZStack {
//                                
//                            
//                                if vm.pet.happinessLevel == "Happy" {
//                                    Image("Happy")
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 100, height: 100)
//                                        .transition(.scale.combined(with: .opacity))
//                                        .offset(y: 30)
//                                        .opacity(vm.pet.happinessLevel == "Happy" ? 1 : 0)
//                                        .keyframeAnimator(initialValue: AnimationProperties(), repeating: true) { content, value in
//                                            content
//                                                .scaleEffect(y: value.horizantalStretch, anchor: .bottom)
//                                                .offset(x: value.xTranslation)
//                                        }
//                                    keyframes: { _ in
//                                        KeyframeTrack(\.xTranslation) {
//                                            CubicKeyframe(-10, duration: totalDuration * 0.1)  // Left side move
//                                            CubicKeyframe(10, duration: totalDuration * 0.4)   // Right side move
//                                            CubicKeyframe(0, duration: totalDuration * 0.5)    // Back to center
//                                        }
//                                    }
//                                    
//                                }
//                                        
//                                        // Sad image when happiness level is "Sad"
//                                if vm.pet.happinessLevel == "Unhappy" {
//                                    Image("Sad")
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 100, height: 100)
//                                        .transition(.scale.combined(with: .opacity))
//                                        .offset(y: 30)
//                                        .opacity(vm.pet.happinessLevel == "Unhappy" ? 1 : 0)
//                                        .keyframeAnimator(initialValue: AnimationProperties(), repeating: true) { content, value in
//                                            content
//                                                .scaleEffect(y: value.verticalStretch, anchor: .bottom)
//                                                .offset(x: value.xTranslation, y: value.yTranslation)
//                                        }keyframes: { _ in
//                                            KeyframeTrack(\.verticalStretch) {
//                                                SpringKeyframe(0.6, duration: totalDuration * 0.15)
//                                                SpringKeyframe(1, duration: totalDuration * 0.15)
//                                                CubicKeyframe(1.2, duration: totalDuration * 0.4)
//                                                CubicKeyframe(1.1, duration: totalDuration * 0.15)
//                                                CubicKeyframe(1, duration: totalDuration * 0.15)
//                                            }
//                                            KeyframeTrack(\.yTranslation) {
//                                                CubicKeyframe(0, duration: totalDuration * 0.1)
//                                                CubicKeyframe(-25, duration: totalDuration * 0.3)
//                                                CubicKeyframe(-25, duration: totalDuration * 0.3)
//                                                CubicKeyframe(0, duration: totalDuration * 0.3)
//                                            }
//                                        }
//                                    
//                                }
//                                    }
//                            Spacer()
//                            HStack {
//                                Label("Thirst: \(vm.pet.thirst)",systemImage: "")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                Spacer()
//                                Label("Status: \(vm.pet.happinessLevel)",systemImage: "")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                    }
//                    .frame(height: 210)
//                    
//                    
//                }
//                .padding()
//                .background {
//                    RoundedRectangle(cornerRadius: 25)
//                        .fill(.blue.opacity(0.1))
//                }
//                .padding(.horizontal)
//                .opacity(animateContent ? 1 : 0)
//                
//                VStack(alignment: .leading, spacing: 15) {
//                    Text("Quick Add")
//                        .font(.title3)
//                        .fontWeight(.semibold)
//                    
//                    HStack(spacing: 15) {
//                        ForEach(displayedQuickAddDrinks, id: \.id) { record in
//                            
//                            Button(action: {
//                                quickAddDrink(record.amount, type: record.type)
//                            }) {
//                                RecentDrink(recentRecords: record)
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 12)
//                            .background {
//                                RoundedRectangle(cornerRadius: 15)
//                                    .fill(.indigo.opacity(0.1))
//                            }
//                        }
//                    }
//                }
//                .frame(height: 100)
//                .padding(.horizontal)
//                .opacity(animateContent ? 1 : 0)
//                .onReceive(timer){_ in
//                    vm.saveData()
//                }
//                
//                
//                Button(action: { showingAddDrink = true }) {
//                    Label("Add Drink", systemImage: "plus.circle.fill")
//                        .font(.title3)
//                        .fontWeight(.semibold)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                        .background {
//                            RoundedRectangle(cornerRadius: 15)
//                                .fill(.indigo)
//                        }
//                        .foregroundColor(.white)
//                }
//                .padding(.horizontal)
//                .opacity(animateContent ? 1 : 0)
//                .offset(y: animateContent ? 0 : 20)
//                
//            }
//            .padding(.vertical)
//            
//            .navigationTitle("Hydration Tracker")
//            .onAppear {
//                withAnimation(.spring(response: 0.8)) {
//                    animateContent = true
//                }
//            }
//        }
//    }
//}
//
//extension DashboardView {
//    var displayedQuickAddDrinks: [DrinkRecord] {
//        let actualDrinks = Array(todaysDrinks.prefix(3))
//        
//        if actualDrinks.count >= 3 {
//            return Array(actualDrinks.prefix(3))
//        }
//       
//        let remainingSlots = 3 - actualDrinks.count
//        let sampleDrinks = Array(DefaultDrinks.sampleDrinks.prefix(remainingSlots))
//    
//        return actualDrinks + sampleDrinks
//    }
//}
//
//struct AnimationProperties{
//    var xTranslation = 0.0
//    var yTranslation = 0.0
//    var verticalStretch = 0.5
//    var horizantalStretch = 0.5
//}
import SwiftUI
import Charts
import WidgetKit
//import UIKit

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
                       //     ZStack {
//                                if vm.pet.happinessLevel == "Happy" {
//                                    Image("Happy")
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 100, height: 100)
//                                        .transition(.scale.combined(with: .opacity))
//                                        .offset(y: 30)
//                                        .opacity(vm.pet.happinessLevel == "Happy" ? 1 : 0)
//                                        .keyframeAnimator(
//                                            initialValue: AnimationProperties(),
//                                            repeating: true
//                                        ) { content, value in
//                                            content
//                                                .scaleEffect(x: value.horizantalStretch, y: 1.0, anchor: .bottom)
//                                                .offset(x: value.xTranslation)
//                                                .scaleEffect(x: value.isFlipped ? -1 : 1, y: 1)
//                                        } keyframes: { _ in
//                                            KeyframeTrack(\.xTranslation) {
//                                                SpringKeyframe(-10, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(10, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(0, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(0, duration: totalDuration * 0.4)
//                                            }
//                                            
//                                            KeyframeTrack(\.horizantalStretch) {
//                                                SpringKeyframe(1.1, duration: totalDuration * 0.15)
//                                                SpringKeyframe(0.9, duration: totalDuration * 0.15)
//                                                SpringKeyframe(1.0, duration: totalDuration * 0.3)
//                                                SpringKeyframe(1.0, duration: totalDuration * 0.4)
//                                            }
//                                            
//                                            KeyframeTrack(\.isFlipped) {
//                                                LinearKeyframe(false, duration: totalDuration * 0.4)
//                                                LinearKeyframe(true, duration: totalDuration * 0.2)
//                                                LinearKeyframe(false, duration: totalDuration * 0.4)
//                                            }
//                                        }
//                                }
//                                
//                                if vm.pet.happinessLevel == "Unhappy" {
//                                    Image("Sad")
//                                        .resizable()
//                                        .scaledToFit()
//                                        .frame(width: 100, height: 100)
//                                        .transition(.scale.combined(with: .opacity))
//                                        .offset(y: 30)
//                                        .opacity(vm.pet.happinessLevel == "Unhappy" ? 1 : 0)
//                                        .keyframeAnimator(
//                                            initialValue: AnimationProperties(),
//                                            repeating: true
//                                        ) { content, value in
//                                            content
//                                                .scaleEffect(y: value.verticalStretch, anchor: .bottom)
//                                                .offset(x: value.xTranslation, y: value.yTranslation)
//                                        } keyframes: { _ in
//                                            KeyframeTrack(\.verticalStretch) {
//                                                SpringKeyframe(0.9, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(1.2, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(0.95, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(1.0, duration: totalDuration * 0.4)
//                                            }
//                                            
//                                            KeyframeTrack(\.yTranslation) {
//                                                SpringKeyframe(0, duration: totalDuration * 0.2)
//                                                SpringKeyframe(-25, duration: totalDuration * 0.2, spring: .bouncy)
//                                                SpringKeyframe(-20, duration: totalDuration * 0.2)
//                                                SpringKeyframe(0, duration: totalDuration * 0.4, spring: .bouncy)
//                                            }
//                                            
//                                            KeyframeTrack(\.xTranslation) {
//                                                SpringKeyframe(-3, duration: totalDuration * 0.2)
//                                                SpringKeyframe(3, duration: totalDuration * 0.2)
//                                                SpringKeyframe(0, duration: totalDuration * 0.6, spring: .bouncy)
//                                            }
//                                        }
                                //}
                            //}
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
                    .scaleEffect(x: value.horizantalStretch, y: 1.0, anchor: .bottom)
                    .offset(x: value.xTranslation)
                    .scaleEffect(x: value.flipRotation < 0.5 ? 1 : -1, y: 1)
            } keyframes: { _ in
                KeyframeTrack(\.xTranslation) {
                    SpringKeyframe(-10, duration: duration * 0.2)
                    SpringKeyframe(10, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.4)
                }
                
                KeyframeTrack(\.horizantalStretch) {
                    SpringKeyframe(1.1, duration: duration * 0.15)
                    SpringKeyframe(0.9, duration: duration * 0.15)
                    SpringKeyframe(1.0, duration: duration * 0.3)
                    SpringKeyframe(1.0, duration: duration * 0.4)
                }
                
                KeyframeTrack(\.flipRotation) {
                    LinearKeyframe(0.0, duration: duration * 0.4)
                    LinearKeyframe(1.0, duration: duration * 0.2)
                    LinearKeyframe(0.0, duration: duration * 0.4)
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
                    .offset(x: value.xTranslation, y: value.yTranslation)
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
                    SpringKeyframe(-20, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.4)
                }
                
                KeyframeTrack(\.xTranslation) {
                    SpringKeyframe(-3, duration: duration * 0.2)
                    SpringKeyframe(3, duration: duration * 0.2)
                    SpringKeyframe(0, duration: duration * 0.6)
                }
            }
    }
}

struct AnimationProperties {
    var xTranslation = 0.0
    var yTranslation = 0.0
    var verticalStretch = 1.0
    var horizantalStretch = 1.0
    var flipRotation = 0.0  // Changed from isFlipped boolean to Double
}
