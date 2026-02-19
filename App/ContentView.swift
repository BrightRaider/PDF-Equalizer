import SwiftUI
import UniformTypeIdentifiers

enum ProcessingState: Equatable {
    case idle
    case processing(String)
    case success(URL, replaced: Bool)
    case error(String)

    static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.processing(let a), .processing(let b)): return a == b
        case (.success(let a, let ar), .success(let b, let br)): return a == b && ar == br
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

struct ContentView: View {
    @State private var state: ProcessingState = .idle
    @State private var isTargeted = false
    @State private var replaceOriginal = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2.5, dash: [8])
                )
                .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            Toggle(isOn: $replaceOriginal) {
                Text(NSLocalizedString("Replace original file", comment: ""))
                    .foregroundColor(replaceOriginal ? .red : .primary)
            }
            .toggleStyle(.checkbox)
            .tint(.red)
            .focusable(false)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            _ = handleDrop(providers)
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPDFFile)) { notification in
            guard let url = notification.object as? URL else { return }
            processPDF(at: url)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("Drop a PDF here", comment: ""))
                    .font(.title2)
                    .fontWeight(.medium)
                Text(NSLocalizedString("All pages will be equalized to the same width", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .processing(let status):
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(status)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

        case .success(let url, let replaced):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text(replaced ? NSLocalizedString("Original replaced!", comment: "") : NSLocalizedString("Done!", comment: ""))
                    .font(.title2)
                    .fontWeight(.medium)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 12) {
                    Button(NSLocalizedString("Show in Finder", comment: "")) {
                        NSWorkspace.shared.selectFile(
                            url.path,
                            inFileViewerRootedAtPath: url.deletingLastPathComponent().path
                        )
                    }
                    Button(NSLocalizedString("Process Another", comment: "")) {
                        state = .idle
                    }
                }
                .padding(.top, 4)
            }

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text(NSLocalizedString("Error", comment: ""))
                    .font(.title2)
                    .fontWeight(.medium)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(NSLocalizedString("Try Again", comment: "")) {
                    state = .idle
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let urlData = data as? Data,
                  let url = URL(dataRepresentation: urlData, relativeTo: nil),
                  url.pathExtension.lowercased() == "pdf" else {
                DispatchQueue.main.async {
                    state = .error(NSLocalizedString("Please drop a PDF file.", comment: ""))
                }
                return
            }
            processPDF(at: url)
        }
        return true
    }

    private func processPDF(at url: URL) {
        let shouldReplace = replaceOriginal
        state = .processing(NSLocalizedString("Loading PDF...", comment: ""))

        Task.detached(priority: .userInitiated) {
            do {
                let result = try PDFProcessor.process(
                    inputURL: url,
                    replaceOriginal: shouldReplace
                ) { status in
                    Task { @MainActor in
                        state = .processing(status)
                    }
                }

                await MainActor.run {
                    state = .success(result.outputURL, replaced: shouldReplace)
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    state = .error(message)
                }
            }
        }
    }
}
