# Barq hotfix notes

Most of the red errors happen when `pubspec.yaml` is copied into `lib/` instead of the project root.

Correct structure:

```
barq/
  pubspec.yaml
  analysis_options.yaml
  assets/
    images/white_mod.png
  lib/
    main.dart
    services/...
    widgets/...
    models/...
```

Then run:

```bash
flutter clean
flutter pub get
flutter run --dart-define=POCKETBASE_URL=http://YOUR_IP:8090
```

Also delete this wrong leftover if it exists:

```
lib/pubspec.yaml
```

The package name in this hotfix is `barq`, so the default test import `package:barq/main.dart` works.
