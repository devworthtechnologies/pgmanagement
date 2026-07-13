// settings.dart
class Setting {
  final String key;
  String value;

  Setting({required this.key, required this.value});

  Map<String, dynamic> toMap() => {'key': key, 'value': value};

  factory Setting.fromMap(Map<String, dynamic> map) => Setting(key: map['key'], value: map['value']);
}