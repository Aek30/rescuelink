import 'package:flutter/material.dart';

import 'login_screen.dart';

/// The three introduction pages shown before entering RescueLink.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _cream = Color(0xFFFCF8F1);
  static const _navy = Color(0xFF102D43);
  static const _orange = Color(0xFFFF6826);
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _login() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
  );

  void _next() {
    if (_page == 2) {
      _login();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _button(String label, {bool arrow = true}) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF8135), _orange]),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: .85)),
    ),
    child: FilledButton(
      onPressed: _next,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          if (arrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ],
      ),
    ),
  );

  Widget _dots({bool dark = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (index) => Semantics(
        label: 'หน้าที่ ${index + 1} จาก 3',
        selected: _page == index,
        button: true,
        child: InkResponse(
          onTap: () => _controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
          child: SizedBox(
            width: 32,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _page == index
                      ? _orange
                      : dark
                      ? Colors.white38
                      : const Color(0xFFD5D0C9),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _feature(IconData icon, String title) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _welcome() => LayoutBuilder(
    builder: (context, constraints) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final navyColor = isDark ? const Color(0xFFF1F5F9) : _navy;
      final height = constraints.maxHeight < 680
          ? 680.0
          : constraints.maxHeight;
      return SingleChildScrollView(
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/onboarding/welcome.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x55FFF5DF),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xE6102130),
                    ],
                    stops: [0, .38, .6, 1],
                  ),
                ),
              ),
              Positioned(
                top: 26,
                left: 22,
                right: 22,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        isDark
                            ? 'assets/branding/rescuelink-logo-dark.png'
                            : 'assets/branding/rescuelink-logo.png',
                        width: 88,
                        height: 88,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Rescue',
                            style: TextStyle(color: navyColor),
                          ),
                          const TextSpan(
                            text: 'Link',
                            style: TextStyle(color: _orange),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontFamily: 'NotoSansThai',
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                      ),
                    ),
                    Text(
                      'เชื่อมต่อผู้คน ในทุกสถานการณ์',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: navyColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'แม้ไม่มีสัญญาณ เราก็ยังเชื่อมต่อกันได้',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: navyColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24292B).withValues(alpha: .84),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _feature(
                            Icons.wifi_off_rounded,
                            'ใช้งานได้\nแม้ไม่มีอินเทอร์เน็ต',
                          ),
                          _feature(
                            Icons.groups_outlined,
                            'เชื่อมต่อได้ด้วย\nอุปกรณ์ใกล้เคียง',
                          ),
                          _feature(
                            Icons.health_and_safety_outlined,
                            'ช่วยเหลือกัน\nได้เร็วขึ้น',
                          ),
                        ],
                      ),
                      _dots(dark: true),
                      SizedBox(
                        width: double.infinity,
                        child: _button('เริ่มใช้งาน', arrow: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _explanation({required bool sos}) => LayoutBuilder(
    builder: (context, constraints) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final navyColor = isDark ? const Color(0xFFF1F5F9) : _navy;
      final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF365069);
      final bg = isDark ? const Color(0xFF0C1017) : _cream;
      final height = constraints.maxHeight < 740
          ? 740.0
          : constraints.maxHeight;
      return SingleChildScrollView(
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 165,
                bottom: 100,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/onboarding/${sos ? 'sos' : 'nearby'}.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
              Positioned(
                top: 120,
                left: 0,
                right: 0,
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bg, bg.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 18,
                child: TextButton(
                  onPressed: _login,
                  style: TextButton.styleFrom(
                    foregroundColor: navyColor,
                    backgroundColor: isDark
                        ? const Color(0xFF1E2631)
                        : const Color(0xFFF0EBE3),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: const Size(64, 44),
                  ),
                  child: const Text('ข้าม'),
                ),
              ),
              Positioned(
                top: 74,
                left: 28,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sos ? 'ส่งความช่วยเหลือ' : 'แม้ไม่มีสัญญาณ',
                      style: TextStyle(
                        color: navyColor,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      sos ? 'ได้อย่างรวดเร็ว' : 'เราก็ยังเชื่อมต่อกันได้',
                      style: const TextStyle(
                        color: _orange,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sos
                          ? 'กดเปิดโหมด SOS เพื่อแจ้งขอความช่วยเหลือ\nแชร์ตำแหน่งปัจจุบัน และส่งข้อความหาผู้ที่อยู่ใกล้เคียง เช่น ทีมกู้ภัย หรือผู้ใช้คนอื่น'
                          : 'ใช้เทคโนโลยี Bluetooth และ Wi-Fi Direct\nเชื่อมต่ออุปกรณ์ใกล้เคียง สร้างเครือข่ายแบบ Ad-hoc เพื่อส่งข้อความ ขอความช่วยเหลือ และแชร์ตำแหน่งได้',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (sos)
                Positioned(
                  top: height * .44,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161C24)
                          : Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(16),
                      border: isDark
                          ? Border.all(color: const Color(0xFF283442))
                          : null,
                      boxShadow: const [
                        BoxShadow(color: Color(0x14000000), blurRadius: 16),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _orange,
                          size: 34,
                        ),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'แชร์ตำแหน่ง',
                              style: TextStyle(
                                color: navyColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ให้คนใกล้เคียง',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bg.withValues(alpha: 0), bg, bg],
                      stops: const [0, .3, 1],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161C24)
                              : _cream.withValues(alpha: .97),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF283442)
                                : Colors.white,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 31,
                              backgroundColor: sos
                                  ? (isDark
                                        ? const Color(0xFF3D181C)
                                        : const Color(0xFFFFDDE0))
                                  : (isDark
                                        ? const Color(0xFF3D2514)
                                        : const Color(0xFFFFEAD0)),
                              child: Icon(
                                sos ? Icons.sos_rounded : Icons.hub_outlined,
                                size: 36,
                                color: sos ? const Color(0xFFFF3157) : _orange,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sos
                                        ? 'เปิดโหมด SOS'
                                        : 'สร้างเครือข่ายใกล้เคียง',
                                    style: TextStyle(
                                      color: navyColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sos
                                        ? 'แจ้งเตือนผู้คนใกล้เคียงได้ทันที\nพร้อมแชร์ตำแหน่งของคุณ'
                                        : 'เชื่อมต่อกับผู้คนรอบตัวแบบอัตโนมัติ\nไม่ต้องใช้อินเทอร์เน็ต',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _dots(),
                          Flexible(
                            child: _button(sos ? 'เริ่มใช้งาน' : 'ถัดไป'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1017) : _cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: PageView(
              controller: _controller,
              onPageChanged: (value) => setState(() => _page = value),
              children: [
                _welcome(),
                _explanation(sos: false),
                _explanation(sos: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
