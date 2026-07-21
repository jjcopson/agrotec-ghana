import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_button.dart';

class _OnboardPage {
  final String title;
  final String subtitle;
  final String emoji;
  final Color gradientStart;
  final Color gradientEnd;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

const _pages = [
  _OnboardPage(
    title: 'Ghana\'s Agro\nMarketplace',
    subtitle: 'Buy and sell fresh produce, equipment, and agricultural inputs directly with verified farmers and businesses.',
    emoji: '🌾',
    gradientStart: Color(0xFF0F766E),
    gradientEnd: Color(0xFF2DD4BF),
  ),  _OnboardPage(
    title: 'Expert\nConsultations',
    subtitle: 'Get professional advice from certified agricultural experts, lecturers, and consultants. First 10 minutes free.',
    emoji: '🎓',
    gradientStart: Color(0xFF15803D),
    gradientEnd: Color(0xFF4ADE80),
  ),
  _OnboardPage(
    title: 'Seamless\nLogistics',
    subtitle: 'Connect with verified truck drivers. Post a transport job and get bids from drivers across Ghana.',
    emoji: '🚛',
    gradientStart: Color(0xFF0369A1),
    gradientEnd: Color(0xFF38BDF8),
  ),
  _OnboardPage(
    title: 'Learn &\nGrow',
    subtitle: 'Access courses, articles, and a community forum from top agricultural experts and institutions.',
    emoji: '📚',
    gradientStart: Color(0xFF7C3AED),
    gradientEnd: Color(0xFFA78BFA),
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [page.gradientStart, page.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => context.go(AppConstants.routeLogin),
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final p = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo on first page
                          if (index == 0) ...[
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset('assets/icons/logo.svg'),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            Text(
                              p.emoji,
                              style: const TextStyle(fontSize: 72),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayLarge.copyWith(
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _currentPage == _pages.length - 1
                    ? Column(
                        children: [
                          AppButton(
                            label: 'Get Started',
                            onPressed: () => context.go(AppConstants.routeRegister),
                            borderRadius: BorderRadius.circular(14),
                          ).apply(white: true),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Sign In',
                            variant: AppButtonVariant.outline,
                            onPressed: () => context.go(AppConstants.routeLogin),
                          ).apply(white: true),
                        ],
                      )
                    : AppButton(
                        label: 'Next',
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ).apply(white: true),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

extension on AppButton {
  AppButton apply({bool white = false}) => this;
}
