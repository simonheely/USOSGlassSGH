# USOS Glass SGH · 0.2

Nieoficjalny natywny klient iOS 26+, SwiftUI. Motyw jasny/ciemny, Liquid Glass, plan tygodnia, oceny, własne zadania, lokalne przypomnienia i Live Activities / Dynamic Island.

## Stan integracji

Zaimplementowano OAuth 1.0a (HMAC-SHA1, autoryzacja PIN na stronie uczelni) i odczyt profilu, planu oraz ocen zmienionych w ostatnich 365 dniach. **Połączenie z kontem SGH wymaga własnego Consumer Key / Consumer Secret wydanego przez SGH i zgody użytkownika.** Nie ma zaszytych kluczy ani haseł. Podczas implementacji serwer SGH zwracał HTTP 503; integracja z rzeczywistym kontem nie została przetestowana. Dane demo są jawnie oznaczone. To nie jest oficjalna aplikacja SGH.

1. Uzyskaj klucz dla własnej aplikacji: https://usosapps.sgh.waw.pl/developers/ . Gdy rejestracja nie jest dostępna, skontaktuj się z administracją USOS SGH.
2. Konto → Połącz z USOS SGH → wpisz klucz i sekret **na swoim telefonie**, nigdy na GitHubie.
3. Otwórz logowanie uczelni, udziel dostępu studies i grades, wróć z kodem PIN.
4. Aplikacja wymieni PIN na token i pobierze dane. Jeśli uczelnia nie udostępnia wymaganych metod/uprawnień, pokaże błąd zamiast fikcyjnych wyników.

To osobisty klient: do publicznej dystrybucji należy przygotować backend chroniący wspólny sekret aplikacji. Nie osadzaj wspólnego sekretu w pliku IPA. Dokumentacja: https://usosapps.demo.usos.edu.pl/developers/api/authorization/ .

## Dynamic Island

Konto → Testuj odliczanie albo Plan → zajęcia → Pokaż na Dynamic Island. Rozszerzenie `CampusLiveActivity` jest częścią IPA. W AltStore zachowaj rozszerzenie (Keep App Extensions); używa dodatkowego App ID. Nie wymaga APNs ani App Groups. Włącz Aktywności na żywo w ustawieniach systemowych. Ostateczne działanie zależy od podpisu i ustawień urządzenia i wymaga próby na iPhonie. Uruchamianie jest ręczne, do godziny przed zajęciami. Stale date oznacza koniec zajęć, lokalne zakończenie działa w aktywnej aplikacji; po ponownym otwarciu usuwane są zakończone aktywności. Nie ma serwerowych aktualizacji w tle.

## Instalacja bez płatnego konta Apple

Actions → Build downloadable iPhone IPA → udane uruchomienie → Artifacts → USOSGlassSGH-iPhone-IPA. Rozpakuj ZIP, zainstaluj `.ipa` przez AltStore Classic i Windows. Odnawiaj podpis przed upływem 7 dni. Zachowaj rozszerzenie Live Activity.

Oficjalna instrukcja: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows . Niepodpisany IPA nie instaluje się bezpośrednio w Safari. Kompilacje w standardowym GitHub Actions publicznego repozytorium nie wymagają płatnego Apple Developer.

## Budowanie i testy

`project.yml` jest źródłem konfiguracji. Na Macu: `brew install xcodegen`, `xcodegen generate`, otwórz wygenerowany projekt. GitHub Actions generuje projekt, uruchamia testy na symulatorze, buduje aplikację i rozszerzenie dla iPhone'a, weryfikuje pakiet i wystawia IPA. Wymagany Xcode 26 lub nowszy.

Testy: podpis OAuth ze znanym wektorem RFC 5849, kodowanie parametrów i tokenów, daty warszawskie, nieznane typy zajęć, odrzucanie błędnych dat, różne typy ID ocen i oddzielenie danych demo.

## Prywatność i ograniczenia

- Klucz i token: Keychain `WhenUnlockedThisDeviceOnly`. Hasła uczelni nie są przechwytywane.
- Plan, oceny, profil i zadania: pliki z pełną ochroną danych i wyłączeniem kopii zapasowej. Brak analityki. Ekran zasłaniany po przejściu aplikacji w tło.
- HTTP: HTTPS, pamięć podręczna sieciowa wyłączona, przekierowania podpisanych zapytań blokowane. Brak sekretów w logach.
- Wylogowanie próbuje unieważnić token, usuwa dane lokalne, przypomnienia i aktywności. Gdy serwer nie odpowiada, informuje o konieczności cofnięcia dostępu na stronie uczelni.
- Synchronizacja atomowa: nie miesza nowych i starych sekcji po błędzie. Jednorazowo pobiera wybrany tydzień; dane offline mają datę aktualizacji.
- Średnia jest orientacyjna, arytmetyczna, uwzględnia pobrane oceny liczbowe i poprawki. Nie jest oficjalną średnią SGH.
- Lokalne przypomnienia ustawiasz osobno dla tygodnia. Zmiana planu wymaga ich ponownego ustawienia.
- Rejestracje, płatności, ankiety: dostęp przez odnośnik do oficjalnego USOSweb, bez symulowania operacji.
