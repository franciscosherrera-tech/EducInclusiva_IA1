import '../models/subject.dart';

/// Agrupa las materias por curso ("1° 2da"). Los cursos salen ordenados por
/// año y división; las materias sin curso van al final como "Sin curso asignado".
Map<String, List<Subject>> groupByCourse(List<Subject> subjects) {
  const noCourse = 'Sin curso asignado';
  final groups = <String, List<Subject>>{};
  for (final subject in subjects) {
    final key = '${subject.year} ${subject.division}'.trim();
    groups.putIfAbsent(key.isEmpty ? noCourse : key, () => []).add(subject);
  }

  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      if (a == noCourse) return b == noCourse ? 0 : 1;
      if (b == noCourse) return -1;
      final numA = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '');
      final numB = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '');
      if (numA != null && numB != null && numA != numB) {
        return numA.compareTo(numB);
      }
      return a.compareTo(b);
    });

  return {for (final key in sortedKeys) key: groups[key]!};
}
