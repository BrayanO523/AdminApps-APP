import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MainHubScreen extends StatelessWidget {
  const MainHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo elegante
      body: Row(
        children: [
          // Sección CarwashPro (Izquierda)
          Expanded(
            child: _AnimatedHubSection(
              title: 'CarwashPro',
              subtitle: 'Gestión Integral de Lavados',
              primaryColor: const Color(0xFF0EA5E9), // Azul premium
              onTap: () => context.go('/dashboard/carwash'),
            ),
          ),

          // Divisor
          Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),

          // Sección EficentPostDynamic (Centro)
          Expanded(
            child: _AnimatedHubSection(
              title: 'EficentPostDynamic',
              subtitle: 'Control Agrícola y Logística',
              primaryColor: const Color(0xFF10B981), // Verde esmeralda
              onTap: () => context.go('/dashboard/eficent'),
            ),
          ),

          // Divisor
          Container(width: 1, color: Colors.white.withValues(alpha: 0.1)),

          // Sección QRecauda (Derecha)
          Expanded(
            child: _AnimatedHubSection(
              title: 'QRecauda',
              subtitle: 'Gestión Municipal',
              primaryColor: const Color(0xFFD97706), // Ámbar
              onTap: () => context.go('/dashboard/qrecauda'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedHubSection extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AnimatedHubSection({
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_AnimatedHubSection> createState() => _AnimatedHubSectionState();
}

class _AnimatedHubSectionState extends State<_AnimatedHubSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isHovered
                    ? widget.primaryColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                _isHovered
                    ? widget.primaryColor.withValues(alpha: 0.05)
                    : Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isHovered ? 0.6 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        widget.primaryColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Contenido
              Center(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  offset: _isHovered ? Offset.zero : const Offset(0, 0.03),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: GoogleFonts.outfit(
                          fontSize: _isHovered ? 40 : 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          shadows: _isHovered
                              ? [
                                  Shadow(
                                    color: widget.primaryColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(widget.title),
                      ),
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isHovered ? 1.0 : 0.0,
                        child: Text(
                          widget.subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
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
