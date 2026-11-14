import SwiftUI
import Combine
import ActivityKit
import UserNotifications

@MainActor final class CampusStore: ObservableObject {
    @Published var isDemo = true
    @Published var student: Student?
    @Published var events: [CampusEvent] = []
    @Published var grades: [CampusGrade] = []
    @Published var weekStart = CampusTime.week(Date())
    @Published var refreshed: Date?
    @Published var busy = false
    @Published var message: String?
    @Published var tasks: [StudyTask] = []
    @Published var authorizationURL: URL?
    @Published var hasConnection = false
    private var credentials: Credentials?
    private var pending: OAuthToken?
    private var pendingCredentials: Credentials?
    private var generation = UUID()
    private var activityEndTask: Task<Void, Never>?
    private var cacheURL: URL { Self.directory.appendingPathComponent("snapshot.json") }
    private var tasksURL: URL { Self.directory.appendingPathComponent("tasks.json") }
    private static var directory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Campus", isDirectory: true) }
    init() {
        do {
            credentials = try SecureStore.read()
            hasConnection = credentials?.token != nil
            if hasConnection {
                isDemo = false
                if let data = try? Data(contentsOf: cacheURL), let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
                    student = s.student; events = s.events; grades = s.grades; weekStart = s.weekStart; refreshed = s.refreshed
                }
            } else {
                if DemoData.events(week: weekStart).last!.end < Date() {
                    weekStart = CampusTime.calendar.date(byAdding: .day, value: 7, to: weekStart)!
                }
                events = DemoData.events(week: weekStart); grades = DemoData.grades
            }
            if let data = try? Data(contentsOf: tasksURL) { tasks = try JSONDecoder().decode([StudyTask].self, from: data) }
        } catch { message = error.localizedDescription }
    }
    var nextEvent: CampusEvent? { events.first { $0.end > Date() } }
    var displayName: String { isDemo ? "Twój kampus" : (student?.first_name ?? "Witaj") }
    var average: String {
        let values = grades.compactMap(\.numeric)
        guard !values.isEmpty else { return "—" }
        return String(format: "%.2f", values.reduce(0, +) / Double(values.count)).replacingOccurrences(of: ".", with: ",")
    }
    var authorizationPending: Bool { pending != nil }
    func beginLogin(key: String, secret: String) async {
        guard !busy else { return }
        let c = Credentials(consumerKey: key.trimmingCharacters(in: .whitespacesAndNewlines), consumerSecret: secret.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !c.consumerKey.isEmpty, !c.consumerSecret.isEmpty else { message = CampusError.missingConfiguration.localizedDescription; return }
        busy = true; defer { busy = false }
        pending = nil; authorizationURL = nil; pendingCredentials = nil
        do {
            let token = try await USOSClient(credentials: c).begin()
            pending = token; pendingCredentials = c
            authorizationURL = URL(string: USOSClient.base + "services/oauth/authorize?oauth_token=" + OAuth1.encode(token.key) + "&interactivity=confirm_user")
        } catch { message = error.localizedDescription }
    }
    func completeLogin(pin: String) async {
        guard !busy, let pending, var c = pendingCredentials else { return }
        let cleanPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPIN.isEmpty else { return }
        busy = true
        do {
            c.token = try await USOSClient(credentials: c).finish(pending, pin: cleanPIN)
            let profile = try await USOSClient(credentials: c).profile()
            try SecureStore.save(c)
            generation = UUID(); credentials = c; hasConnection = true; isDemo = false
            student = profile; events = []; grades = []; refreshed = nil
            weekStart = CampusTime.week(Date())
            self.pending = nil; pendingCredentials = nil; authorizationURL = nil
            try? FileManager.default.removeItem(at: cacheURL)
            await endActivities()
            await clearReminders()
            busy = false
            await refresh()
        } catch { busy = false; message = error.localizedDescription }
    }
    func cancelLogin() { pending = nil; pendingCredentials = nil; authorizationURL = nil }
    func refresh() async {
        guard !busy else { return }
        guard !isDemo, let c = credentials, c.token != nil else { return }
        busy = true; defer { busy = false }
        let stamp = generation; let requestedWeek = weekStart
        do {
            let api = USOSClient(credentials: c)
            async let p = api.profile()
            async let e = api.timetable(start: requestedWeek)
            async let g = api.grades()
            let (profile, timetable, marks) = try await (p, e, g)
            guard stamp == generation else { return }
            student = profile; events = timetable; grades = marks; refreshed = Date()
            let snapshot = Snapshot(student: profile, events: timetable, grades: marks, weekStart: requestedWeek, refreshed: refreshed!)
            try persist(snapshot, to: cacheURL)
            await reconcileActivity()
        } catch { if stamp == generation { message = error.localizedDescription } }
    }
    func changeWeek(by offset: Int) async {
        guard !busy else { return }
        let old = weekStart
        weekStart = CampusTime.calendar.date(byAdding: .day, value: offset * 7, to: weekStart)!
        if isDemo { events = DemoData.events(week: weekStart) }
        else {
            let previousEvents = events; let previousRefresh = refreshed
            events = []; refreshed = nil
            await refresh()
            if refreshed == nil { weekStart = old; events = previousEvents; refreshed = previousRefresh }
        }
    }
    func persist<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        var dir = Self.directory; var flags = URLResourceValues(); flags.isExcludedFromBackup = true
        try dir.setResourceValues(flags)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
    }
    func addTask(title: String, due: Date) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        tasks.append(StudyTask(title: String(clean.prefix(200)), due: due)); saveTasks()
    }
    func toggleTask(_ id: UUID) { if let i = tasks.firstIndex(where: { $0.id == id }) { tasks[i].done.toggle(); saveTasks() } }
    func deleteTask(_ id: UUID) { tasks.removeAll { $0.id == id }; saveTasks() }
    private func saveTasks() { do { try persist(tasks, to: tasksURL) } catch { message = error.localizedDescription } }
    func logout() async {
        guard !busy else { return }
        busy = true; generation = UUID()
        // Revoke remotely when reachable; always allow local data removal.
        var revokeFailed = false
        if let c = credentials, c.token != nil {
            do { _ = try await USOSClient(credentials: c).request("oauth/revoke_token") } catch { revokeFailed = true }
        }
        do { try SecureStore.delete() } catch { message = error.localizedDescription; busy = false; return }
        credentials = nil; student = nil; hasConnection = false; isDemo = true
        cancelLogin(); refreshed = nil; tasks = []
        do { if FileManager.default.fileExists(atPath: Self.directory.path) { try FileManager.default.removeItem(at: Self.directory) } }
        catch { message = "Wylogowano, ale nie udało się usunąć wszystkich plików lokalnych." }
        weekStart = CampusTime.week(Date()); events = DemoData.events(week: weekStart); grades = DemoData.grades
        await endActivities(); await clearReminders()
        if revokeFailed { message = "Usunięto dane z telefonu. Serwer nie potwierdził unieważnienia sesji — możesz cofnąć dostęp na stronie USOSapps SGH." }
        busy = false
    }
    func startActivity(_ event: CampusEvent) async {
        guard event.end > Date(), event.start < Date().addingTimeInterval(3600), event.end.timeIntervalSinceNow <= 8 * 3600 else {
            message = "Aktywność można uruchomić do godziny przed zajęciami. Wybierz bieżące lub najbliższe zajęcia."; return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Włącz Aktywności na żywo w ustawieniach aplikacji. Zachowaj rozszerzenie LiveActivity podczas instalacji w AltStore."; return
        }
        await endActivities()
        do {
            let state = ClassActivity.ContentState(start: event.start, end: event.end, launched: Date())
            _ = try Activity.request(attributes: ClassActivity(title: event.title, room: event.room, isDemo: event.isDemo),
                content: ActivityContent(state: state, staleDate: event.end), pushType: nil)
            activityEndTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(1, event.end.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                await self?.endActivities()
            }
            message = "Aktywność uruchomiona. Po wyjściu z aplikacji sprawdź Dynamic Island lub ekran blokady."
        } catch { message = "Nie udało się uruchomić Aktywności na żywo: \(error.localizedDescription)" }
    }
    func demoActivity() async {
        await startActivity(CampusEvent(id: "preview", title: "Podgląd · Statystyka", kind: "Ćwiczenia", room: "201", building: "", start: Date(), end: Date().addingTimeInterval(900), isDemo: true))
    }
    func endActivities() async {
        activityEndTask?.cancel(); activityEndTask = nil
        for activity in Activity<ClassActivity>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
    func reconcileActivity() async {
        for activity in Activity<ClassActivity>.activities where activity.content.state.end <= Date() {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    func clearReminders() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix("campus.") }.map(\.identifier))
        center.removeAllDeliveredNotifications()
    }
    func scheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { message = "Powiadomienia są wyłączone. Możesz włączyć je w Ustawieniach iPhone’a."; return }
            await clearReminders()
            let upcoming = events.filter { $0.start.addingTimeInterval(-900) > Date() }.prefix(50)
            for event in upcoming {
                let content = UNMutableNotificationContent()
                content.title = (event.isDemo ? "DEMO · " : "") + event.title
                content.body = "Za 15 minut · \(event.location.isEmpty ? "Sprawdź salę w USOS" : event.location)"
                content.sound = .default
                var comps = CampusTime.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.start.addingTimeInterval(-900))
                comps.timeZone = CampusTime.calendar.timeZone
                let req = UNNotificationRequest(identifier: "campus." + event.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                try await center.add(req)
            }
            message = "Zapisano \(upcoming.count) przypomnień dla wyświetlanego tygodnia. Po zmianie planu ustaw je ponownie."
        } catch { message = error.localizedDescription }
    }
}
