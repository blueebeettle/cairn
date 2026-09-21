# Cairn release-build ProGuard/R8 rules.
#
# Shrinking (removing unused code/resources) is what gets the APK size down;
# obfuscation is left off for now so a library that leans on reflection
# doesn't break silently with no build/test loop available to catch it here.
# Re-enable by deleting the next line once a real release build has been
# smoke-tested end to end (see the verification checklist this shipped with).
-dontobfuscate

# Flutter's own embedding classes.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# flutter_local_notifications — reflectively looks up notification icon
# resources and the app's own broadcast receivers.
-keep class com.dexterous.** { *; }
-keep class * extends android.app.Notification { *; }

# Supabase (gotrue / postgrest / realtime) — JSON (de)serialization used by
# these packages can reach model classes reflectively.
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Kotlin coroutines / serialization, pulled in transitively by several
# plugins above.
-keepclassmembers class kotlinx.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# sqlite3 (Drift's native backend) — JNI entry points.
-keep class io.sqlite3.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# file_picker / share_plus — reflectively resolve the FileProvider
# authority from the manifest.
-keep class androidx.core.content.FileProvider { *; }
-keep class * extends androidx.core.content.FileProvider { *; }

# Play Core (referenced by some plugin versions for deferred components even
# when this app doesn't use dynamic feature delivery) — silence, don't keep.
-dontwarn com.google.android.play.core.**

# General safety net: warnings, not errors, for anything else unresolved at
# shrink time rather than failing the build over a class only reachable from
# an unused code path.
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
