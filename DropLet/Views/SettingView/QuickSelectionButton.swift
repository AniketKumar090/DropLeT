import SwiftUI

struct QuickSelectionButton: View {
    let selection: QuickSelection
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: selection.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(selection.isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.15))
                    )
                Text(selection.label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .sensoryFeedback(.selection, trigger: selection.isSelected)
    }
}

