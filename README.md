# RescueLink — Phase 1 / Week 2

Flutter Android Technical POC: ค้นหา → เชื่อมต่อ → ส่งข้อความ UTF-8 แบบ offline ผ่าน Google Nearby Connections Bytes Payload

**สถานะ: เขียนโค้ดแล้ว แต่ยังไม่ผ่านเกณฑ์ทดสอบบน Android จริงสองเครื่อง**
อัปเดตล่าสุด: ติดตั้ง Android SDK/NDK แล้ว และ build/install/เปิดแอปบน emulator-5554 สำเร็จ ดู [รายละเอียดการแก้และคำสั่งรัน](docs/EMULATOR_RUN_FIX.md) ยังไม่ได้ยืนยันผล radio/device-to-device บนโทรศัพท์จริงสองเครื่อง ห้ามเริ่ม Phase 2 จนกว่าจะทำ checklist ด้านล่างผ่าน

## ไฟล์และหน้าที่

| ไฟล์ | หน้าที่ |
| --- | --- |
| `lib/main.dart` | เริ่มแอป Material 3, theme navy/blue |
| `lib/models/nearby_device.dart` | endpoint ID, ชื่อ, available/connecting/connected |
| `lib/services/permission_service.dart` | ตรวจ Android SDK version, runtime permissions, Location service, Bluetooth radio; คืน true/false และคำอธิบาย error |
| `lib/services/nearby_service.dart` | advertising/discovery, connection callbacks, auto-accept, timeout, bytes UTF-8, disconnect, cleanup และ System Log |
| `lib/screens/nearby_test_screen.dart` | หน้าเดียว: ชื่อเครื่อง, permissions, ปุ่มควบคุม, รายชื่ออุปกรณ์, chat, logs และ lifecycle |
| `lib/widgets/device_tile.dart` | รายการอุปกรณ์และปุ่ม Connect/Disconnect |
| `android/app/src/main/AndroidManifest.xml` | permissions และชื่อแอป RescueLink |
| `android/gradle.properties` | อนุญาต path Windows ที่มีอักษรไทย; คงค่า Gradle จาก Flutter template |
| `pubspec.yaml` / `pubspec.lock` | dependencies และรุ่นที่ resolve จริง |
| `test/nearby_service_test.dart` | ทดสอบ logic ด้วย fake native transport; ไม่ใช่ผลทดสอบมือถือจริง |
| `tool/flutter.ps1` | เรียก Flutter กับไฟล์เดิมผ่าน temporary ASCII drive alias แล้วลบ alias เมื่อจบ |
| `docs/PHYSICAL_TEST.md` | checklist/ตารางบันทึกผลทดสอบสองเครื่อง |

โครงสร้าง Android อื่น ๆ เช่น MainActivity, Gradle wrapper และ resource มาจาก `flutter create --platforms=android --org com.rmutt rescuelink` ไม่มี platform web/desktop/iOS

## Packages

- `nearby_connections: ^4.3.0` → resolve 4.3.0 (ใช้ native Google Play services Nearby 19.2.0 ของ package)
- `permission_handler: ^13.0.2`
- `location: ^10.0.2` — ใช้ตรวจ/ขอเปิด Location service เท่านั้น ไม่อ่านพิกัด
- `device_info_plus: ^13.2.0` — อ่าน Android API level เพื่อเลือก permission
- Flutter SDK และ `flutter_lints: ^6.0.0`; `flutter_test` ใช้ตรวจ logic

ใช้ `Strategy.P2P_CLUSTER` และ `serviceId = com.rmutt.rescuelink` เหมือนกันทุกเครื่อง ไม่มี Firebase, login, local database, SOS, mesh relay หรือ Cloud Sync

## Android permissions

| Android API | Runtime permission |
| --- | --- |
| 24–30 (Android 7–11) | Location while in use (Fine + Coarse declarations) |
| 31–32 (Android 12/12L) | Location แบบ precise และ Bluetooth advertise/connect/scan |
| 33–36 (Android 13–16) | Bluetooth advertise/connect/scan และ Nearby Wi-Fi Devices |

Manifest เพิ่ม `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `NEARBY_WIFI_DEVICES`

เหตุผลที่ปรับจาก XML ตัวอย่าง:

- Bluetooth เดิมจำกัด maxSdk 30; Location จำกัด maxSdk 32 เพราะ API 32 คือ Android 12L ส่วน Nearby Wi-Fi runtime permission เริ่ม API 33
- ประกาศ coarse และ fine คู่กันสำหรับ precise permission บน Android 12 ไม่กำหนด coarse maxSdk 28
- คง Wi-Fi state permissions แบบไม่จำกัด maxSdk ตาม plugin 4.3.0 ที่ใช้; เป็น normal permissions ไม่แสดง runtime dialog
- ใช้ `neverForLocation` กับ Bluetooth scan และ Nearby Wi-Fi เพราะ Phase 1 ไม่อนุมานพิกัดจากการสแกน
- ใช้ manifest merger `tools:node="replace"` เพื่อจำกัด Location/Bluetooth declarations จาก dependencies
- ไม่ขอ storage, background location หรือ foreground service permissions; ลบ declarations ที่ไม่ใช้จาก manifest merger
- Flutter template ปัจจุบัน compile/target SDK 36 และ minSdk 24 จึงยังไม่ต้องใช้ `ACCESS_LOCAL_NETWORK` สำหรับ target SDK 37+ ต้องตรวจใหม่ก่อนอัปเกรด target เป็น 37
- debug/profile template มี INTERNET เพื่อเครื่องมือ Flutter debugger; chat ไม่ใช้ HTTP/server หรืออินเทอร์เน็ต

แอปขอ permission ก่อน Advertising/Discovery/Connect ทุกครั้ง เมื่อปฏิเสธจะมีข้อความบนหน้าจอ ปุ่ม APP SETTINGS ใช้กรณีปฏิเสธถาวร และ Location service ต้องเปิดตามคำแนะนำ package เพื่อความเสถียร

## Environment และผลตรวจเดิม (ก่อนติดตั้ง SDK; ดูผลล่าสุดใน EMULATOR_RUN_FIX.md)

ตรวจบน Windows วันที่ 2026-09-23:

- Flutter stable 3.44.6 ที่ `D:\app\flutter`, Dart 3.12.2
- `flutter doctor -v`: Flutter ใช้ได้ แต่ binary ยังไม่อยู่ PATH; **Android SDK not found**
- `flutter devices`: พบ Windows/Chrome/Edge เท่านั้น ไม่มี Android จริง; ไม่ได้ใช้แพลตฟอร์มเหล่านี้แทนการทดสอบ Android
- `flutter pub get`: ผ่าน
- `flutter analyze`: ผ่าน `No issues found!` เมื่อเรียกผ่าน ASCII alias ของโปรเจกต์เดิม
- `flutter test`: ดูผลล่าสุดใน `docs/VALIDATION.md`; ทดสอบเฉพาะ logic ไม่ยืนยัน Nearby native implementation
- `flutter build apk --debug`: ยังไม่สำเร็จ ข้อความ `No Android SDK found`

Flutter analyzer รุ่นนี้ล้มด้วย `FormatException` ใน LSP เมื่อใช้ path อักษรไทย และล้มอีกแบบเมื่อ project อยู่ที่ root ของ drive alias จึง map **โฟลเดอร์แม่** แล้วใช้ `R:\rescuelink` แทน `R:\` helper ทำให้อัตโนมัติ ไม่ copy project และไม่ downgrade dependency หรือแก้ Flutter SDK

## เตรียม Android toolchain

1. ติดตั้ง Android Studio แล้วติดตั้ง Android SDK Platform 36, Build-Tools, Platform-Tools และ Android SDK Command-line Tools (latest) ใน SDK Manager รวมถึง NDK (Side by side) หาก Gradle ขอรุ่นที่ Flutter กำหนด
2. เพิ่ม `D:\app\flutter\bin` ใน PATH ของ terminal นี้:

```powershell
$env:Path = 'D:\app\flutter\bin;' + $env:Path
cd 'D:\3-1\project_keeratiburt\miniProject\rescuelink'
```

3. หาก Flutter ไม่พบ SDK อัตโนมัติ ใช้ตำแหน่งจริงที่แสดงใน Android Studio (อย่าคัดลอก placeholder ตรง ๆ):

```powershell
flutter config --android-sdk '<ANDROID_SDK_PATH>'
flutter doctor --android-licenses
flutter doctor -v
```

อ่านและยอมรับ license ด้วยตนเอง Android Studio มี JDK ให้ใช้; หาก doctor พบ Java ไม่ตรงให้กำหนด `flutter config --jdk-dir '<ANDROID_STUDIO_JBR_PATH>'` ตามตำแหน่งจริง ไม่ต้อง downgrade Gradle แบบสุ่ม

4. โทรศัพท์ทั้งสองควรเป็น Android 7/API 24 ขึ้นไปและมี Google Play services เปิด Developer options → USB debugging เสียบสาย USB ที่ส่งข้อมูลได้ แล้วอนุญาต RSA prompt บนมือถือ หากแสดง unauthorized ให้ปลดล็อกเครื่องและกดยอมรับ; ถ้าไม่พบให้ตรวจสาย/USB driver

## รัน Phone A และติดตั้ง Phone B

ใน project นี้ใช้ helper แทน `flutter` เพื่อหลีกเลี่ยง Unicode path bug (คำสั่งที่ส่งต่อไปยัง Flutter เหมือนกันทุกประการ):

```powershell
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 devices
.\tool\flutter.ps1 run -d <PHONE_A_ID>
```

เปิด PowerShell อีกหน้าต่างในโฟลเดอร์เดียวกันสำหรับ Phone B:

```powershell
.\tool\flutter.ps1 run -d <PHONE_B_ID>
```

หรือ build APK หนึ่งครั้งแล้วติดตั้ง APK เดียวกันทั้งสองเครื่อง:

```powershell
.\tool\flutter.ps1 build apk --debug
.\tool\flutter.ps1 install --debug -d <PHONE_A_ID>
.\tool\flutter.ps1 install --debug -d <PHONE_B_ID>
```

เมื่อ build ผ่าน APK อยู่ที่ `build\app\outputs\flutter-apk\app-debug.apk` และติดตั้งตรงได้ด้วย:

```powershell
& '<ANDROID_SDK_PATH>\platform-tools\adb.exe' -s <PHONE_B_ID> install -r '.\build\app\outputs\flutter-apk\app-debug.apk'
```

คำสั่งมาตรฐานหากโปรเจกต์อยู่ใน ASCII path: `flutter devices`, `flutter run -d <id>`, `flutter build apk --debug`, `flutter install --debug -d <id>`

build ครั้งแรกต้องใช้อินเทอร์เน็ตบนคอมพิวเตอร์เพื่อดาวน์โหลด dependencies แต่ช่วงทดสอบ chat บนโทรศัพท์ไม่ต้องมีอินเทอร์เน็ต

## ทดสอบ Offline A ↔ B ทีละขั้น

1. ติดตั้งแอปเดียวกันบน Android จริงสองเครื่อง ตั้งชื่อ A = `Rescue-A`, B = `Rescue-B` ก่อนเริ่ม mode
2. เปิด Bluetooth, Wi-Fi **radio**, Location ทั้งสองเครื่อง ปิด Mobile Data, hotspot, tethering และ disconnect จาก Wi-Fi network ที่มีอินเทอร์เน็ต คง Wi-Fi radio ไว้ ไม่จำเป็นต้องมี router/access point
3. เปิดแอปไว้ด้านหน้าทั้งสองเครื่อง กด CHECK / REQUEST และอนุญาตสิทธิ์ที่จำเป็น Android 12/12L ให้เลือก Precise location หากไปเปิด service ใน Settings แล้วกลับมาให้กดเริ่ม mode ใหม่
4. A กด START ADVERTISING; ต้องเห็น Advertising on และ Waiting for nearby devices
5. B กด START DISCOVERY; ต้องเห็น `Rescue-A` เพียงรายการเดียว
6. B กด CONNECT; ทั้งสองแอป auto-accept และต้องเห็นอีกเครื่องใน Connected Devices พร้อม log `Connected to ...` ฝั่ง B หยุด discovery อัตโนมัติเมื่อเชื่อมต่อได้
7. B ส่ง `Hello A` และตรวจว่า A แสดง `Rescue-B: Hello A`
8. A ส่ง `Hello B` และตรวจว่า B แสดง `Rescue-A: Hello B`
9. ส่ง `Hello from RescueLink` และ `สวัสดีจาก RescueLink` สลับทั้งสองทิศทาง ดูข้อความบน **เครื่องรับจริง** ไม่ใช้แค่ queued ฝั่งส่งเป็นหลักฐาน
10. กด DISCONNECT หรือ STOP แล้วลองส่ง ต้องมีข้อความว่าให้เชื่อมต่อก่อน จากนั้นเริ่มค้นหาและเชื่อมต่อใหม่
11. ทดสอบ deny permission, Location off, Bluetooth off, ข้อความว่าง และออกจากแอปแล้วกลับเข้าใหม่ บันทึกผลใน `docs/PHYSICAL_TEST.md`

## ปัญหาที่อาจพบ

| อาการ | วิธีตรวจ/แก้ |
| --- | --- |
| No Android SDK found | ติดตั้ง SDK และกำหนด `flutter config --android-sdk` แล้วรัน doctor |
| Analyzer FormatException / Windows non-ASCII path | ใช้ `tool/flutter.ps1`; หาก native build tool ยัง resolve กลับไป path ไทย ให้ย้าย checkout ไป ASCII path แล้ว `flutter clean` / `flutter pub get` |
| Nearby Devices / Location denied | CHECK / REQUEST; หาก denied permanently ใช้ APP SETTINGS; Android 12 เลือก precise |
| ไม่พบอุปกรณ์ | ตรวจ A Advertising, B Discovery, Bluetooth/Wi-Fi/Location on, อยู่ใกล้กัน, serviceId และ APK รุ่นเดียวกัน, Google Play services พร้อมใช้ |
| Advertising/Discovery failed | อ่าน error code ใน System Log; ตรวจ permission/radio แล้ว STOP และเริ่มใหม่ |
| Connection rejected/failed/timed out | ให้แอปอยู่ foreground ทั้งสองฝั่ง แล้ว discover ใหม่; timeout ตั้งไว้ 30 วินาที |
| ข้อความขึ้น queued แต่ปลายทางไม่เห็น | queued เป็นเพียง API รับคำขอส่ง ดู transfer success/failure และข้อความบนเครื่องรับ ไม่มี read receipt ใน Phase 1 |
| ส่งไม่ได้หลังหน้าจอดับ/สลับแอป | POC หยุดการเชื่อมต่อเมื่อ paused เพื่อไม่ค้างเบื้องหลัง เปิดใหม่แล้ว reconnect |
| เชื่อมต่อหลุด | ตรวจ Location service, ระยะ, radio; Android แต่ละรุ่นอาจมีข้อจำกัดด้านพลังงาน |
| ต้องการ native logs | `flutter logs -d <id>` หรือ `adb -s <id> logcat`; แอปมี `[RescueLink]` logs และ System Log ในจอ |

## ข้อจำกัดที่ตั้งใจไว้

- Auto-accept ใช้เฉพาะอุปกรณ์ทดสอบ; มี TODO ให้ผู้ใช้ approve/reject ในรุ่นจริง
- ข้อความส่งไปยัง peers ที่เชื่อมต่อทั้งหมด ไม่มี relay A → B → C
- Bytes payload ไม่เกิน 32 KB หลัง encode UTF-8
- เก็บข้อความ/log ใน RAM ไม่เกิน 200 รายการต่อ list; ชื่อ default สุ่มใหม่เมื่อเปิด session ไม่มีฐานข้อมูล
- `Me … (queued)` ไม่ใช่คำยืนยันว่าอีกฝ่ายอ่านแล้ว; System Log แสดง payload transfer status แยกต่างหาก
- หยุด Advertising/Discovery/Endpoints เมื่อ STOP, screen dispose, app paused/detached; ไม่รับประกัน callback ตอน OS force-kill ซึ่งระบบจะคืนทรัพยากร native เอง
- Android debug build/manifest merge และเปิดแอปบน emulator ผ่านแล้ว แต่ยังไม่ยืนยันการเชื่อมต่อจริงบนโทรศัพท์สองเครื่อง
- Phase 2 ยังไม่เริ่ม

## แหล่งอ้างอิง

- [Nearby Connections Android setup](https://developers.google.com/nearby/connections/android/get-started)
- [nearby_connections 4.3.0](https://pub.dev/packages/nearby_connections)
- [Android Nearby Wi-Fi permissions](https://developer.android.com/develop/connectivity/wifi/wifi-permissions)
- [permission_handler](https://pub.dev/packages/permission_handler)
- [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup)
