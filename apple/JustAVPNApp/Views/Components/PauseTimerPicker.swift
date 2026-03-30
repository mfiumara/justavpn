import SwiftUI
import JustAVPNCore

struct PauseTimerPicker: View {
    let onSelect: (PauseDuration) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Pause VPN for")
                .font(.headline)

            ForEach(PauseDuration.allCases) { duration in
                Button(action: { onSelect(duration) }) {
                    Text(duration.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
