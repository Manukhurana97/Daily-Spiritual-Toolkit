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
-dontwarn kotlin.**

# - Firebase + Google Sign-In -
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.auth.** { *; }

# - Google Mobile Abs (AdMob) -
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# - General -
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile