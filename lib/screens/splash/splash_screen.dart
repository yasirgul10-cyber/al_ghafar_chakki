import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // 🕒 3 سیکنڈ بعد HomeScreen پر نیویگیشن
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🏆 تصویری یا کسٹم گولڈن میرون آئیکن
                  _buildChakkiLogo(),

                  const SizedBox(height: 30),

                  // 🏷️ ایپ کا نام
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 📝 ٹیگ لائن
                  Text(
                    AppStrings.appTagline,
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // ⏳ لوڈنگ انڈیکیٹر
                  const CircularProgressIndicator(
                    color: Color(0xFFFFD700), // گولڈن رنگ
                    strokeWidth: 3.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🌾 تصویر جیسا خوبصورت گولڈن اور میرون ایمبلم لوگو
  Widget _buildChakkiLogo() {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // بیرونی گولڈن رنگ کا دائرہ
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDF00),
            Color(0xFFD4AF37),
            Color(0xFF996515),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6), // Outer Golden Border
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFF8B0000), // Dark Maroon Center
              Color(0xFF4A0000), // Deep Burgundy Edge
            ],
            center: Alignment.center,
            radius: 0.85,
          ),
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 2.5,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // اگر امیج کا فائل پاتھ نہ ملے تو یہ خوبصورت کسٹم لوگو ڈیزائن دکھائے گا
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.grain_rounded,
                    size: 40,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'الغفّار',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                      height: 1.1,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    width: 70,
                    height: 1.5,
                    color: const Color(0xFFFFD700),
                  ),
                  const Text(
                    'AL-GHAFFAR CHAKKI',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}