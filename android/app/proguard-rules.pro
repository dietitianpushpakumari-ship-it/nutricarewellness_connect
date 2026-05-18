# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Cloudinary / HTTP
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Gson / JSON
-keep class com.google.gson.** { *; }
-keepattributes Signature

# Keep model classes
-keep class * extends java.io.Serializable { *; }

# Keep annotations
-keepattributes *Annotation*