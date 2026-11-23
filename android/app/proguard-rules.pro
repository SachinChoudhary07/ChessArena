# R8 keep rules for the release build.
# Flutter and the Firebase plugins ship their own consumer rules; these cover
# the gaps that show up as crashes or missing-class errors in minified builds.

# Flutter engine and plugin registrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter references Play Core for deferred components, which this app does not use.
-dontwarn com.google.android.play.core.**

# flutter_local_notifications stores scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Firebase and Play services ship their own rules; keep the metadata they rely on.
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Image cropper (uCrop).
-dontwarn com.yalantis.ucrop.**
-keep class com.yalantis.ucrop.** { *; }
