class UserModel {
  final String id;
  final String name;
  final String role; // 'docente', 'estudiante', 'profesional'
  final bool modoTea;
  final bool lecturaFacil;
  final bool altoContraste;
  final bool lenguaSenas;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.modoTea = false,
    this.lecturaFacil = false,
    this.altoContraste = false,
    this.lenguaSenas = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final settings =
        json['accessibility_settings'] as Map<String, dynamic>? ?? {};
    return UserModel(
      id: json['id'] ?? '',
      name: json['full_name'] ?? 'Usuario',
      role: json['role'] ?? 'estudiante',
      modoTea: settings['modo_tea'] ?? false,
      lecturaFacil: settings['lectura_facil'] ?? false,
      altoContraste: settings['alto_contraste'] ?? false,
      lenguaSenas: settings['lengua_senas'] ?? false,
    );
  }
}
