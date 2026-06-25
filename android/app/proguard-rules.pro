# ProGuard rules
# 保留 PyTorch native 方法
-keep class org.pytorch.** { *; }
-keep class com.facebook.jni.** { *; }
