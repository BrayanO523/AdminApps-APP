import 'package:flutter/material.dart';

/// Definición de cada sección del sidebar.
class CarwashSection {
  final String id;
  final String label;
  final String collection;
  final IconData icon;
  final bool allowCreate;
  final bool usesCustomView;

  const CarwashSection({
    required this.id,
    required this.label,
    required this.collection,
    required this.icon,
    this.allowCreate = true,
    this.usesCustomView = false,
  });
}

/// Todas las secciones disponibles en el panel CarwashPro.
const List<CarwashSection> carwashSections = [
  CarwashSection(
    id: 'empresas',
    label: 'Empresas',
    collection: 'empresas',
    icon: Icons.business_rounded,
  ),
  CarwashSection(
    id: 'sucursales',
    label: 'Sucursales',
    collection: 'sucursales',
    icon: Icons.location_on_rounded,
  ),
  CarwashSection(
    id: 'clientes',
    label: 'Clientes',
    collection: 'clientes',
    icon: Icons.groups_rounded,
  ),
  CarwashSection(
    id: 'usuarios',
    label: 'Usuarios',
    collection: 'usuarios',
    icon: Icons.person_rounded,
  ),
  CarwashSection(
    id: 'productos',
    label: 'Productos',
    collection: 'productos',
    icon: Icons.inventory_2_rounded,
  ),
  CarwashSection(
    id: 'tiposLavados',
    label: 'Tipos de Lavado',
    collection: 'tiposLavados',
    icon: Icons.local_car_wash_rounded,
  ),
  CarwashSection(
    id: 'vehiculos',
    label: 'Vehículos',
    collection: 'vehiculos',
    icon: Icons.directions_car_rounded,
  ),
  CarwashSection(
    id: 'balance',
    label: 'Balance',
    collection: '',
    icon: Icons.analytics_rounded,
    allowCreate: false,
    usesCustomView: true,
  ),
  CarwashSection(
    id: 'facturas',
    label: 'Facturas',
    collection: 'facturas',
    icon: Icons.receipt_long_rounded,
    allowCreate: false,
    usesCustomView: true,
  ),
  CarwashSection(
    id: 'pagos',
    label: 'Pagos',
    collection: 'pagos',
    icon: Icons.payments_rounded,
    allowCreate: false,
  ),
  CarwashSection(
    id: 'estadoCuenta',
    label: 'Estado de Cuenta',
    collection: '',
    icon: Icons.account_balance_wallet_rounded,
    allowCreate: false,
    usesCustomView: true,
  ),
  CarwashSection(
    id: 'facturacion',
    label: 'Facturación',
    collection: 'facturacion',
    icon: Icons.bar_chart_rounded,
    allowCreate: false,
  ),
  CarwashSection(
    id: 'audit_logs',
    label: 'Auditoría',
    collection: 'audit_logs',
    icon: Icons.shield_rounded,
    allowCreate: false,
  ),
];
