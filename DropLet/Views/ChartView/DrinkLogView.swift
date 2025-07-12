import SwiftUI

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
                        VStack(alignment: .center, spacing: 10) {
                            Spacer()
                            Image("Sphera")
                                .resizable()
                                .opacity(0.5)
                                .frame(width: 60, height: 60)
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
