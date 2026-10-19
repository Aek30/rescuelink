Vendored video_thumbnail 0.5.6 (upstream MIT license retained).
Android uses the host Android Gradle plugin and repositories instead of obsolete jcenter()/AGP 4.1.0. Dart SDK upper bound updated for Dart 3. Runtime Dart/Java/ObjC implementation unchanged.
Android manifest namespace is declared only in build.gradle for current AGP compatibility.
compileSdk raised to 37 to match the host and satisfy AndroidX metadata; minSdk unchanged.
