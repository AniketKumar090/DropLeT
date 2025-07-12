import SwiftUI

struct HoldDownButton: View {
    var text: String
    var paddingHorizontal: CGFloat = 25
    var paddingVertical: CGFloat = 18
    var duration: CGFloat = 1
    var scale: CGFloat = 0.95
    var background: Color
    var loadingTint: Color
    var shape: AnyShape = .init(.rect(cornerRadius: 12))
    var action: () -> ()
    
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    @State private var timeCount: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var isHolding: Bool = false
    @State private var isCompleted: Bool = false
    
    // Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        HStack {
            Image(systemName: "trash.fill")
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(background.gradient)
                
                GeometryReader {
                    let size = $0.size
                    
                    if !isCompleted {
                        Rectangle()
                            .fill(loadingTint)
                            .frame(width: size.width * progress)
                            .transition(.opacity)
                    }
                }
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        .scaleEffect(isHolding ? scale : 1)
        .animation(.snappy, value: isHolding)
        .onLongPressGesture(minimumDuration: duration, perform: {
            isHolding = false
            cancelTimer()
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted = true
            }
            action()
        }, onPressingChanged: { status in
            if status {
                isCompleted = false
                reset()
                isHolding = true
                addTimer()
            }
        })
        .simultaneousGesture(dragGesture)
        .onReceive(timer) { _ in
            if isHolding && progress != 1 {
                timeCount += 0.01
                progress = max(min(timeCount / duration, 1), 0)
                triggerHapticFeedback()
            }
        }
        .onAppear(perform: cancelTimer)
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { _ in
                guard !isCompleted else { return }
                cancelTimer()
                withAnimation(.snappy) {
                    reset()
                }
            }
    }
    
    func addTimer() {
        timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    }
    
    func cancelTimer() {
        timer.upstream.connect().cancel()
    }
    
    func reset() {
        isHolding = false
        progress = 0
        timeCount = 0
    }
    
    func triggerHapticFeedback() {
        let intensity = CGFloat(progress)
        feedbackGenerator.impactOccurred(intensity: intensity)
    }
}
