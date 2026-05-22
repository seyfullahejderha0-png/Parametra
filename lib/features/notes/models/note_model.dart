class NoteEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final List<String> imageUrls;
  final DateTime? reminderDateTime;

  NoteEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.imageUrls = const [],
    this.reminderDateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'imageUrls': imageUrls,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
    };
  }

  factory NoteEntry.fromMap(Map<String, dynamic> map) {
    return NoteEntry(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      reminderDateTime: map['reminderDateTime'] != null ? DateTime.parse(map['reminderDateTime']) : null,
    );
  }
}
