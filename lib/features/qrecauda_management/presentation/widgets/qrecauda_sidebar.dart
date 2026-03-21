import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/qrecauda_section.dart';
import '../viewmodels/qrecauda_dashboard_viewmodel.dart';

class QRecaudaSidebar extends ConsumerWidget {
  final VoidCallback? onItemTap;
  const QRecaudaSidebar({super.key, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(
      qrecaudaDashboardProvider.select((s) => s.activeSection),
    );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
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
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QRecauda',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Gestión Municipal',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ],
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
              itemCount: qrecaudaSections.length,
              itemBuilder: (context, index) {
                final section = qrecaudaSections[index];
                final isActive = section.id == activeSection;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _SidebarItem(
                    section: section,
                    isActive: isActive,
                    onTap: () {
                      ref
                          .read(qrecaudaDashboardProvider.notifier)
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
  final QRecaudaSection section;
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
                ? const Color(0xFFD97706).withValues(alpha: 0.12)
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
                color: isHighlighted ? const Color(0xFFD97706) : Colors.white38,
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
