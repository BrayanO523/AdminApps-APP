import '../../../../core/utils/resolvable_state.dart';
import '../../domain/entities/carwash_section.dart';

class CarwashDashboardState implements ResolvableState {
  final String activeSection;
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> data;
  final bool hasMore;
  final int totalItems;
  final String? searchField;
  final String? searchValue;
  final Map<String, String> empresaNames;
  final Map<String, String> sucursalNames;
  final Map<String, String> usuarioNames;
  final Map<String, String> clienteNames;
  final Map<String, String> tipoLavadoNames;
  final Map<String, String> categoriaNames;
  final List<Map<String, dynamic>> selectedEmpresas;

  const CarwashDashboardState({
    this.activeSection = 'empresas',
    this.isLoading = false,
    this.errorMessage,
    this.data = const [],
    this.hasMore = true,
    this.totalItems = 0,
    this.searchField,
    this.searchValue,
    this.empresaNames = const {},
    this.sucursalNames = const {},
    this.usuarioNames = const {},
    this.clienteNames = const {},
    this.tipoLavadoNames = const {},
    this.categoriaNames = const {},
    this.selectedEmpresas = const [],
  });

  CarwashDashboardState copyWith({
    String? activeSection,
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? data,
    bool? hasMore,
    int? totalItems,
    String? searchField,
    String? searchValue,
    Map<String, String>? empresaNames,
    Map<String, String>? sucursalNames,
    Map<String, String>? usuarioNames,
    Map<String, String>? clienteNames,
    Map<String, String>? tipoLavadoNames,
    Map<String, String>? categoriaNames,
    List<Map<String, dynamic>>? selectedEmpresas,
    bool clearError = false,
    bool clearSearch = false,
    bool clearEmpresas = false,
  }) {
    return CarwashDashboardState(
      activeSection: activeSection ?? this.activeSection,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data: data ?? this.data,
      hasMore: hasMore ?? this.hasMore,
      totalItems: totalItems ?? this.totalItems,
      searchField: clearSearch ? null : (searchField ?? this.searchField),
      searchValue: clearSearch ? null : (searchValue ?? this.searchValue),
      empresaNames: empresaNames ?? this.empresaNames,
      sucursalNames: sucursalNames ?? this.sucursalNames,
      usuarioNames: usuarioNames ?? this.usuarioNames,
      clienteNames: clienteNames ?? this.clienteNames,
      tipoLavadoNames: tipoLavadoNames ?? this.tipoLavadoNames,
      categoriaNames: categoriaNames ?? this.categoriaNames,
      selectedEmpresas: clearEmpresas
          ? const []
          : (selectedEmpresas ?? this.selectedEmpresas),
    );
  }

  String get activeSectionLabel {
    return carwashSections
        .firstWhere(
          (section) => section.id == activeSection,
          orElse: () => carwashSections.first,
        )
        .label;
  }

  @override
  String resolveId(String fieldName, String rawValue) {
    final lower = fieldName.toLowerCase();
    if (lower.contains('empresa')) return empresaNames[rawValue] ?? rawValue;
    if (lower.contains('sucursal')) return sucursalNames[rawValue] ?? rawValue;
    if (lower.contains('usuario') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('creado_por') ||
        lower.contains('modificado') ||
        lower.contains('modificadopor') ||
        lower.contains('admin') ||
        lower.contains('adminid')) {
      return usuarioNames[rawValue] ?? rawValue;
    }
    if (lower.contains('cliente')) return clienteNames[rawValue] ?? rawValue;
    if (lower.contains('servicio') ||
        lower.contains('tipolavado') ||
        lower.contains('tipo_lavado')) {
      return tipoLavadoNames[rawValue] ?? rawValue;
    }
    if (lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories')) {
      return categoriaNames[rawValue] ?? rawValue;
    }
    return rawValue;
  }

  @override
  bool isResolvableField(String fieldName) {
    final lower = fieldName.toLowerCase();
    return lower.contains('empresa') ||
        lower.contains('sucursal') ||
        lower.contains('usuario') ||
        lower.contains('uid') ||
        lower.contains('creado') ||
        lower.contains('modificado') ||
        lower.contains('admin') ||
        lower.contains('cliente') ||
        lower.contains('servicio') ||
        lower.contains('tipolavado') ||
        lower.contains('tipo_lavado') ||
        lower.contains('categoria') ||
        lower.contains('categoría') ||
        lower.contains('categor') ||
        lower.contains('category') ||
        lower.contains('categories');
  }
}
