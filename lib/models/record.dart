class Record {
  final int? id;
  final DateTime dateTime;
  final String category;
  final bool isIncome;
  final double amount;
  final String? note;

  Record({
    this.id,
    required this.dateTime,
    required this.category,
    required this.isIncome,
    required this.amount,
    this.note,
  });

  factory Record.fromMap(Map<String, Object?> map) => Record(
        id: map['id'] as int?,
        dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int),
        category: map['category'] as String,
        isIncome: (map['isIncome'] as int) == 1,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'category': category,
        'isIncome': isIncome ? 1 : 0,
        'amount': amount,
        'note': note,
      };
}
