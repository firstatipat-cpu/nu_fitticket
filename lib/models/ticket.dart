/// ตั๋ว NU Fitness หนึ่งใบ — ใช้ได้ 1 วันนับจากเวลาที่ซื้อ
/// เจ้าของ: <67316807>
class Ticket {
  const Ticket({
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.priceCents,
    required this.purchasedAt,
    required this.expiresAt,
    this.slipRef,
  });

  final String code;
  final String studentId;
  final String studentName;
  final int priceCents;
  final int purchasedAt;
  final int expiresAt;

  /// เลขที่รายการของสลิปที่ใช้ยืนยันการโอน (null = ยังไม่ยืนยัน)
  final String? slipRef;

  bool get isPaid => slipRef != null;

  DateTime get purchasedTime =>
      DateTime.fromMillisecondsSinceEpoch(purchasedAt);
  DateTime get expiryTime => DateTime.fromMillisecondsSinceEpoch(expiresAt);
  double get priceBaht => priceCents / 100;

  bool isExpiredAt(DateTime now) => now.isAfter(expiryTime);

  Map<String, Object?> toJson() => {
    'student_id': studentId,
    'student_name': studentName,
    'price_cents': priceCents,
    'purchased_at': purchasedAt,
    'expires_at': expiresAt,
    if (slipRef != null) 'slip_ref': slipRef,
  };

  factory Ticket.fromJson(Map<String, Object?> json) => Ticket(
    code: json['code']! as String,
    studentId: json['student_id']! as String,
    studentName: json['student_name']! as String,
    priceCents: (json['price_cents']! as num).toInt(),
    purchasedAt: (json['purchased_at']! as num).toInt(),
    expiresAt: (json['expires_at']! as num).toInt(),
    slipRef: json['slip_ref'] as String?,
  );

  /// สร้างจากโหนดของ Realtime Database (คีย์ของโหนดคือ code)
  factory Ticket.fromNode(String code, Map<String, Object?> json) =>
      Ticket.fromJson({...json, 'code': code});
}
