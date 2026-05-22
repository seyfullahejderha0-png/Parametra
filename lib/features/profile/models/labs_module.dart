class LabsModule {
  final String id;
  final String name;
  final String nameEn;
  final String status; // 'Geliştiriliyor', 'Planlandı', 'Ar-Ge'
  final String statusEn; // 'Developing', 'Planned', 'R&D'
  final String description;
  final String descriptionEn;
  final double progress; // 0.0 to 1.0
  final String icon; // Emoji representation
  final String category; // 'geliştiriliyor', 'planlandı', 'arge'

  const LabsModule({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.status,
    required this.statusEn,
    required this.description,
    required this.descriptionEn,
    required this.progress,
    required this.icon,
    required this.category,
  });

  LabsModule copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? status,
    String? statusEn,
    String? description,
    String? descriptionEn,
    double? progress,
    String? icon,
    String? category,
  }) {
    return LabsModule(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      status: status ?? this.status,
      statusEn: statusEn ?? this.statusEn,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      progress: progress ?? this.progress,
      icon: icon ?? this.icon,
      category: category ?? this.category,
    );
  }
}
