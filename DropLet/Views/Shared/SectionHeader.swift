import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.title3)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle()) // Make the entire row tappable
        .padding(.horizontal)
    }
}
