/// `AppTheme` used to be defined twice — once here and once in
/// `themeData.dart` (which `main.dart` actually wires up). Both declared the
/// same class name with the same brand constants, which happened to work by
/// accident but left two sources of truth. `themeData.dart` is the real one
/// (it also carries the app's `TextTheme`/`DatePickerTheme` overrides, plus
/// the `StatusColors`/`AppShadows`/`AppRadius` tokens from the Mobo UI Style
/// Guide), so this file now just re-exports it and keeps every existing
/// `import '.../app_theme.dart'` working unchanged.
library;

export 'themeData.dart';
