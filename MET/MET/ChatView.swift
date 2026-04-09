import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.turns) { turn in
                                messageBlock(for: turn)
                                    .id(turn.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.turns.count) { _, _ in
                        if let last = viewModel.turns.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                if let err = viewModel.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                HStack(alignment: .bottom) {
                    TextField("Write in English…", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...6)

                    Button {
                        let text = draft
                        draft = ""
                        Task {
                            await viewModel.sendUserMessage(text)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("MET")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        viewModel.clearConversation()
                    }
                    .disabled(viewModel.turns.isEmpty || viewModel.isSending)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBlock(for turn: ChatTurn) -> some View {
        switch turn.role {
        case .user:
            VStack(alignment: .leading, spacing: 8) {
                Text(turn.text)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let t = turn.teaching {
                    correctionCard(t, userOriginal: turn.text)
                }
            }
        case .assistant:
            Text(turn.text)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func correctionCard(_ t: TeachingPayload, userOriginal: String) -> some View {
        let trimmedUser = userOriginal.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCorrected = t.correctedUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Correction")
                    .font(.subheadline.weight(.semibold))
            }

            if trimmedCorrected != trimmedUser {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested wording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(t.correctedUserText)
                        .font(.body)
                }
            }

            if !t.mistakes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(t.mistakes) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.type.capitalized)
                                .font(.caption.weight(.semibold))
                            Text(m.explanation)
                                .font(.caption)
                            Text("Try: \(m.suggestion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !t.improvementFocus.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(t.improvementFocus, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
}
