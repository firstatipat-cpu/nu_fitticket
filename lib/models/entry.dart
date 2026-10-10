/// บันทึกการเข้าใช้หนึ่งครั้ง (เขียนโดยเครื่องเจ้าหน้าที่)
/// เจ้าของ: <67316807>
class Entry {
  const Entry({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.priceCents,
    required this.ts,
    required this.date,
  });

  final String id;
  final String code;
  final String studentId;
  final String studentName;
  final int priceCents;
  final int ts;

  /// วันที่แบบ yyyy-MM-dd (เวลาเครื่อง) ใช้สำหรับนับ "คนละ 1 ครั้งต่อวัน"
  final String date;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  Map<String, Object?> toJson() => {
    'code': code,
    'student_id': studentId,
    'student_name': studentName,
    'price_cents': priceCents,
    'ts': ts,
    'date': date,
  };

  factory Entry.fromJson(Map<String, Object?> json) => Entry(
    id: json['id']! as String,
    code: json['code']! as String,
    studentId: json['student_id']! as String,
    studentName: json['student_name']! as String,
    priceCents: (json['price_cents']! as num).toInt(),
    ts: (json['ts']! as num).toInt(),
    date: json['date']! as String,
  );

  factory Entry.fromNode(String id, Map<String, Object?> json) =>
      Entry.fromJson({...json, 'id': id});
}
