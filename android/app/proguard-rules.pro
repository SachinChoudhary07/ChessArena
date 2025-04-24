# Razorpay SDK - Prevent R8 from removing or renaming important classes
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Preserve annotation classes used internally by Razorpay SDK
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers

# Sometimes helpful for Flutter plugins in general
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.plugin.**
