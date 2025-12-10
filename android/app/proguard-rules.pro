# 不混淆 Shizuku 相关类
-keep class rikka.shizuku.** { *; }
-keep class moe.shizuku.** { *; }

# 不混淆反射调用的类
-keep class android.hardware.input.InputManager { *; }
-keep class android.view.InputDevice { *; }
-keep class android.view.MotionEvent { *; }
-keep class android.view.KeyEvent { *; }

# 保留Flutter相关
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留GSON等序列化需要的类
-keepattributes Signature
-keepattributes *Annotation*

# 保留Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Google Play Core (deferred components) - 忽略缺失的类
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
