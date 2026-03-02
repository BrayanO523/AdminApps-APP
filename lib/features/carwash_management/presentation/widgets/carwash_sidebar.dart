import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/carwash_section.dart';
import '../viewmodels/carwash_dashboard_viewmodel.dart';

class CarwashSidebar extends ConsumerWidget {
  final VoidCallback? onItemTap;
  const CarwashSidebar({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(
      carwashDashboardProvider.select((s) => s.activeSection),
    );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1929),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_car_wash_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CarwashPro',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 8),

          // ── Secciones ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: carwashSections.length,
              itemBuilder: (context, index) {
                final section = carwashSections[index];
                final isActive = section.id == activeSection;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _SidebarItem(
                    section: section,
                    isActive: isActive,
                    onTap: () {
                      ref
                          .read(carwashDashboardProvider.notifier)
                          .selectSection(section.id);
                      onItemTap?.call();
                    },
                  ),
                );
              },
            ),
          ),

          // ── Footer ──
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Panel Administrativo',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.white24,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final CarwashSection section;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.section,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
                : _hovered
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.section.icon,
                size: 18,
                color: isHighlighted ? const Color(0xFF0EA5E9) : Colors.white38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.section.label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isHighlighted ? Colors.white : Colors.white54,
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
