import SwiftUI

struct MemoriesListView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var memoryVM: MemoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if appState.memories.isEmpty {
                    emptyState
                } else {
                    memoriesList
                }
            }
            .navigationTitle("Memories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await memoryVM.loadMemories() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No memories yet")
                .font(.title3.weight(.semibold))
            Text("Start streaming and tap Record to capture your first memory.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var memoriesList: some View {
        List {
            ForEach(appState.memories) { entry in
                NavigationLink(destination: MemoryDetailView(entry: entry)) {
                    MemoryRowView(entry: entry)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let entry = appState.memories[index]
                    Task { await memoryVM.deleteMemory(entry) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Row

struct MemoryRowView: View {
    let entry: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Summary
            Text(entry.structuredSummary)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            // Date + duration
            HStack {
                Label(entry.createdAt.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock")
                Spacer()
                Label(String(format: "%.0fs", entry.durationSeconds),
                      systemImage: "waveform")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Tags
            if !entry.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct MemoryDetailView: View {
    let entry: MemoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Summary card
                GroupBox("Summary") {
                    Text(entry.structuredSummary)
                        .font(.body)
                }

                // Tags
                if !entry.tags.isEmpty {
                    GroupBox("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(entry.tags, id: \.self) { TagChip(text: $0) }
                        }
                    }
                }

                // Raw transcript
                GroupBox("Raw Transcript") {
                    Text(entry.rawTranscript)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                // Metadata
                GroupBox("Info") {
                    LabeledContent("Recorded", value: entry.createdAt.formatted())
                    LabeledContent("Duration", value: String(format: "%.1f seconds", entry.durationSeconds))
                    LabeledContent("ID", value: entry.id.uuidString)
                }
            }
            .padding()
        }
        .navigationTitle("Memory Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
            for subview in subviews {
                let sz = subview.sizeThatFits(.unspecified)
                if x + sz.width > maxWidth, x > 0 {
                    y += rowHeight + spacing
                    x = 0
                    rowHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: sz))
                x += sz.width + spacing
                rowHeight = max(rowHeight, sz.height)
            }
            size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
