import Foundation

struct QuickSelection: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let volume: Int
    var isSelected: Bool
}
