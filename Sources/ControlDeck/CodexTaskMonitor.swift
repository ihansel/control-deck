import Foundation

@MainActor
final class CodexTaskMonitor: ObservableObject {
    @Published private(set) var tasks: [RecentCodexTask] = []
    @Published private(set) var lastRefresh = Date.distantPast
    @Published private(set) var errorMessage: String?

    var onTasksChanged: (([RecentCodexTask]) -> Void)?

    private var timer: Timer?
    private var refreshInFlight = false
    private var rolloutCache: [String: CachedRollout] = [:]
    private let databasePath = NSString(string: "~/.codex/state_5.sqlite").expandingTildeInPath

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        let databasePath = self.databasePath
        let cache = rolloutCache

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Self.loadTasks(databasePath: databasePath, cache: cache)
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshInFlight = false
                self.lastRefresh = Date()
                switch result {
                case let .success(loadResult):
                    self.rolloutCache = loadResult.cache
                    if loadResult.tasks != self.tasks {
                        self.tasks = loadResult.tasks
                        self.onTasksChanged?(loadResult.tasks)
                    }
                    self.errorMessage = nil
                case let .failure(error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    nonisolated static func inferState(from logText: String) -> CodexTaskState {
        guard !logText.isEmpty else { return .idle }

        func latest(_ patterns: [String]) -> String.Index? {
            patterns.compactMap {
                logText.range(of: $0, options: .backwards)?.lowerBound
            }.max()
        }

        let latestTaskStart = latest(["\"type\":\"task_started\"", "\"type\": \"task_started\""])
        let latestTaskComplete = latest(["\"type\":\"task_complete\"", "\"type\": \"task_complete\""])
        let latestError = latest([
            "\"type\":\"turn_aborted\"",
            "\"type\": \"turn_aborted\"",
            "\"type\":\"stream_error\""
        ])
        let latestInputRequest = latest([
            "\"name\":\"request_user_input\"",
            "\"type\":\"request_user_input\"",
            "exec_approval_request",
            "apply_patch_approval_request"
        ])
        let latestResolution = latest([
            "\"type\":\"function_call_output\"",
            "\"type\": \"function_call_output\"",
            "\"type\":\"user_message\""
        ])
        let beginning = logText.startIndex

        if let error = latestError, error > (latestTaskComplete ?? beginning) {
            return .error
        }
        if let request = latestInputRequest,
           request > (latestResolution ?? beginning),
           request > (latestTaskComplete ?? beginning) {
            return .needsInput
        }
        if let start = latestTaskStart, start > (latestTaskComplete ?? beginning) {
            return .thinking
        }
        if latestTaskComplete != nil {
            return .complete
        }
        return .idle
    }

    nonisolated private static func loadTasks(
        databasePath: String,
        cache: [String: CachedRollout]
    ) -> Result<TaskLoadResult, Error> {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            return .failure(MonitorError.databaseMissing)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-separator", "\u{001f}",
            databasePath,
            """
            SELECT id, replace(replace(title, char(10), ' '), char(13), ' '), \
            rollout_path, coalesce(updated_at_ms, updated_at * 1000)
            FROM threads
            WHERE archived = 0
            ORDER BY max(
                coalesce(recency_at_ms, 0),
                coalesce(updated_at_ms, 0),
                updated_at * 1000
            ) DESC
            LIMIT 6;
            """
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let data = errors.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8) ?? "sqlite3 failed"
                return .failure(MonitorError.queryFailed(message))
            }
        } catch {
            return .failure(error)
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else {
            return .failure(MonitorError.invalidOutput)
        }

        var updatedCache = cache
        let tasks = string.split(separator: "\n").compactMap { row -> RecentCodexTask? in
            let fields = row.split(separator: "\u{001f}", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4 else { return nil }
            let rolloutPath = fields[2]
            let attributes = try? FileManager.default.attributesOfItem(atPath: rolloutPath)
            let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
            let modified = attributes?[.modificationDate] as? Date ?? .distantPast
            let cached = cache[rolloutPath]

            let state: CodexTaskState
            if cached?.size == size, cached?.modified == modified {
                state = cached?.state ?? .idle
            } else {
                let inferred = inferState(from: tail(of: rolloutPath))
                if inferred == .idle, Date().timeIntervalSince(modified) < 120 {
                    state = .thinking
                } else {
                    state = inferred
                }
                updatedCache[rolloutPath] = CachedRollout(
                    size: size,
                    modified: modified,
                    state: state
                )
            }
            let milliseconds = Double(fields[3]) ?? 0
            return RecentCodexTask(
                id: fields[0],
                title: fields[1].isEmpty ? "Untitled task" : fields[1],
                rolloutPath: rolloutPath,
                updatedAt: Date(timeIntervalSince1970: milliseconds / 1000),
                state: state
            )
        }
        let activePaths = Set(tasks.map(\.rolloutPath))
        updatedCache = updatedCache.filter { activePaths.contains($0.key) }
        return .success(TaskLoadResult(tasks: tasks, cache: updatedCache))
    }

    nonisolated private static func tail(
        of path: String,
        maximumBytes: Int = 96_000
    ) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }
        do {
            let length = try handle.seekToEnd()
            let offset = length > UInt64(maximumBytes) ? length - UInt64(maximumBytes) : 0
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

private struct CachedRollout: Sendable {
    let size: UInt64
    let modified: Date
    let state: CodexTaskState
}

private struct TaskLoadResult: Sendable {
    let tasks: [RecentCodexTask]
    let cache: [String: CachedRollout]
}

private enum MonitorError: LocalizedError {
    case databaseMissing
    case queryFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .databaseMissing: "Codex task database was not found"
        case let .queryFailed(message): "Codex task query failed: \(message)"
        case .invalidOutput: "Codex task query returned invalid text"
        }
    }
}
