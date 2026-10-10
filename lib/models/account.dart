/// บัญชีผู้ใช้ในเครื่อง (นิสิต หรือ เจ้าหน้าที่)
/// เจ้าของ: <67317088>
enum AccountRole { student, staff }

class Account {
  const Account({required this.login, required this.role, required this.name});

  final String login;
  final AccountRole role;
  final String name;

  bool get isStaff => role == AccountRole.staff;

  factory Account.fromMap(Map<String, Object?> map) => Account(
    login: map['login']! as String,
    role: (map['role']! as String) == 'staff'
        ? AccountRole.staff
        : AccountRole.student,
    name: map['name']! as String,
  );
}
