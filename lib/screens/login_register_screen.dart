import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class LoginRegisterScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginRegisterScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  final TextEditingController _phoneController = TextEditingController(text: '+976 9911 8844');
  final TextEditingController _passwordController = TextEditingController(text: '••••••••');

  late PageController _slideshowController;
  int _activeSlide = 0;
  Timer? _slideshowTimer;

  final List<Map<String, String>> _slides = [
    {
      'titleKey': 'slideshow1_title',
      'subKey': 'slideshow1_sub',
      'image': 'assets/images/banner.jpg',
    },
    {
      'titleKey': 'slideshow2_title',
      'subKey': 'slideshow2_sub',
      'image': 'assets/images/bmw_x5.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _slideshowController = PageController();
    _startSlideshowTimer();
  }

  void _startSlideshowTimer() {
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_slideshowController.hasClients) {
        final nextPage = (_activeSlide + 1) % _slides.length;
        _slideshowController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _slideshowController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkForest,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // TOP 70%: Slideshow Hero Banner & Logo
            Expanded(
              flex: 7,
              child: Stack(
                children: [
                  // PageView Slideshow
                  PageView.builder(
                    controller: _slideshowController,
                    onPageChanged: (index) {
                      setState(() => _activeSlide = index);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              slide['image']!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppTheme.darkForest,
                                  child: const Center(
                                    child: Icon(Icons.bolt_rounded, size: 100, color: AppTheme.sageGreen),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Dark gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    AppTheme.darkForest.withOpacity(0.95),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Text Content Overlay
                          Positioned(
                            bottom: 30,
                            left: 24,
                            right: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.get(slide['titleKey']!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppStrings.get(slide['subKey']!),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Top Header Logo & Language Toggle
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 24,
                    right: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.sageGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.get('appName'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  AppStrings.get('tagline'),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Language Switcher Toggle
                        InkWell(
                          onTap: () {
                            setState(() {
                              AppStrings.currentLanguage =
                                  AppStrings.currentLanguage == AppLanguage.mn
                                      ? AppLanguage.en
                                      : AppLanguage.mn;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  AppStrings.currentLanguage == AppLanguage.mn ? '🇲🇳 МН' : '🇬🇧 EN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slideshow Indicator Dots
                  Positioned(
                    bottom: 12,
                    left: 24,
                    child: Row(
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: _activeSlide == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _activeSlide == index ? AppTheme.sageGreen : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTTOM 30%: Input Sheet & Authentication Buttons
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.softBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Selector (Login / Register)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLoginMode = true),
                              child: Column(
                                children: [
                                  Text(
                                    AppStrings.get('login'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: _isLoginMode ? FontWeight.bold : FontWeight.w500,
                                      color: _isLoginMode ? AppTheme.darkForest : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 3,
                                    color: _isLoginMode ? AppTheme.sageGreen : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLoginMode = false),
                              child: Column(
                                children: [
                                  Text(
                                    AppStrings.get('register'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: !_isLoginMode ? FontWeight.bold : FontWeight.w500,
                                      color: !_isLoginMode ? AppTheme.darkForest : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 3,
                                    color: !_isLoginMode ? AppTheme.sageGreen : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input 1: Phone / Email
                      TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: AppStrings.get('phone_email'),
                          prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.darkForest),
                          filled: true,
                          fillColor: AppTheme.cardWhite,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.borderSubtle),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Input 2: Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: AppStrings.get('password'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.darkForest),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppTheme.cardWhite,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.borderSubtle),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: widget.onLoginSuccess,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.darkForest,
                          ),
                          child: Text(
                            _isLoginMode ? AppStrings.get('login') : AppStrings.get('register'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
