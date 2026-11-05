# Gson 2.8.9 rules required by flutter_local_notifications 18.0.1:
# https://github.com/google/gson/blob/gson-parent-2.8.9/examples/android-proguard-example/proguard.cfg
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# R8 full mode must retain TypeToken and its subclasses, not only Signature.
# Keep these classes even when shrinking; their generic type is read at runtime.
-keep,allowobfuscation class com.google.gson.reflect.TypeToken { *; }
-keep,allowobfuscation class * extends com.google.gson.reflect.TypeToken
