import Foundation

struct LocalizedText: Codable, Equatable {
    var pl: String?
    var en: String?
    var text: String { [pl, en].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "Bez nazwy" }
}

enum CampusTime {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        c.firstWeekday = 2
        return c
    }
    static func parse(_ value: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: value)
    }
    static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pl_PL")
        f.timeZone = calendar.timeZone; f.dateFormat = format
        return f.string(from: date)
    }
    static func week(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)!.start }
}

struct CampusEvent: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let kind: String
    let room: String
    let building: String
    let start: Date
    let end: Date
    var tentative: Bool = false
    var isDemo: Bool = false
    var timeRange: String { "\(CampusTime.string(start, "HH:mm"))–\(CampusTime.string(end, "HH:mm"))" }
    var location: String { [room.isEmpty ? nil : "Sala \(room)", building.isEmpty ? nil : building].compactMap { $0 }.joined(separator: " · ") }
    var tintIndex: Int { title.utf8.reduce(0) { ($0 + Int($1)) % 4 } }
}

struct APIEvent: Decodable {
    let start_time: String
    let end_time: String
    let name: LocalizedText
    let course_name: LocalizedText?
    let classtype_name: LocalizedText?
    let room_number: String?
    let building_name: LocalizedText?
    let frequency: String?
    let type: String?
    func model() throws -> CampusEvent {
        guard let start = CampusTime.parse(start_time), let end = CampusTime.parse(end_time), end > start else {
            throw CampusError.invalidData
        }
        let title = course_name?.text ?? name.text
        return CampusEvent(id: "\(start_time)|\(end_time)|\(title)|\(room_number ?? "")", title: title,
            kind: classtype_name?.text ?? (type == "exam" ? "Egzamin" : "Zajęcia"),
            room: room_number ?? "", building: building_name?.text ?? "", start: start, end: end,
            tentative: frequency == "other" || frequency == "once")
    }
}
struct FlexibleID: Codable, Equatable {
    let value: String
    init(_ value: String) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s } else { value = String(try c.decode(Int.self)) }
    }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }
}
struct Student: Codable {
    let id: FlexibleID
    let first_name: String
    let last_name: String
    var fullName: String { "\(first_name) \(last_name)" }
}
struct CourseEdition: Codable {
    let course_name: LocalizedText?
    let course_id: String?
    let term_id: String?
}
struct CampusGrade: Codable, Identifiable {
    let value_symbol: String
    let passes: Bool
    let exam_id: FlexibleID
    let exam_session_number: FlexibleID
    let date_modified: String?
    let course_edition: CourseEdition?
    var id: String { exam_id.value + ":" + exam_session_number.value }
    var title: String { course_edition?.course_name?.text ?? "Protokół \(exam_id.value)" }
    var term: String { course_edition?.term_id ?? "Bez cyklu" }
    var numeric: Double? { Double(value_symbol.replacingOccurrences(of: ",", with: ".")) }
}
struct Snapshot: Codable {
    let student: Student
    let events: [CampusEvent]
    let grades: [CampusGrade]
    let weekStart: Date
    let refreshed: Date
}
struct StudyTask: Codable, Identifiable {
    var id = UUID()
    var title: String
    var due: Date
    var done = false
}

enum CampusError: LocalizedError {
    case invalidData, missingConfiguration, http(Int), keychain(Int32), invalidToken
    var errorDescription: String? {
        switch self {
        case .invalidData: return "USOS zwrócił dane w nieobsługiwanym formacie. Spróbuj ponownie później."
        case .missingConfiguration: return "Dodaj klucz aplikacji wydany przez USOS SGH."
        case .http(let status):
            switch status {
            case 401: return "Sesja lub klucz aplikacji są nieprawidłowe. Połącz konto ponownie."
            case 403: return "USOS nie udzielił dostępu. Sprawdź uprawnienia klucza i zgodę na dostęp do danych."
            case 429: return "Zbyt wiele zapytań do USOS. Odczekaj chwilę."
            case 500...599: return "Serwer USOS SGH jest chwilowo niedostępny (\(status)). Zachowano ostatnie dane."
            default: return "USOS odrzucił zapytanie (\(status)). Sprawdź klucz i zgodność API uczelni."
            }
        case .keychain: return "Nie udało się bezpiecznie zapisać danych w pęku kluczy."
        case .invalidToken: return "Nieprawidłowa lub wygasła autoryzacja. Rozpocznij logowanie ponownie."
        }
    }
}

enum DemoData {
    static func events(week: Date) -> [CampusEvent] {
        let subjects = ["Mikroekonomia", "Statystyka", "Finanse przedsiębiorstw", "Język angielski", "Zarządzanie strategiczne"]
        return (0..<5).flatMap { day in
            (0..<2).map { slot in
                let date = CampusTime.calendar.date(byAdding: .day, value: day, to: week)!
                let start = CampusTime.calendar.date(bySettingHour: 9 + slot * 3, minute: 0, second: 0, of: date)!
                return CampusEvent(id: "demo-\(day)-\(slot)", title: subjects[(day + slot) % subjects.count],
                    kind: slot == 0 ? "Wykład" : "Ćwiczenia", room: slot == 0 ? "Aula I" : "201", building: "Budynek G",
                    start: start, end: start.addingTimeInterval(5400), isDemo: true)
            }
        }
    }
    static var grades: [CampusGrade] {
        zip(["Statystyka", "Mikroekonomia", "Zarządzanie", "Język angielski"], ["4.5", "5.0", "4.0", "5.0"]).enumerated().map { i, pair in
            CampusGrade(value_symbol: pair.1, passes: true, exam_id: FlexibleID("demo\(i)"), exam_session_number: FlexibleID("1"),
                date_modified: nil, course_edition: CourseEdition(course_name: LocalizedText(pl: pair.0), course_id: nil, term_id: "Przykładowy semestr"))
        }
    }
}
