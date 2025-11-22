import SwiftUI

struct DebugConsoleView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        VStack(alignment: .leading) {

            // Header
            HStack {
                Text("Logs")
                    .font(.headline)

                Spacer()

                Button("Copy") {
                    UIPasteboard.general.string =
                        vm.logs
                            .map { "\($0.timestamp.formatted(date: .numeric, time: .standard)) • \($0.message)" }
                            .joined(separator: "\n")
                }
            }
            .padding(.horizontal)

            // Logs list
            List(vm.logs) { log in
                VStack(alignment: .leading, spacing: 4) {

                    // Timestamp
                    Text(log.timestamp.formatted(date: .numeric, time: .standard))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Message
                    Text(log.message)
                        .font(.caption)
                }
            }
        }
    }
}
