# Subsumo – Flutter-Client

Eine Codebasis für **Android, iOS, Windows und Web** (macOS/Linux fallen ab).

## Start

```bash
cd app
flutter pub get

flutter run -d chrome                       # Web
flutter run -d windows                      # Windows
flutter run -d android                      # Android
flutter run -d ios                          # iOS

# Backend-Adresse überschreiben (Default: http://localhost:8000)
flutter run -d chrome --dart-define=SUBSUMO_API=http://192.168.1.20:8000
```

Die Plattformordner (`android/`, `ios/`, `windows/`, `web/`) sind bewusst nicht
eingecheckt – sie werden einmalig erzeugt:

```bash
flutter create . --platforms=android,ios,windows,web --org de.subsumo
```

## Stand

M0-Gerüst: Login, Dashboard mit Coverage, Karteikarten-Review gegen die echte
API, Schemata-Browser, Fallliste und Gutachten-Trainer mit Live-Strukturfeedback.

Noch offen (M1, siehe `../docs/03-roadmap.md`): Offline-Speicher mit drift,
Outbox-Sync, Riverpod als State-Management, Klausur-Simulator.
