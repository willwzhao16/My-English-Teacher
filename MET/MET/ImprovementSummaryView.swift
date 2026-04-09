import SwiftUI

struct ImprovementSummaryView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("This week") {
                    if summaryLines.isEmpty {
                        Text("Chat in English to see patterns and focus areas here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(summaryLines, id: \.self) { line in
                            Text(line)
                        }
                    }
                }

                Section("Mistake types (recent)") {
                    if typeRows.isEmpty {
                        Text("No tagged mistakes yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(typeRows, id: \.type) { row in
                            HStack {
                                Text(row.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                Spacer()
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Focus ideas (from your chats)") {
                    if focusBullets.isEmpty {
                        Text("Improvement tips will appear after each exchange.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(focusBullets, id: \.self) { line in
                            Text(line)
                        }
                    }
                }
            }
            .navigationTitle("Improve")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.reloadFromDisk()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var weekStart: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
    }

    private var recentTeachings: [TeachingPayload] {
        viewModel.turns.compactMap { turn in
            guard turn.role == .user, let t = turn.teaching, turn.createdAt >= weekStart else { return nil }
            return t
        }
    }

    private var typeRows: [(type: String, count: Int)] {
        var counts: [String: Int] = [:]
        for t in recentTeachings {
            for m in t.mistakes {
                counts[m.type, default: 0] += 1
            }
        }
        return counts.map { (type: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var focusBullets: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for t in recentTeachings.reversed() {
            for line in t.improvementFocus {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
                seen.insert(trimmed)
                out.append(trimmed)
                if out.count >= 12 { return out }
            }
        }
        return out
    }

    private var summaryLines: [String] {
        guard !typeRows.isEmpty || !focusBullets.isEmpty else { return [] }
        var lines: [String] = []
        if let top = typeRows.first {
            lines.append("You often see notes in the \"\(top.type.replacingOccurrences(of: "_", with: " "))\" area—worth a little extra practice.")
        }
        if let firstFocus = focusBullets.first {
            lines.append("Latest focus: \(firstFocus)")
        }
        return lines
    }
}

#Preview {
    ImprovementSummaryView(viewModel: ChatViewModel())
}
