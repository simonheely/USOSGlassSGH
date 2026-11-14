import SwiftUI
import Combine

@main
struct USOSGlassSGHApp: App {
    @StateObject private var store = DemoStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.08, green: 0.39, blue: 0.78)
    static let violet = Color(red: 0.45, green: 0.36, blue: 0.83)
    static let mint = Color(red: 0.04, green: 0.65, blue: 0.55)
    static let paper = Color(uiColor: .systemGroupedBackground)
}

struct Lesson: Identifiable {
    let id = UUID()
    let subject: String
    let kind: String
    let start: String
    let end: String
    let room: String
    let lecturer: String
    let weekday: Int // Monday = 1
    let color: Color
}

struct Grade: Identifiable {
    let id = UUID()
    let subject: String
    let value: String
    let ects: Int
    let date: String
    let lecturer: String
}

struct Registration: Identifiable {
    let id: String
    let title: String
    let details: String
    let deadline: String
    let capacity: String
}

@MainActor final class DemoStore: ObservableObject {
    @Published var enrolled: Set<String> = ["finance"] {
        didSet { UserDefaults.standard.set(Array(enrolled), forKey: "demo.enrolled") }
    }
    @Published var notificationsEnabled = true
    @Published var showOnlyUpcoming = false
    @Published var completedSurveys: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(completedSurveys), forKey: "demo.surveys") }
    }

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "demo.enrolled") { enrolled = Set(saved) }
        if let saved = UserDefaults.standard.stringArray(forKey: "demo.surveys") { completedSurveys = Set(saved) }
    }

    let lessons: [Lesson] = [
        .init(subject: "Mikroekonomia", kind: "Wykład", start: "08:00", end: "09:30", room: "Aula I", lecturer: "dr Anna Kowalska", weekday: 1, color: Theme.accent),
        .init(subject: "Statystyka", kind: "Ćwiczenia", start: "10:00", end: "11:30", room: "B-201", lecturer: "dr Piotr Nowak", weekday: 1, color: Theme.violet),
        .init(subject: "Finanse przedsiębiorstw", kind: "Ćwiczenia", start: "12:00", end: "13:30", room: "G-152", lecturer: "dr Marta Zielińska", weekday: 2, color: Theme.mint),
        .init(subject: "Makroekonomia", kind: "Wykład", start: "09:50", end: "11:20", room: "Aula VII", lecturer: "prof. Jan Wiśniewski", weekday: 3, color: Theme.accent),
        .init(subject: "Język angielski", kind: "Lektorat", start: "13:40", end: "15:10", room: "C-105", lecturer: "mgr Alex Smith", weekday: 3, color: Theme.violet),
        .init(subject: "Prawo gospodarcze", kind: "Wykład", start: "11:40", end: "13:10", room: "Aula II", lecturer: "dr Katarzyna Mazur", weekday: 4, color: Theme.mint),
        .init(subject: "Matematyka", kind: "Ćwiczenia", start: "08:00", end: "09:30", room: "B-114", lecturer: "dr Tomasz Lewandowski", weekday: 5, color: Theme.violet)
    ]
    let grades: [Grade] = [
        .init(subject: "Podstawy zarządzania", value: "5,0", ects: 5, date: "24.06.2026", lecturer: "dr A. Nowak"),
        .init(subject: "Geografia ekonomiczna", value: "4,5", ects: 4, date: "18.06.2026", lecturer: "prof. M. Wiśniewska"),
        .init(subject: "Socjologia", value: "5,0", ects: 3, date: "12.06.2026", lecturer: "dr P. Lewicki"),
        .init(subject: "Matematyka I", value: "4,0", ects: 6, date: "06.06.2026", lecturer: "dr K. Marek"),
        .init(subject: "Podstawy ekonomii", value: "4,5", ects: 6, date: "03.06.2026", lecturer: "dr J. Wójcik")
    ]
    let registrations: [Registration] = [
        .init(id: "finance", title: "Finanse przedsiębiorstw", details: "Ćwiczenia • grupa 12 • wt. 12:00", deadline: "20 listopada", capacity: "18 / 25 miejsc"),
        .init(id: "marketing", title: "Marketing", details: "Ćwiczenia • grupa 04 • czw. 10:00", deadline: "20 listopada", capacity: "21 / 25 miejsc"),
        .init(id: "strategy", title: "Zarządzanie strategiczne", details: "Konwersatorium • grupa 07 • pt. 12:00", deadline: "22 listopada", capacity: "14 / 20 miejsc")
    ]

    var weightedAverage: String {
        let numerator = grades.reduce(0.0) { result, grade in
            result + (Double(grade.value.replacingOccurrences(of: ",", with: ".")) ?? 0) * Double(grade.ects)
        }
        let denominator = grades.reduce(0) { $0 + $1.ects }
        return String(format: "%.2f", denominator == 0 ? 0 : numerator / Double(denominator)).replacingOccurrences(of: ".", with: ",")
    }
    var earnedECTS: Int { grades.reduce(0) { $0 + $1.ects } }
}

struct RootView: View {
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            DashboardView().tabItem { Label("Pulpit", systemImage: "house.fill") }.tag(0)
            TimetableView().tabItem { Label("Plan", systemImage: "calendar") }.tag(1)
            GradesView().tabItem { Label("Oceny", systemImage: "graduationcap.fill") }.tag(2)
            RegistrationsView().tabItem { Label("Zapisy", systemImage: "square.stack.3d.up.fill") }.tag(3)
            MoreView().tabItem { Label("Więcej", systemImage: "ellipsis.circle.fill") }.tag(4)
        }
    }
}

struct DemoLabel: View {
    var body: some View {
        Label("TRYB DEMO · DANE PRZYKŁADOWE", systemImage: "sparkles")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(.secondary)
    }
}

struct Surface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.primary.opacity(0.045)))
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.title3.weight(.bold)).padding(.top, 5)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).foregroundStyle(color).font(.title3)
                Text(value).font(.system(size: 29, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DemoLabel()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dzień dobry 👋").font(.largeTitle.bold())
                        Text("Twój semestr w jednym miejscu.").foregroundStyle(.secondary)
                    }
                    Surface {
                        HStack(spacing: 14) {
                            Image(systemName: "building.columns.fill")
                                .font(.title).foregroundStyle(Theme.accent)
                                .frame(width: 54, height: 54)
                                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Szkoła Główna Handlowa").font(.headline)
                                Text("Studia licencjackie · Semestr zimowy").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        StatTile(value: store.weightedAverage, label: "Średnia ważona", icon: "chart.line.uptrend.xyaxis", color: Theme.violet)
                        StatTile(value: "\(store.earnedECTS)", label: "Zdobyte ECTS (demo)", icon: "checkmark.seal.fill", color: Theme.mint)
                    }
                    SectionTitle(title: "Najbliższe zajęcia")
                    ForEach(store.lessons.prefix(2)) { lesson in LessonCard(lesson: lesson) }
                    SectionTitle(title: "Ważne terminy")
                    Surface {
                        VStack(spacing: 15) {
                            HStack(spacing: 13) {
                                Image(systemName: "calendar.badge.clock").font(.title2).foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Rejestracja na zajęcia").font(.subheadline.weight(.semibold))
                                    Text("20 listopada · termin demonstracyjny").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            Divider()
                            HStack(spacing: 13) {
                                Image(systemName: "doc.text.magnifyingglass").font(.title2).foregroundStyle(Theme.violet)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Ankiety dydaktyczne").font(.subheadline.weight(.semibold))
                                    Text("Przykładowa ankieta do wypełnienia").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("USOS SGH")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { ProfileView() } label: {
                        Image(systemName: "person.crop.circle.fill").font(.title2)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}

struct LessonCard: View {
    let lesson: Lesson
    var body: some View {
        Surface {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3).fill(lesson.color).frame(width: 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(lesson.subject).font(.headline)
                    Text("\(lesson.kind) · \(lesson.lecturer)").font(.caption).foregroundStyle(.secondary)
                    Label(lesson.room, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(lesson.start).font(.subheadline.weight(.bold).monospacedDigit())
                    Text(lesson.end).font(.caption).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TimetableView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var weekday = 1
    private let days = Array(1...7)
    private let labels = ["Pon", "Wt", "Śr", "Czw", "Pt", "Sob", "Nd"]
    private var matching: [Lesson] { store.lessons.filter { $0.weekday == weekday } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DemoLabel()
                    Text("Tydzień akademicki").font(.title2.weight(.bold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 9) {
                                ForEach(days, id: \.self) { day in
                                    Button {
                                        withAnimation(.snappy) { weekday = day }
                                    } label: {
                                        Text(labels[day - 1])
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 43, height: 46)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(weekday == day ? .regular.tint(Theme.accent.opacity(0.25)).interactive() : .regular, in: .rect(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    HStack {
                        SectionTitle(title: labels[weekday - 1])
                        Spacer()
                        Text("\(matching.count) zajęcia").font(.caption).foregroundStyle(.secondary)
                    }
                    if matching.isEmpty {
                        ContentUnavailableView("Brak zajęć", systemImage: "sun.max", description: Text("Ten dzień jest wolny w przykładowym planie."))
                    } else {
                        ForEach(matching) { LessonCard(lesson: $0) }
                    }
                    Surface {
                        Label("Plan jest przykładowy i nie jest połączony z Twoim kontem SGH.", systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("Plan zajęć")
        }
    }
}

struct GradesView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var selectedGrade: Grade?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DemoLabel()
                    HStack(spacing: 12) {
                        StatTile(value: store.weightedAverage, label: "Średnia ważona ECTS", icon: "chart.bar.fill", color: Theme.accent)
                        StatTile(value: "\(store.earnedECTS)", label: "Suma punktów ECTS", icon: "graduationcap.fill", color: Theme.mint)
                    }
                    SectionTitle(title: "Historia ocen")
                    ForEach(store.grades) { grade in
                        Button { selectedGrade = grade } label: {
                            Surface {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(grade.subject).font(.headline).foregroundStyle(.primary)
                                        Text("\(grade.ects) ECTS · \(grade.date)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(grade.value)
                                        .font(.title3.bold().monospacedDigit())
                                        .foregroundStyle(Theme.accent)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    Text("Średnia to obliczenie demonstracyjne ważone punktami ECTS; oficjalna metodologia uczelni może być inna.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("Oceny")
            .sheet(item: $selectedGrade) { grade in
                NavigationStack {
                    Form {
                        LabeledContent("Przedmiot", value: grade.subject)
                        LabeledContent("Ocena", value: grade.value)
                        LabeledContent("ECTS", value: "\(grade.ects)")
                        LabeledContent("Data", value: grade.date)
                        LabeledContent("Prowadzący", value: grade.lecturer)
                        Section { DemoLabel() }
                    }
                    .navigationTitle("Szczegóły oceny")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Gotowe") { selectedGrade = nil } } }
                }
            }
        }
    }
}

struct RegistrationsView: View {
    @EnvironmentObject private var store: DemoStore
    @State private var pending: Registration?
    @State private var showResult = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DemoLabel()
                    Surface {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.checkmark").font(.title2).foregroundStyle(Theme.mint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rejestracja demonstracyjna").font(.headline)
                                Text("Zmiany zapisów są lokalne. Nie trafiają do USOS.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    SectionTitle(title: "Dostępne grupy")
                    ForEach(store.registrations) { registration in
                        Surface {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(registration.title).font(.headline)
                                Text(registration.details).font(.subheadline).foregroundStyle(.secondary)
                                HStack {
                                    Label(registration.capacity, systemImage: "person.2")
                                    Spacer()
                                    Label(registration.deadline, systemImage: "calendar")
                                }.font(.caption).foregroundStyle(.secondary)
                                Button {
                                    pending = registration
                                } label: {
                                    Label(store.enrolled.contains(registration.id) ? "Wypisz (demo)" : "Zapisz (demo)", systemImage: store.enrolled.contains(registration.id) ? "minus.circle" : "plus.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                            }
                        }
                    }
                }.padding(18)
            }
            .background(Theme.paper)
            .navigationTitle("Rejestracje")
            .confirmationDialog("Operacja demonstracyjna", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
                Button("Potwierdź lokalną zmianę") {
                    if let registration = pending {
                        if store.enrolled.contains(registration.id) {
                            store.enrolled.remove(registration.id)
                        } else {
                            store.enrolled.insert(registration.id)
                        }
                    }
                    pending = nil
                    showResult = true
                }
                Button("Anuluj", role: .cancel) { pending = nil }
            } message: {
                Text("Nie zostanie wysłane żadne żądanie do USOS SGH.")
            }
            .alert("Zapisano w prototypie", isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Stan zapisano wyłącznie lokalnie na tym urządzeniu, bez połączenia z SGH.")
            }
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ExamsView() } label: { Label("Egzaminy i zaliczenia", systemImage: "pencil.and.list.clipboard") }
                    NavigationLink { PaymentsView() } label: { Label("Płatności", systemImage: "creditcard") }
                    NavigationLink { SurveysView() } label: { Label("Ankiety", systemImage: "checklist") }
                    NavigationLink { AcademicProgressView() } label: { Label("Tok studiów", systemImage: "books.vertical") }
                } header: { Text("Studia") }
                Section {
                    NavigationLink { ProfileView() } label: { Label("Profil studenta", systemImage: "person.crop.circle") }
                    NavigationLink { SettingsView() } label: { Label("Ustawienia", systemImage: "gearshape") }
                } header: { Text("Konto") }
                Section {
                    Link(destination: URL(string: "https://usosapps.sgh.waw.pl/developers/api/")!) {
                        Label("Dokumentacja USOS API SGH", systemImage: "link")
                    }
                    Label("Wersja 0.1 · prototyp offline", systemImage: "info.circle")
                } header: { Text("O aplikacji") }
            }
            .navigationTitle("Więcej")
        }
    }
}

struct ExamsView: View {
    var body: some View {
        List {
            Section("Przykładowe terminy") {
                DetailLine(title: "Statystyka", subtitle: "Egzamin pisemny · 22.01.2027, 09:00", icon: "doc.text")
                DetailLine(title: "Makroekonomia", subtitle: "Egzamin pisemny · 29.01.2027, 11:00", icon: "doc.text")
                DetailLine(title: "Prawo gospodarcze", subtitle: "Zaliczenie · 03.02.2027, 12:00", icon: "checkmark.circle")
            }
            Section { DemoLabel() }
        }.navigationTitle("Egzaminy")
    }
}

struct PaymentsView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Saldo przykładowe") { Text("0,00 zł").font(.title3.bold()).foregroundStyle(Theme.mint) }
            }
            Section("Historia demonstracyjna") {
                DetailLine(title: "Brak zaległości", subtitle: "Brak prawdziwego połączenia z kontem", icon: "checkmark.shield")
            }
            Section { Text("W prototypie nie można wykonywać płatności ani sprawdzać rzeczywistego salda.").font(.footnote) }
        }.navigationTitle("Płatności")
    }
}

struct SurveysView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        List {
            Section("Ankiety demonstracyjne") {
                ForEach(["Ocena zajęć – Mikroekonomia", "Ocena zajęć – Statystyka"], id: \.self) { title in
                    Button {
                        if store.completedSurveys.contains(title) { store.completedSurveys.remove(title) }
                        else { store.completedSurveys.insert(title) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title).foregroundStyle(.primary)
                                Text(store.completedSurveys.contains(title) ? "Oznaczono lokalnie" : "Dotknij, aby oznaczyć jako ukończoną").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: store.completedSurveys.contains(title) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }
            Section { DemoLabel() }
        }.navigationTitle("Ankiety")
    }
}

struct AcademicProgressView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        List {
            Section("Postęp demonstracyjny") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Zaliczone ECTS w danych testowych"); Spacer(); Text("\(store.earnedECTS) / 180").bold() }
                    ProgressView(value: Double(store.earnedECTS), total: 180).tint(Theme.mint)
                }.padding(.vertical, 6)
                DetailLine(title: "Studia pierwszego stopnia", subtitle: "Przykładowy tok sześciosemestralny", icon: "building.columns")
            }
            Section { DemoLabel() }
        }.navigationTitle("Tok studiów")
    }
}

struct ProfileView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 54)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Student SGH").font(.headline)
                        Text("Profil demonstracyjny").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            Section("Informacje") {
                LabeledContent("Uczelnia", value: "SGH w Warszawie")
                LabeledContent("Poziom", value: "Studia I stopnia")
                LabeledContent("Status", value: "Tryb demo")
            }
            Section { Text("Nie zapisujemy loginów ani haseł. Logowanie uczelniane będzie wymagało zatwierdzonej integracji z USOS API.").font(.footnote) }
        }.navigationTitle("Profil")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: DemoStore
    var body: some View {
        Form {
            Section("Preferencje") {
                Toggle("Przyszłe powiadomienia (demo)", isOn: $store.notificationsEnabled)
                Toggle("Tylko przyszłe wydarzenia (demo)", isOn: $store.showOnlyUpcoming)
            }
            Section("Dane") {
                LabeledContent("Źródło", value: "Dane lokalne")
                LabeledContent("Połączenie USOS", value: "Nieaktywne")
                Text("Ustawienia nie konfigurują powiadomień push ani synchronizacji z uczelnią.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Ustawienia")
    }
}

struct DetailLine: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 27)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    RootView()
        .environmentObject(DemoStore())
}
#endif
