class ModelLeaveUnusualDays {
  final int length;
  final List<UnusualDay> records;

  ModelLeaveUnusualDays({required this.length, required this.records});

  factory ModelLeaveUnusualDays.fromJson(Map<String, dynamic> json) {
    final records = json.entries
        .map((e) => UnusualDay.fromJson(e.key, e.value))
        .toList();

    return ModelLeaveUnusualDays(length: records.length, records: records);
  }
}

class UnusualDay {
  final DateTime date;
  final bool isUnusual;

  UnusualDay({required this.date, required this.isUnusual});

  factory UnusualDay.fromJson(String dateKey, dynamic value) {
    final parsedDate = DateTime.parse(dateKey);

    return UnusualDay(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      isUnusual: value == true,
    );
  }
}
