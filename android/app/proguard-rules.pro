# Owner, 29 Oct: the release build's shrinker (R8) dropped the constructor
# Room calls by reflection to open WorkManager's database (AdMob brings
# WorkManager), so WorkManager failed to start and closed the app at start.
# The সমস্যার লগ showed it: Class.getDeclaredConstructor from Room's builder.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class androidx.work.impl.** extends androidx.room.RoomDatabase { *; }
