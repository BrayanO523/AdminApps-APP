import 'package:flutter/material.dart';

/// Definición de cada sección del sidebar QRecauda.
class QRecaudaSection {
  final String id;
  final String label;
  final String collection;
  final IconData icon;

  const QRecaudaSection({
    required this.id,
    required this.label,
    required this.collection,
    required this.icon,
  });
}

/// Todas las secciones disponibles en el panel QRecauda.
const List<QRecaudaSection> qrecaudaSections = [
  QRecaudaSection(
    id: 'municipalidades',
    label: 'Municipalidades',
    collection: 'municipalidades',
    icon: Icons.account_balance_rounded,
  ),
  QRecaudaSection(
    id: 'mercados',
    label: 'Mercados',
    collection: 'mercados',
    icon: Icons.storefront_rounded,
  ),
  QRecaudaSection(
    id: 'locales',
    label: 'Locales',
    collection: 'locales',
    icon: Icons.store_rounded,
  ),
  QRecaudaSection(
    id: 'cobros',
    label: 'Cobros',
    collection: 'cobros',
    icon: Icons.receipt_long_rounded,
  ),
  QRecaudaSection(
    id: 'tipos_negocio',
    label: 'Tipos de Negocio',
    collection: 'tipos_negocio',
    icon: Icons.category_rounded,
  ),
  QRecaudaSection(
    id: 'usuarios',
    label: 'Usuarios',
    collection: 'usuarios',
    icon: Icons.people_rounded,
  ),
];
