"""
migrate_add_profile_fields.py
-------------------------------
สคริปต์ migration เพิ่มคอลัมน์สำหรับฟีเจอร์ "แก้ไขโปรไฟล์" ในแอปพนักงาน
(หน้าโปรไฟล์ที่ให้แก้เบอร์โทร + ดูสถานะการทำงาน)

สิ่งที่สคริปต์นี้ทำ:
1. เพิ่มคอลัมน์ phone ในตาราง users (ถ้ายังไม่มี)
2. เพิ่มคอลัมน์ employment_status ในตาราง users (ถ้ายังไม่มี) พร้อมค่าเริ่มต้น
   "พนักงานประจำ (Active)" ให้ทุกแถวที่มีอยู่เดิม

ปลอดภัยกับข้อมูลเดิม: ไม่ลบ ไม่แก้ไขข้อมูลที่มีอยู่ (นอกจากตั้งค่าเริ่มต้นให้คอลัมน์ใหม่)
รันซ้ำได้หลายครั้งไม่พัง (idempotent) เหมือน migrate_add_payroll.py

วิธีใช้:
    1. สำรองไฟล์ attendance.db ก่อนเสมอ (cp attendance.db attendance.db.backup)
    2. วางไฟล์นี้ไว้ใน backend/ (โฟลเดอร์เดียวกับ database.py)
    3. รันคำสั่ง: python migrate_add_profile_fields.py
"""

import sqlite3
import sys
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "attendance.db")
DEFAULT_EMPLOYMENT_STATUS = "พนักงานประจำ (Active)"


def column_exists(cursor, table, column):
    cursor.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cursor.fetchall())


def migrate(db_path: str):
    if not os.path.exists(db_path):
        print(f"ไม่พบไฟล์ฐานข้อมูล: {db_path}")
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    if column_exists(cursor, "users", "phone"):
        print("[ข้าม] คอลัมน์ phone มีอยู่แล้วในตาราง users")
    else:
        cursor.execute("ALTER TABLE users ADD COLUMN phone VARCHAR")
        print("[สำเร็จ] เพิ่มคอลัมน์ phone ในตาราง users")

    if column_exists(cursor, "users", "employment_status"):
        print("[ข้าม] คอลัมน์ employment_status มีอยู่แล้วในตาราง users")
    else:
        cursor.execute("ALTER TABLE users ADD COLUMN employment_status VARCHAR")
        cursor.execute(
            "UPDATE users SET employment_status = ? WHERE employment_status IS NULL",
            (DEFAULT_EMPLOYMENT_STATUS,),
        )
        print("[สำเร็จ] เพิ่มคอลัมน์ employment_status ในตาราง users (ตั้งค่าเริ่มต้นให้แถวเดิมแล้ว)")

    conn.commit()
    conn.close()
    print("\nMigration เสร็จสมบูรณ์ ✅")


if __name__ == "__main__":
    migrate(DB_PATH)