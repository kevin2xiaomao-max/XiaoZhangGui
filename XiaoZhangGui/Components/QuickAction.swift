import SwiftUI

struct QuickAction: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.light()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
