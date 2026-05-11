class ModelTimeOffAddTimeOffType {
  final int id;
  final String name;

  ModelTimeOffAddTimeOffType({required this.id, required this.name});

  factory ModelTimeOffAddTimeOffType.fromNameSearch(dynamic json) {
    if (json is List && json.length >= 2) {
      return ModelTimeOffAddTimeOffType(id: json[0], name: json[1]);
    }

    return ModelTimeOffAddTimeOffType(id: 0, name: '');
  }
}
