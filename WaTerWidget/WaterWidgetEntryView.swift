import SwiftUI
import SwiftData

struct WaTerWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry
    let goal = 10000
    
    // Computed properties optimized with let declaration
    private let calendar = Calendar.current
    
    private var progressPercentage: Int {
        min(Int((Double(entry.amount) / Double(goal)) * 100), 100)
    }
    
    private var hoursFromNow: Int {
        let oneDayAhead = calendar.date(byAdding: .day, value: 1, to: .now)!
        let startOfNextDay = calendar.startOfDay(for: oneDayAhead)
        let diffComponents = calendar.dateComponents([.hour], from: entry.date, to: startOfNextDay)
        return diffComponents.hour ?? 0
    }
    
    private var waveAnimation: Animation {
        .linear(duration: 2).repeatForever(autoreverses: false)
    }
    
    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                smallWidget
            default:
                mediumWidget
            }
        }
        .widgetBackground()
    }
    
    private var smallWidget: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary.opacity(0.8))
                Spacer()
         }
            
            ZStack {
                waterDropView
                    .frame(height: 80)
                
                Text("\(progressPercentage)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .offset(y: 5)
            }
            
            HStack {
                Label("\(hoursFromNow)h left", systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
            }
        }
        .padding(8)
    }
    
    private var mediumWidget: some View {
        HStack(spacing: 20) {
            waterDropView
                .frame(width: 100, height: 100)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Water Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(entry.amount) / \(goal) ml")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if #available(iOS 17.0, *) {
                    HStack(alignment: .center, spacing: 12) {
                        ForEach(DrinkType.allCases.reversed(), id: \.self) { drinkType in
                            Button(intent: DrinkAddIntent(drinkType: drinkType, amount: 50)) {
                                VStack {
                                    Image(systemName: drinkType.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(drinkType.color)
                                        .frame(width: 28, height: 28)
                                        .background(drinkType.color.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }.offset(x: -5)
                }
                
                Label("\(hoursFromNow) hours remaining", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
    
    private var waterDropView: some View {
        GeometryReader { proxy in
            ZStack {
                // Background drop
                Image(systemName: "drop.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blue.opacity(0.1))
                
                // Animated water wave
                WaterWave(
                    progress: CGFloat(progressPercentage) / 100,
                    waveHeight: 0.05,
                    offset: proxy.size.width
                )
                .fill(Color.blue)
                .overlay(BubblesOverlay())
                .mask {
                    Image(systemName: "drop.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                }
            }
            .animation(waveAnimation, value: progressPercentage)
        }
    }
}

// Extension for widget background
extension View {
    func widgetBackground() -> some View {
        self.containerBackground(for: .widget) {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
}


