import 'dart:convert';
import 'dart:typed_data';

class ModelTimeOffAddEmployees {
  final List<Employee> employees;

  ModelTimeOffAddEmployees({required this.employees});

  factory ModelTimeOffAddEmployees.fromList(List<dynamic> jsonList) {
    return ModelTimeOffAddEmployees(
      employees: jsonList.map((e) => Employee.fromJson(e)).toList(),
    );
  }
}

class Employee {
  final int id;
  final String name;
  final Uint8List? imageBytes;
  final int? departmentId;
  final String? departmentName;

  Employee({
    required this.id,
    required this.name,
    this.imageBytes,
    this.departmentId,
    this.departmentName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    Uint8List? imageBytes;
    int? deptId;
    String? deptName;

    ///  Decode image
    final image = json['image_128'];
    if (image is String && image.isNotEmpty) {
      try {
        imageBytes = base64Decode(image);
      } catch (_) {
        imageBytes = null;
      }
    }

    ///  Handle department_id (List OR false)
    final department = json['department_id'];

    if (department is List && department.isNotEmpty) {
      deptId = department[0];
      if (department.length > 1) {
        deptName = department[1];
      }
    }

    return Employee(
      id: json['id'] ?? 0,
      name: json['display_name'] ?? json['name'] ?? '',
      imageBytes: imageBytes,
      departmentId: deptId,
      departmentName: deptName,
    );
  }
}
