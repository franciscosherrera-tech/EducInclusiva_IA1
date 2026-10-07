class StudyMaterial {
  final String id;
  final String subjectId;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileName;
  final String uploadedBy;
  final DateTime createdAt;

  StudyMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileName,
    this.uploadedBy = '',
    required this.createdAt,
  });

  factory StudyMaterial.fromMap(Map<String, dynamic> map) {
    return StudyMaterial(
      id: map['id']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      fileUrl: map['file_url']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? '',
      uploadedBy: map['uploaded_by']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'file_name': fileName,
      'uploaded_by': uploadedBy,
    };
  }

  factory StudyMaterial.fromJson(Map<String, dynamic> json) =>
      StudyMaterial.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
