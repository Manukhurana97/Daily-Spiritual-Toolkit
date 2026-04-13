class Mantra {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Mantra({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Mantra.fromMap(Map<String, dynamic> map) => Mantra(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Mantra copyWith({int? id, String? name, DateTime? createdAt}) => Mantra(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Mantra && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
