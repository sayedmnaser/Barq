## ML Kit text recognition: optional script libs (Chinese/Japanese/Korean/Devanagari)
## not bundled — keep R8 from failing on missing references.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

## Flutter / Play Core (deferred components) — typical Flutter R8 fix
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.** { *; }
