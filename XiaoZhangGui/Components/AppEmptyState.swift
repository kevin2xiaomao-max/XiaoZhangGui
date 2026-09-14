import SwiftUI

struct AppEmptyState: View {
    let title: String
    var systemImage: String = "tray"
    var description: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxl)
    }
}
