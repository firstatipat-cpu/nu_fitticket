/// โครงสร้างตารางในเครื่อง (SQLite)
/// เจ้าของ: <67316807>
class Schema {
  Schema._();

  static const createTables = <String>[
    '''
    CREATE TABLE IF NOT EXISTS accounts (
      login         TEXT PRIMARY KEY,
      role          TEXT NOT NULL,
      name          TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      salt          TEXT NOT NULL
    )
    ''',
    // เก็บ snapshot ล่าสุดที่ดึงจากคลาวด์ ไว้ใช้ตอนออฟไลน์
    '''
    CREATE TABLE IF NOT EXISTS cache (
      key        TEXT PRIMARY KEY,
      json       TEXT NOT NULL,
      fetched_at INTEGER NOT NULL
    )
    ''',
    // คิวการเขียนที่ยังซิงก์ขึ้นคลาวด์ไม่ได้
    '''
    CREATE TABLE IF NOT EXISTS outbox (
      id   INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL,
      body TEXT NOT NULL,
      ts   INTEGER NOT NULL
    )
    ''',
  ];

  static const seedStaffLogin = 'staff01';
  static const seedStudentLogin = '67000001';
  static const seedPassword = 'test1234';
  static const seedStaffName = 'เจ้าหน้าที่โรงยิม';
  static const seedStudentName = 'นิสิตตัวอย่าง';
}
