import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    if (isMobile) {
      // ── Layout Móvil: Column vertical ──
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _DashboardHalf(
                  title: 'CarwashPro',
                  subtitle: 'Gestión Operativa Vehicular',
                  baseColor: const Color(0xFF0EA5E9),
                  darkColor: const Color(0xFF0C4A6E),
                  icon: Icons.local_car_wash_rounded,
                  onTap: () => context.go('/dashboard/carwash'),
                  isMobile: true,
                ),
              ),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              Expanded(
                child: _DashboardHalf(
                  title: 'Eficent',
                  subtitle: 'Post Dynamic Control',
                  baseColor: const Color(0xFF10B981),
                  darkColor: const Color(0xFF064E3B),
                  icon: Icons.pie_chart_rounded,
                  onTap: () => context.go('/dashboard/eficent'),
                  isMobile: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Layout Desktop/Web: Row horizontal (sin cambios) ──
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          Expanded(
            child: _DashboardHalf(
              title: 'CarwashPro',
              subtitle: 'Gestión Operativa Vehicular',
              baseColor: const Color(0xFF0EA5E9),
              darkColor: const Color(0xFF0C4A6E),
              icon: Icons.local_car_wash_rounded,
              onTap: () => context.go('/dashboard/carwash'),
              isMobile: false,
            ),
          ),
          Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(
            child: _DashboardHalf(
              title: 'Eficent',
              subtitle: 'Post Dynamic Control',
              baseColor: const Color(0xFF10B981),
              darkColor: const Color(0xFF064E3B),
              icon: Icons.pie_chart_rounded,
              onTap: () => context.go('/dashboard/eficent'),
              isMobile: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHalf extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color baseColor;
  final Color darkColor;
  final IconData icon;
  final VoidCallback onTap;
  final bool isMobile;

  const _DashboardHalf({
    required this.title,
    required this.subtitle,
    required this.baseColor,
    required this.darkColor,
    required this.icon,
    required this.onTap,
    required this.isMobile,
  });

  @override
  State<_DashboardHalf> createState() => _DashboardHalfState();
}

class _DashboardHalfState extends State<_DashboardHalf>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // En móvil: botón siempre visible, sin hover scale
    final showButton = widget.isMobile || _isHovered;
    final iconSize = widget.isMobile ? 180.0 : 380.0;
    final cardPadH = widget.isMobile ? 32.0 : 52.0;
    final cardPadV = widget.isMobile ? 28.0 : 44.0;
    final titleSize = widget.isMobile ? 26.0 : 34.0;
    final iconInnerSize = widget.isMobile ? 40.0 : 56.0;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isHovered
                    ? widget.baseColor.withValues(alpha: 0.35)
                    : widget.darkColor.withValues(alpha: 0.4),
                widget.darkColor.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Ícono grande de fondo ──
              Positioned(
                right: -60,
                bottom: -60,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 0.06 : 0.02,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(widget.icon, size: iconSize, color: Colors.white),
                ),
              ),

              // ── Card central Glassmorphism ──
              Center(
                child: widget.isMobile
                    ? _buildCard(
                        showButton,
                        cardPadH,
                        cardPadV,
                        titleSize,
                        iconInnerSize,
                      )
                    : ScaleTransition(
                        scale: _scaleAnim,
                        child: _buildCard(
                          showButton,
                          cardPadH,
                          cardPadV,
                          titleSize,
                          iconInnerSize,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    bool showButton,
    double padH,
    double padV,
    double titleSize,
    double iconSize,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isHovered ? 0.25 : 0.08),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.baseColor.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.baseColor.withValues(alpha: 0.15),
                ),
                child: Icon(widget.icon, size: iconSize, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white60,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // En móvil: siempre visible. En desktop: aparece al hover.
              AnimatedOpacity(
                opacity: showButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedSlide(
                  offset: showButton ? Offset.zero : const Offset(0, 0.3),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: widget.baseColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      'Ingresar al panel →',
                      style: GoogleFonts.outfit(
                        color: widget.darkColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
