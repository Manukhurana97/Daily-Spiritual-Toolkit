# - Flutter -
-keep class io.Flutter.** { *; }
-keep class io.Flutter.plugina.** { *; }
-dontwarn io.flutter.embedding.**

# - Revenuecat -
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**

# - Google Play Billing -
-keep class com.android.vending.billing.** { *; }

# - kotlin Serialization (used by Revenue Cat) -
-keepattributes *Annotation*
-keep class kotlin.Metadata { *; }
--dontwarn kotlin.**

# - General -
-keepattributes SourceFile,LineNumberTable
-renamesourcefuleattribute SourceFile