import SwiftUI

struct SummaryView: View {
    let result: SummaryResult
    let onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 20)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Lecture")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.3)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GroupBox("Key Points") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(result.bullets, id: \.self) { b in
                                    Text("• \(b)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if !result.keywords.isEmpty {
                            GroupBox("Keywords") {
                                Text(result.keywords.joined(separator: ", "))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .padding(.vertical, 4)
                            }
                        }

                        if !result.questions.isEmpty {
                            GroupBox("Possible Questions") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(result.questions, id: \.self) { q in
                                        Text("• \(q)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 420, height: 540)
    }
}
