# ringapp ProGuard Rules

# Keep BLE related classes
-keep class com.ringapp.RingBLEManager$** { *; }
-keep class com.ringapp.SoundCategory { *; }
-keep class com.ringapp.SoundTypeParser { *; }

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
