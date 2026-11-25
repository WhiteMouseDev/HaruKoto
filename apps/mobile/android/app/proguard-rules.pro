# flutter_local_notifications uses Gson TypeToken for scheduled notification
# JSON. In R8 full mode the signature also needs rules for its endpoint classes.
-keepattributes Signature
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
