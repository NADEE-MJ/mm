import SwiftUI

struct LogStreamView: View {
    let serverId: String
    let source: String

    @State private var text = "Log streaming placeholder"

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color.black.opacity(0.95).ignoresSafeArea())
        .foregroundStyle(.green)
        .navigationTitle("\(source) logs")
    }
}
