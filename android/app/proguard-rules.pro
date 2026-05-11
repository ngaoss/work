# ML Kit Text Recognition rules
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Ignore missing optional language classes (Chinese, Japanese, Korean, Devanagari)
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**
