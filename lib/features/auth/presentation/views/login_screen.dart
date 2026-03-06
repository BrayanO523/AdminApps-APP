import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Por favor, ingresa tu correo y contraseña.');
      return;
    }

    ref.read(authViewModelProvider.notifier).login(email, password);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.outfit(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    // Escuchar errores — solo cuando la transición va a un error nuevo
    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          previous?.errorMessage != next.errorMessage) {
        _showError(next.errorMessage!);
        // Limpiamos después de un frame para no interferir con el build
        Future.microtask(() {
          if (mounted) {
            ref.read(authViewModelProvider.notifier).clearError();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── Fondo decorativo ──
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.tealAccent.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Card Glassmorphism ──
          Center(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeIn,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 600
                          ? 20
                          : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.sizeOf(context).width < 600
                                ? 24
                                : 40,
                            vertical: 48,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Ícono
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Acceso Centralizado',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'CarwashPro · EficentPostDynamic',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.white54,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Email
                              _buildField(
                                controller: _emailController,
                                hint: 'Correo electrónico',
                                icon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildField(
                                controller: _passwordController,
                                hint: 'Contraseña',
                                icon: Icons.lock_outline,
                                isObscure: _isObscure,
                                onToggle: () =>
                                    setState(() => _isObscure = !_isObscure),
                              ),
                              const SizedBox(height: 32),

                              // Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: authState.isLoading
                                      ? null
                                      : _submit,
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Ingresar',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isObscure = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white30, size: 20),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                  isObscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white30,
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
  }
}
