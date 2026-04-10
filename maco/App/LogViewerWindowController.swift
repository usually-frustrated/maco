import AppKit
import OSLog

final class LogViewerWindowController: NSWindowController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private var streamTimer: Timer?
    private var lastEntryDate: Date = .distantPast
    private static let subsystem = "frustrated.maco.app"
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.labelColor
    ]

    convenience init() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "maco Logs"
        window.center()
        self.init(window: window)
        setupUI()
        loadInitialEntries()
        startStream()
    }

    private func setupUI() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .textBackgroundColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        window?.contentView = scrollView
    }

    private func loadInitialEntries() {
        let since = Date().addingTimeInterval(-300) // last 5 minutes
        appendEntries(since: since)
        // If no historical entries found, anchor to now so the timer only
        // fetches entries that arrive after the window was opened.
        if lastEntryDate == .distantPast {
            lastEntryDate = since
        }
    }

    private func startStream() {
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.appendEntries(since: self.lastEntryDate)
        }
    }

    private func appendEntries(since: Date) {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: since)
            let predicate = NSPredicate(format: "subsystem BEGINSWITH %@", Self.subsystem)
            var newLines: [String] = []
            var latest = lastEntryDate
            for entry in try store.getEntries(at: position, matching: predicate) {
                guard let e = entry as? OSLogEntryLog else { continue }
                // Skip already-seen entries (position(date:) is inclusive)
                guard e.date > lastEntryDate else { continue }
                let level: String
                switch e.level {
                case .debug:   level = "DEBUG"
                case .info:    level = "INFO "
                case .notice:  level = "NOTCE"
                case .error:   level = "ERROR"
                case .fault:   level = "FAULT"
                default:       level = "     "
                }
                newLines.append("[\(dateFormatter.string(from: e.date))] [\(level)] [\(e.category)] \(e.composedMessage)")
                if e.date > latest { latest = e.date }
            }
            guard !newLines.isEmpty else { return }
            lastEntryDate = latest
            let appended = NSAttributedString(string: newLines.joined(separator: "\n") + "\n", attributes: textAttrs)
            textView.textStorage?.append(appended)
            textView.scrollToEndOfDocument(nil)
        } catch {
            let msg = NSAttributedString(string: "OSLogStore error: \(error)\n", attributes: textAttrs)
            textView.textStorage?.append(msg)
            streamTimer?.invalidate() // stop spamming on persistent error
        }
    }

    override func close() {
        streamTimer?.invalidate()
        streamTimer = nil
        super.close()
    }
}
