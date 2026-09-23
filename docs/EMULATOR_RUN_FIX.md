# แก้ flutter run -d emulator-5554 — 2026-09-23

ผลล่าสุด: **BUILD / INSTALL / LAUNCH ผ่าน** บน Android 16 API 36 emulator-5554
Flutter 3.47.5, Dart 3.13.4, Android Studio JBR 25, Gradle 9.1.0, AGP 9.0.1

## สาเหตุและสิ่งที่แก้

1. ไม่มี NDK 28.2.13676358 ที่ Flutter ต้องใช้ และ sdkmanager.bat ของ Android CLI รุ่นใหม่ติดตั้งอัตโนมัติไม่ผ่าน (`Package ndk not found`, `Package 28.2.13676358 not found`). ติดตั้ง NDK รุ่นที่ต้องใช้โดยตรงด้วย `android.exe sdk install ndk/28.2.13676358` และตรวจ source.properties/package.xml แล้ว Build ผ่านจุดนี้ได้
2. permission_handler_android 14.1.0 ต้อง compile กับ API 37 จึงตั้ง `compileSdk = 37` ใน android/app/build.gradle.kts โดยไม่เปลี่ยน targetSdk 36 หรือ minSdk 24
3. Kotlin incremental compiler ของ device_info_plus/location เกิด `this and base files have different roots` เพราะ Pub Cache อยู่ C: แต่โปรเจกต์อยู่ D: จึงเพิ่ม `kotlin.incremental=false` ใน android/gradle.properties และล้างเฉพาะ build/device_info_plus/kotlin กับ build/location/kotlin ก่อน build ใหม่ ไม่แก้ Pub Cache และไม่ downgrade dependency
4. Gradle ติดตั้ง Android Platform 34 เพิ่มให้ Nearby plugin สำเร็จ

## รันครั้งต่อไป

```powershell
cd 'D:\3-1\project_keeratiburt\miniProject\rescuelink'
flutter run -d emulator-5554
```

โปรเจกต์ย้ายมา path ภาษาอังกฤษแล้ว และ Flutter/Dart อยู่ PATH สามารถใช้คำสั่งตรง ๆ ได้ ไม่ต้องใช้ drive alias สำหรับ environment นี้

APK ที่สร้างสำเร็จ: build/app/outputs/flutter-apk/app-debug.apk

## ผลตรวจ

- flutter analyze: No issues found!
- flutter test: All tests passed! (13 tests)
- flutter run -d emulator-5554: Built app-debug.apk, ติดตั้งสำเร็จ, Flutter VM Service เชื่อมต่อสำเร็จ และแอปทำงานบน emulator
- ยังมี warning ที่ไม่หยุด build เช่น KGP ของ location และ deprecated APIs ใน Nearby plugin
- ปิดเฉพาะ Kotlin incremental compilation จึงอาจ compile Kotlin ช้าลง; Dart hot reload และ Gradle caching ยังคงใช้ได้
- การเปิดแอปบน emulator ไม่ใช่หลักฐานว่า Nearby offline A ↔ B ผ่าน ต้องทดสอบบนโทรศัพท์ Android จริงสองเครื่องตาม PHYSICAL_TEST.md
