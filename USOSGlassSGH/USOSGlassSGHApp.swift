import SwiftUI

@main
struct USOSGlassSGHApp: App {
    @StateObject private var store = CampusStore()
    @Environment(\.scenePhase) private var phase
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("onboarded.v2") private var onboarded = false
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .tint(Palette.accent)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .environment(\.locale, Locale(identifier: "pl_PL"))
                .environment(\.timeZone, CampusTime.calendar.timeZone)
                .sheet(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
                    WelcomeView { onboarded = true }
                }
                .alert("USOS Glass", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                    Button("OK") { store.message = nil }
                } message: { Text(store.message ?? "") }
                .task { await store.reconcileActivity(); await store.refresh() }
                .onChange(of: phase) { _, new in if new == .active { Task { await store.reconcileActivity() } } }
                .overlay {
                    if phase != .active {
                        ZStack { Palette.background.ignoresSafeArea(); Image(systemName: "graduationcap.fill").font(.system(size: 60)).foregroundStyle(Palette.accent) }
                    }
                }
        }
    }
}

enum Palette {
    static let accent = Color(red: 0.05, green: 0.48, blue: 0.39)
    static let ink = Color(red: 0.04, green: 0.17, blue: 0.17)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let tones: [Color] = [accent, .indigo, .orange, .blue]
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 26))
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(.secondary) }
}
struct SourceBadge: View {
    @EnvironmentObject var store: CampusStore
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(store.isDemo ? Color.orange : Palette.accent).frame(width: 6, height: 6)
            Text(store.isDemo ? "PODGLĄD · DANE DEMO" : "USOS SGH · ZAPIS LOKALNY")
                .font(.system(size: 9, weight: .bold)).tracking(1)
        }.padding(.horizontal, 12).padding(.vertical, 9).glassEffect(.regular, in: .capsule)
    }
}
struct RootView: View {
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            Tab("Dzisiaj", systemImage: "sun.max", value: 0) { TodayView() }
            Tab("Plan", systemImage: "calendar", value: 1) { ScheduleView() }
            Tab("Oceny", systemImage: "chart.bar.xaxis", value: 2) { GradesView() }
            Tab("Konto", systemImage: "person.crop.circle", value: 3) { AccountView() }
        }
        .onOpenURL { url in if url.scheme == "usosglass", url.host == "today" { selection = 0 } }
    }
}
struct WelcomeView: View {
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "graduationcap.fill").font(.system(size: 54)).foregroundStyle(Palette.accent)
                    .padding(26).background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 32))
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "USOS GLASS / SGH")
                    Text("Mniej szukania.\nWięcej studiowania.").font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-1.5)
                    Text("Twój plan, oceny i najbliższe zajęcia — w jednym spokojnym miejscu.").font(.title3).foregroundStyle(.secondary)
                }
                Label("Zajęcia na Dynamic Island", systemImage: "waveform.path")
                Label("Plan dostępny również offline", systemImage: "wifi.slash")
                Label("Logowanie na stronie uczelni", systemImage: "lock.shield")
                Text("Nieoficjalny klient. Na początek zobaczysz dane demo. Prawdziwe dane wymagają klucza aplikacji USOS SGH i autoryzacji w zakładce Konto.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(action: done) { Text("Odkryj aplikację").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12) }
                    .buttonStyle(.glassProminent)
            }.padding(28).padding(.top, 26)
        }.background(Palette.background).interactiveDismissDisabled()
    }
}
struct TodayView: View {
    @EnvironmentObject var store: CampusStore
    @State private var showTask = false
    @State private var detail: CampusEvent?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Eyebrow(text: CampusTime.string(Date(), "EEEE, d MMMM")); Spacer(); Image(systemName: "sparkle").foregroundStyle(Palette.accent) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.displayName + ".").font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-1.5)
                        Text(store.isDemo ? "Zobacz, jak może wyglądać Twój dzień." : "Wszystko, czego potrzebujesz na uczelni.").foregroundStyle(.secondary)
                    }
                    SourceBadge()
                    if let next = store.nextEvent {
                        Button { detail = next } label: { NextClassHero(event: next) }.buttonStyle(.plain)
                    } else {
                        Card {
                            Label("Masz chwilę dla siebie", systemImage: "leaf").font(.title2.bold())
                            Text("Brak nadchodzących zajęć w pobranym tygodniu. Sprawdź kolejny tydzień w Planie.").foregroundStyle(.secondary).padding(.top, 8)
                        }
                    }
                    HStack(spacing: 12) {
                        Metric(value: "\(store.events.filter { CampusTime.calendar.isDate($0.start, inSameDayAs: Date()) }.count)", label: "zajęcia dzisiaj", icon: "calendar", tint: Palette.accent)
                        Metric(value: "\(store.tasks.filter { !$0.done }.count)", label: "Twoje zadania", icon: "checkmark.circle", tint: .indigo)
                    }
                    HStack { Text("Twoje zadania").font(.title2.bold()); Spacer(); Button { showTask = true } label: { Image(systemName: "plus").frame(width: 36, height: 36) }.buttonStyle(.glass).accessibilityLabel("Dodaj zadanie") }
                    if store.tasks.isEmpty {
                        Card {
                            Label("Miejsce na Twój następny krok", systemImage: "checklist").font(.headline)
                            Text("Dodaj kolokwium, projekt albo przypomnienie o nauce. Zadania zapisują się tylko na telefonie.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.tasks.sorted { $0.due < $1.due }) { item in
                                TaskRow(item: item)
                            }
                        }
                    }
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(store.refreshed.map { "Ostatnia synchronizacja: " + CampusTime.string($0, "d MMM, HH:mm") } ?? "Dane przykładowe · połącz konto w zakładce Konto")
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(20).padding(.bottom, 24)
            }.background(Palette.background)
                .navigationTitle("USOS Glass").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { if store.busy { ProgressView() } else { Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.disabled(store.isDemo).accessibilityLabel("Odśwież dane USOS") } } }
                .refreshable { await store.refresh() }
                .sheet(isPresented: $showTask) { AddTaskView() }
                .sheet(item: $detail) { EventDetail(event: $0) }
        }
    }
}
struct NextClassHero: View {
    let event: CampusEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label(event.isDemo ? "NAJBLIŻSZE · DEMO" : "NAJBLIŻSZE ZAJĘCIA", systemImage: "circle.inset.filled").font(.system(size: 10, weight: .bold)).tracking(1.3)
                Spacer(); Image(systemName: "arrow.up.right").font(.headline)
            }.foregroundStyle(.white.opacity(0.8))
            Text(event.title).font(.system(size: 29, weight: .bold, design: .rounded)).tracking(-0.6).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(CampusTime.string(event.start, "EEE, d MMM")).font(.caption).foregroundStyle(.white.opacity(0.65))
                    Text(event.timeRange).font(.title2.bold().monospacedDigit())
                }
                Spacer()
                Text(event.room.isEmpty ? event.kind : "Sala \(event.room)").font(.subheadline.bold()).padding(12)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(colors: [Palette.ink, Color(red: 0.08, green: 0.36, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().stroke(.white.opacity(0.06), lineWidth: 45).frame(width: 230, height: 230).offset(x: 90, y: -85)
                    Circle().stroke(.white.opacity(0.05), lineWidth: 2).frame(width: 290, height: 290).offset(x: 60, y: -55)
                }.clipShape(RoundedRectangle(cornerRadius: 30))
            }
    }
}
struct Metric: View {
    let value: String; let label: String; let icon: String; let tint: Color
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(value).font(.system(size: 32, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
struct TaskRow: View {
    @EnvironmentObject var store: CampusStore
    let item: StudyTask
    var body: some View {
        HStack(spacing: 12) {
            Button { store.toggleTask(item.id) } label: { Image(systemName: item.done ? "checkmark.circle.fill" : "circle").font(.title2).frame(width: 44, height: 44) }
                .accessibilityLabel(item.done ? "Oznacz jako niezrobione" : "Ukończ zadanie")
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline.weight(.semibold)).strikethrough(item.done).foregroundStyle(item.done ? .secondary : .primary)
                Text(CampusTime.string(item.due, "d MMM, HH:mm")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu { Button("Usuń zadanie", role: .destructive) { store.deleteTask(item.id) } } label: { Image(systemName: "ellipsis").frame(width: 36, height: 44) }.accessibilityLabel("Opcje zadania")
        }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct AddTaskView: View {
    @EnvironmentObject var store: CampusStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var due = Date().addingTimeInterval(86400)
    var body: some View {
        NavigationStack {
            Form {
                Section("Co chcesz zrobić?") { TextField("Np. powtórzyć rozdział 2", text: $title); DatePicker("Termin", selection: $due) }
                Section { Text("Prywatne zadanie lokalne. Nie trafia do USOS i nie wysyła powiadomienia.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Nowe zadanie").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Dodaj") { store.addTask(title: title, due: due); dismiss() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }.presentationDetents([.medium, .large])
    }
}
struct ScheduleView: View {
    @EnvironmentObject var store: CampusStore
    @State private var selected = CampusTime.calendar.startOfDay(for: Date())
    @State private var detail: CampusEvent?
    private var days: [Date] { (0..<7).map { CampusTime.calendar.date(byAdding: .day, value: $0, to: store.weekStart)! } }
    private var selectedEvents: [CampusEvent] { store.events.filter { CampusTime.calendar.isDate($0.start, inSameDayAs: selected) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SourceBadge()
                    HStack {
                        Button { Task { await store.changeWeek(by: -1); selected = store.weekStart } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(store.busy).accessibilityLabel("Poprzedni tydzień")
                        Spacer(); Text(CampusTime.string(store.weekStart, "d MMM") + " – " + CampusTime.string(days.last!, "d MMM yyyy")).font(.headline); Spacer()
                        Button { Task { await store.changeWeek(by: 1); selected = store.weekStart } } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(store.busy).accessibilityLabel("Następny tydzień")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(days, id: \.self) { day in
                                Button { selected = day } label: {
                                    VStack(spacing: 10) {
                                        Text(CampusTime.string(day, "EEEEE").uppercased()).font(.caption2.bold())
                                        Text(CampusTime.string(day, "d")).font(.title3.bold())
                                        Circle().fill(store.events.contains { CampusTime.calendar.isDate($0.start, inSameDayAs: day) } ? Color.primary : Color.clear).frame(width: 4, height: 4)
                                    }.frame(width: 44).padding(.vertical, 14)
                                        .foregroundStyle(CampusTime.calendar.isDate(day, inSameDayAs: selected) ? Color.white : Color.primary)
                                        .background(CampusTime.calendar.isDate(day, inSameDayAs: selected) ? Palette.accent : Palette.card, in: Capsule())
                                }.buttonStyle(.plain).accessibilityLabel(CampusTime.string(day, "EEEE, d MMMM"))
                            }
                        }
                    }
                    HStack { Text(CampusTime.string(selected, "EEEE").capitalized).font(.title2.bold()); Spacer(); Text("\(selectedEvents.count) zajęć").font(.subheadline).foregroundStyle(.secondary) }
                    if store.busy { ProgressView("Synchronizuję plan…").frame(maxWidth: .infinity).padding(30) }
                    else if selectedEvents.isEmpty {
                        ContentUnavailableView("Wolna przestrzeń", systemImage: "cup.and.saucer", description: Text("Brak zajęć w zapisanym planie na ten dzień."))
                    } else {
                        VStack(spacing: 14) {
                            ForEach(selectedEvents) { event in
                                Button { detail = event } label: { EventRow(event: event) }.buttonStyle(.plain)
                            }
                        }
                    }
                    Button { Task { await store.scheduleReminders() } } label: { Label("Przypomnij 15 min przed zajęciami", systemImage: "bell.badge").frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.glass)
                    Text("Godziny według strefy Warszawy. Przypomnienia obejmują tylko wyświetlany tydzień i wymagają ponownego ustawienia po zmianach planu.").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Palette.background).navigationTitle("Twój tydzień")
                .refreshable { await store.refresh() }
                .sheet(item: $detail) { EventDetail(event: $0) }
                .onAppear { if !days.contains(where: { CampusTime.calendar.isDate($0, inSameDayAs: selected) }) { selected = store.weekStart } }
        }
    }
}
struct EventRow: View {
    let event: CampusEvent
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(CampusTime.string(event.start, "HH:mm")).font(.headline.monospacedDigit())
                Text(CampusTime.string(event.end, "HH:mm")).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.frame(width: 52, alignment: .leading)
            RoundedRectangle(cornerRadius: 3).fill(Palette.tones[event.tintIndex]).frame(width: 4)
            VStack(alignment: .leading, spacing: 7) {
                Text(event.kind.uppercased()).font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(Palette.tones[event.tintIndex])
                Text(event.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Label(event.location.isEmpty ? "Sala niepodana" : event.location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                if event.tentative { Text("Termin do potwierdzenia w USOS").font(.caption2).foregroundStyle(.orange) }
            }
            Spacer(minLength: 0)
        }.padding(18).background(Palette.card, in: RoundedRectangle(cornerRadius: 24)).fixedSize(horizontal: false, vertical: true)
    }
}
struct EventDetail: View {
    @EnvironmentObject var store: CampusStore
    @Environment(\.dismiss) var dismiss
    let event: CampusEvent
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NextClassHero(event: event)
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Label(CampusTime.string(event.start, "EEEE, d MMMM yyyy"), systemImage: "calendar")
                            Label(event.kind, systemImage: "books.vertical")
                            Label(event.location.isEmpty ? "Lokalizacja niepodana" : event.location, systemImage: "mappin.and.ellipse")
                            if event.tentative { Label("Potwierdź termin w USOS — spotkanie może być nieregularne.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                        }.font(.subheadline)
                    }
                    Button { Task { await store.startActivity(event) } } label: { Label("Pokaż na Dynamic Island", systemImage: "waveform.path").frame(maxWidth: .infinity).padding(.vertical, 10) }.buttonStyle(.glassProminent)
                    Text("Uruchom maksymalnie godzinę przed zajęciami. Sala i odliczanie pojawią się też na ekranie blokady. Zmiany planu nie aktualizują się w tle.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Palette.background).navigationTitle("Szczegóły zajęć").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
        }
    }
}
struct GradesView: View {
    @EnvironmentObject var store: CampusStore
    @State private var search = ""
    @State private var term = "Wszystkie"
    private var terms: [String] { ["Wszystkie"] + Array(Set(store.grades.map(\.term))).sorted().reversed() }
    private var filtered: [CampusGrade] { store.grades.filter { (term == "Wszystkie" || $0.term == term) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SourceBadge()
                    HStack(spacing: 12) {
                        Metric(value: store.average, label: "średnia wyświetlonych ocen*", icon: "chart.xyaxis.line", tint: Palette.accent)
                        Metric(value: "\(store.grades.filter(\.passes).count)", label: "ocen zaliczających", icon: "checkmark.seal", tint: .indigo)
                    }
                    Text("*Orientacyjna średnia arytmetyczna wszystkich pobranych ocen liczbowych z ostatnich 365 dni, także poprawek. Nie jest oficjalną średnią SGH ani średnią ważoną ECTS.").font(.caption).foregroundStyle(.secondary)
                    Picker("Cykl dydaktyczny", selection: $term) { ForEach(terms, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    if filtered.isEmpty { ContentUnavailableView("Brak ocen", systemImage: "graduationcap", description: Text("Brak wyników dla wybranego filtra w pobranych danych.")) }
                    ForEach(filtered) { grade in
                        Card {
                            HStack(spacing: 16) {
                                Text(grade.value_symbol).font(.system(size: 27, weight: .bold, design: .rounded))
                                    .foregroundStyle(grade.passes ? Palette.accent : Color.red)
                                    .frame(minWidth: 54, minHeight: 54)
                                    .background((grade.passes ? Palette.accent : Color.red).opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(grade.title).font(.headline)
                                    Text(grade.term + " · termin " + grade.exam_session_number.value).font(.caption).foregroundStyle(.secondary)
                                    if let date = grade.date_modified { Text("Aktualizacja: " + date).font(.caption2).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }.padding(20)
            }.background(Palette.background).navigationTitle("Twoje wyniki")
                .searchable(text: $search, prompt: "Znajdź przedmiot")
                .refreshable { await store.refresh() }
                .onChange(of: store.isDemo) { _, _ in term = "Wszystkie" }
        }
    }
}
struct AccountView: View {
    @EnvironmentObject var store: CampusStore
    @AppStorage("appearance") private var appearance = "system"
    @State private var showLogin = false
    @State private var confirmLogout = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 52)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.student?.fullName ?? "Twój profil SGH").font(.headline)
                            Text(store.hasConnection ? "Połączono z USOS SGH" : "Oglądasz dane demonstracyjne").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    if !store.hasConnection { Button("Połącz z USOS SGH") { showLogin = true } }
                    else { Button("Synchronizuj dane") { Task { await store.refresh() } }.disabled(store.busy) }
                }
                Section("Dynamic Island") {
                    Button { Task { await store.demoActivity() } } label: { Label("Testuj odliczanie · demo 15 min", systemImage: "waveform.path") }
                    Button { Task { await store.endActivities() } } label: { Label("Zakończ aktywność", systemImage: "stop.circle") }
                    Text("Wybierz zajęcia w Planie, aby uruchomić ich aktywność. W AltStore zachowaj rozszerzenie aplikacji. Po upływie czasu widok staje się nieaktualny; po powrocie do aplikacji zostanie usunięty.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Wygląd") {
                    Picker("Motyw", selection: $appearance) {
                        Text("Systemowy").tag("system"); Text("Jasny").tag("light"); Text("Ciemny").tag("dark")
                    }
                }
                Section("Prywatność i powiadomienia") {
                    Label("Tokeny w pęku kluczy iPhone’a", systemImage: "lock.shield")
                    Label("Brak reklam i analityki", systemImage: "hand.raised")
                    Button("Usuń zaplanowane przypomnienia") { Task { await store.clearReminders(); store.message = "Usunięto przypomnienia aplikacji." } }
                    if store.hasConnection { Button("Wyloguj i usuń dane lokalne", role: .destructive) { confirmLogout = true }.disabled(store.busy) }
                }
                Section("Uczelnia") {
                    Link("Otwórz USOSweb SGH", destination: URL(string: "https://usosweb.sgh.waw.pl/")!)
                    Link("Zarządzaj dostępem w USOSapps", destination: URL(string: USOSClient.base)!)
                }
                Section {
                    Text("USOS Glass 0.2 · niezależny klient studencki. Integracja wymaga własnego klucza USOS SGH. Rejestracje, płatności i ankiety obsługuj w USOSweb. Aplikacja pobiera profil, tygodniowy plan oraz oceny zmienione w ostatnim roku.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Po Twojemu")
                .sheet(isPresented: $showLogin) { LoginView() }
                .confirmationDialog("Wylogować i usunąć plan, oceny oraz zadania z tego telefonu?", isPresented: $confirmLogout, titleVisibility: .visible) {
                    Button("Wyloguj i usuń", role: .destructive) { Task { await store.logout() } }
                }
        }
    }
}
struct LoginView: View {
    @EnvironmentObject var store: CampusStore
    @Environment(\.dismiss) var dismiss
    @State private var key = ""
    @State private var secret = ""
    @State private var pin = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Połącz swoje studia", systemImage: "building.columns.fill").font(.title2.bold())
                    Text("Logujesz się wyłącznie na stronie SGH. Aplikacja otrzyma zgodę na odczyt planu, ocen i profilu.")
                }
                if !store.authorizationPending {
                    Section {
                        SecureField("Consumer Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Consumer Secret", text: $secret).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Link("Uzyskaj klucz w USOSapps SGH", destination: URL(string: USOSClient.base + "developers/")!)
                    } header: { Text("1. Klucz Twojej aplikacji") } footer: {
                        Text("To klucz deweloperski wydany dla SGH, nie numer albumu ani hasło. Własny klucz wpisujesz tylko tutaj. Nigdy nie umieszczaj go na GitHubie. Bez klucza dostępny jest tryb demo.")
                    }
                    Section {
                        Button("Rozpocznij autoryzację") { Task { await store.beginLogin(key: key, secret: secret) } }
                            .disabled(store.busy || key.isEmpty || secret.isEmpty)
                    }
                } else {
                    Section("2. Zgoda na stronie uczelni") {
                        if let url = store.authorizationURL { Link("Otwórz bezpieczne logowanie SGH", destination: url) }
                        Text("Po zaakceptowaniu dostępu skopiuj kod PIN wyświetlony przez USOS i wróć do aplikacji.").font(.footnote)
                    }
                    Section("3. Potwierdzenie") {
                        TextField("Kod PIN z USOS", text: $pin).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Połącz konto") { Task { await store.completeLogin(pin: pin); if store.hasConnection { key = ""; secret = ""; pin = ""; dismiss() } } }.disabled(store.busy || pin.isEmpty)
                        Button("Zacznij od nowa") { store.cancelLogin(); pin = "" }.disabled(store.busy)
                    }
                }
                if store.busy { Section { ProgressView("Łączę z SGH…") } }
            }.navigationTitle("Połączenie z USOS").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zamknij") { store.cancelLogin(); dismiss() }.disabled(store.busy) } }
                .interactiveDismissDisabled(store.busy)
        }
    }
}
