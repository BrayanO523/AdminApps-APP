import 'package:flutter/material.dart';

/// Definición de cada sección del sidebar EPD.
class EpdSection {
  final String id;
  final String label;
  final String collection;
  final IconData icon;

  const EpdSection({
    required this.id,
    required this.label,
    required this.collection,
    required this.icon,
  });
}

/// Todas las secciones disponibles en el panel EficentPost Dynamic.
const List<EpdSection> epdSections = [
  EpdSection(
    id: 'companies',
    label: 'Empresas',
    collection: 'companies',
    icon: Icons.business_rounded,
  ),
  EpdSection(
    id: 'branches',
    label: 'Sucursales',
    collection: 'branches',
    icon: Icons.store_mall_directory_rounded,
  ),
  EpdSection(
    id: 'users',
    label: 'Usuarios',
    collection: 'users',
    icon: Icons.people_rounded,
  ),
  EpdSection(
    id: 'clients',
    label: 'Clientes',
    collection: 'clients',
    icon: Icons.person_pin_rounded,
  ),
  EpdSection(
    id: 'products',
    label: 'Productos',
    collection: 'products',
    icon: Icons.inventory_2_rounded,
  ),
  EpdSection(
    id: 'categories',
    label: 'Categorías',
    collection: 'categories',
    icon: Icons.category_rounded,
  ),
  EpdSection(
    id: 'combos',
    label: 'Combos',
    collection: 'combos',
    icon: Icons.fastfood_rounded,
  ),
  EpdSection(
    id: 'sales',
    label: 'Ventas',
    collection: 'sales',
    icon: Icons.point_of_sale_rounded,
  ),
  EpdSection(
    id: 'inventory',
    label: 'Inventario',
    collection: 'inventory',
    icon: Icons.warehouse_rounded,
  ),
  EpdSection(
    id: 'inventory_transactions',
    label: 'Transacciones de Inv.',
    collection: 'inventory_transactions',
    icon: Icons.swap_horiz_rounded,
  ),
  EpdSection(
    id: 'inventory_transfers',
    label: 'Traslados de Inv.',
    collection: 'inventory_transfers',
    icon: Icons.transfer_within_a_station_rounded,
  ),
  EpdSection(
    id: 'suppliers',
    label: 'Proveedores',
    collection: 'suppliers',
    icon: Icons.local_shipping_rounded,
  ),
  EpdSection(
    id: 'supplier_assignments',
    label: 'Asig. Proveedores',
    collection: 'supplier_assignments',
    icon: Icons.assignment_ind_rounded,
  ),
  EpdSection(
    id: 'waste_reports',
    label: 'Mermas',
    collection: 'waste_reports',
    icon: Icons.delete_sweep_rounded,
  ),
  EpdSection(
    id: 'catalog_templates',
    label: 'Plantillas Catálogo',
    collection: 'catalog_templates',
    icon: Icons.list_alt_rounded,
  ),
  EpdSection(
    id: 'category_templates',
    label: 'Plantillas Categoría',
    collection: 'category_templates',
    icon: Icons.style_rounded,
  ),
  EpdSection(
    id: 'app_releases',
    label: 'Releases App',
    collection: 'app_releases',
    icon: Icons.system_update_rounded,
  ),
  EpdSection(
    id: 'empresa_device_versions',
    label: 'Versiones Equipos',
    collection: 'empresa_device_versions',
    icon: Icons.devices_rounded,
  ),
];
