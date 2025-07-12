import SwiftUI

struct SettingsToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let title: String
    var onChange: ((Bool) -> Void)? = nil
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .font(.title3)
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.blue.opacity(0.6)))
        .onChange(of: isOn) { newValue in
            onChange?(newValue)
        }
    }
}
