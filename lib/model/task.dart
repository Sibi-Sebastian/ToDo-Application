class Task {
  String task;
  DateTime reminderTime;

  Task({required this.task, required this.reminderTime});

  Map<String, dynamic> toMap() {
    return {
      'task': task,
      'reminderTime': reminderTime.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      task: map['task'],
      reminderTime: DateTime.parse(map['reminderTime']),
    );
  }
}
