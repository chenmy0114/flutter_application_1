class Category {
  final int? id;
  final String name;
  final int order;

  Category({this.id, required this.name, required this.order});

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        order: (map['ordering'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'ordering': order,
      };
}
