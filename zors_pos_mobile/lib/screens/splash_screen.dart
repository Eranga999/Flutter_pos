import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum CheckStatus { pending, loading, success, failed }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _contentController;
  late AnimationController _pulseController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _pulseAnimation;

  // Status checks
  CheckStatus _internetStatus = CheckStatus.pending;
  CheckStatus _serverStatus = CheckStatus.pending;
  CheckStatus _authStatus = CheckStatus.pending;

  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startChecks();
  }

  void _initAnimations() {
    // Logo animation with elastic bounce
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoRotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Content fade animation
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    // Pulse animation for loading states
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _contentController.forward();
    });
  }

  Future<void> _startChecks() async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Check 1: Internet connectivity
    await _checkInternet();
    if (_internetStatus == CheckStatus.failed) {
      _showRetryOption();
      return;
    }

    // Check 2: Server/API connection
    await _checkServer();
    if (_serverStatus == CheckStatus.failed) {
      _showRetryOption();
      return;
    }

    // Check 3: Authentication status
    await _checkAuth();

    // All checks passed - navigate
    await Future.delayed(const Duration(milliseconds: 500));
    _navigateToApp();
  }

  Future<void> _checkInternet() async {
    setState(() {
      _internetStatus = CheckStatus.loading;
      _statusMessage = 'Checking internet connection...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _internetStatus = CheckStatus.success;
        });
        HapticFeedback.lightImpact();
      } else {
        throw Exception('No internet');
      }
    } catch (e) {
      setState(() {
        _internetStatus = CheckStatus.failed;
        _hasError = true;
        _errorMessage =
            'No internet connection.\nPlease check your network settings.';
        _statusMessage = 'Connection failed';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _checkServer() async {
    setState(() {
      _serverStatus = CheckStatus.loading;
      _statusMessage = 'Connecting to server...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      // Try to reach the API
      final result = await ApiService.getCategories().timeout(
        const Duration(seconds: 10),
      );

      if (result['success'] == true || result['data'] != null) {
        setState(() {
          _serverStatus = CheckStatus.success;
        });
        HapticFeedback.lightImpact();
      } else {
        // Even if categories fail, check if we can reach the server
        setState(() {
          _serverStatus = CheckStatus.success;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() {
        _serverStatus = CheckStatus.failed;
        _hasError = true;
        _errorMessage = 'Unable to connect to server.\nPlease try again later.';
        _statusMessage = 'Server unreachable';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _checkAuth() async {
    setState(() {
      _authStatus = CheckStatus.loading;
      _statusMessage = 'Checking authentication...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final token = await ApiService.getToken();
      setState(() {
        _authStatus = CheckStatus.success;
        _statusMessage = token != null ? 'Welcome back!' : 'Ready to login';
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _authStatus = CheckStatus.success;
        _statusMessage = 'Ready to login';
      });
    }
  }

  void _showRetryOption() {
    setState(() {
      _hasError = true;
    });
  }

  void _retryChecks() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _internetStatus = CheckStatus.pending;
      _serverStatus = CheckStatus.pending;
      _authStatus = CheckStatus.pending;
      _statusMessage = 'Retrying...';
    });
    _startChecks();
  }

  void _navigateToApp() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo Section
              _buildLogoSection(),

              const SizedBox(height: 32),

              // App Title
              FadeTransition(
                opacity: _contentFadeAnimation,
                child: _buildAppTitle(),
              ),

              const Spacer(flex: 1),

              // Status Checks Section
              FadeTransition(
                opacity: _contentFadeAnimation,
                child: _buildStatusSection(),
              ),

              const Spacer(flex: 1),

              // Error/Retry Section or Loading
              FadeTransition(
                opacity: _contentFadeAnimation,
                child: _hasError
                    ? _buildRetrySection()
                    : _buildLoadingSection(),
              ),

              const SizedBox(height: 40),

              // Footer
              FadeTransition(
                opacity: _contentFadeAnimation,
                child: _buildFooter(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScaleAnimation.value,
          child: Transform.rotate(
            angle: _logoRotateAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF324137).withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 20,
              offset: const Offset(-5, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.storefront_rounded,
                  size: 60,
                  color: Colors.white,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
          ).createShader(bounds),
          child: const Text(
            'ZORS POS',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E260).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Point of Sale System',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF324137),
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatusItem(
            'Internet Connection',
            Icons.wifi_rounded,
            _internetStatus,
          ),
          const SizedBox(height: 16),
          _buildStatusItem(
            'Server Connection',
            Icons.cloud_rounded,
            _serverStatus,
          ),
          const SizedBox(height: 16),
          _buildStatusItem('Authentication', Icons.shield_rounded, _authStatus),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, IconData icon, CheckStatus status) {
    Color iconColor;
    Color bgColor;
    Widget statusWidget;

    switch (status) {
      case CheckStatus.pending:
        iconColor = Colors.grey.shade400;
        bgColor = Colors.grey.shade100;
        statusWidget = Icon(
          Icons.circle_outlined,
          size: 20,
          color: Colors.grey.shade400,
        );
        break;
      case CheckStatus.loading:
        iconColor = const Color(0xFF324137);
        bgColor = const Color(0xFF324137).withOpacity(0.1);
        statusWidget = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _pulseAnimation.value, child: child);
          },
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF324137),
              ),
            ),
          ),
        );
        break;
      case CheckStatus.success:
        iconColor = const Color(0xFF35AE4A);
        bgColor = const Color(0xFF35AE4A).withOpacity(0.1);
        statusWidget = TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF35AE4A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        );
        break;
      case CheckStatus.failed:
        iconColor = Colors.red.shade400;
        bgColor = Colors.red.shade50;
        statusWidget = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
        );
        break;
    }

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: status == CheckStatus.pending
                  ? Colors.grey.shade500
                  : const Color(0xFF324137),
            ),
          ),
        ),
        statusWidget,
      ],
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: 0.5 + (_pulseAnimation.value * 0.5),
              child: child,
            );
          },
          child: Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetrySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _AnimatedRetryButton(onTap: _retryChecks),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, size: 14, color: Colors.red.shade400),
            const SizedBox(width: 6),
            Text(
              'Powered by kodernet',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'v1.0.0',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

// Animated retry button
class _AnimatedRetryButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedRetryButton({required this.onTap});

  @override
  State<_AnimatedRetryButton> createState() => _AnimatedRetryButtonState();
}

class _AnimatedRetryButtonState extends State<_AnimatedRetryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF324137).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
