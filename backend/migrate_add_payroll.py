"""
migrate_add_payroll.py
------------------------
สคริปต์ migration สำหรับอัปเดตฐานข้อมูล attendance.db ที่มีอยู่แล้ว
ให้รองรับฟีเจอร์ "แอปพนักงาน" (login + ดูสลิปเงินเดือน)

สิ่งที่สคริปต์นี้ทำ:
1. เพิ่มคอลัมน์ hashed_password ในตาราง users (ถ้ายังไม่มี)
2. สร้างตาราง payslips ใหม่ (ถ้ายังไม่มี)

ปลอดภัยกับข้อมูลเดิม: ไม่ลบ ไม่แก้ไขข้อมูลที่มีอยู่ รันซ้ำได้หลายครั้งไม่พัง (idempotent)

วิธีใช้:
    1. สำรองไฟล์ attendance.db ก่อนเสมอ (cp attendance.db attendance.db.backup)
    2. วางไฟล์นี้ไว้ใน backend/ (โฟลเดอร์เดียวกับ database.py)
    3. รันคำสั่ง: python migrate_add_payroll.py
"""

import sqlite3
import sys
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "attendance.db")


def column_exists(cursor, table, column):
    cursor.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cursor.fetchall())


def table_exists(cursor, table):
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,)
    )
    return cursor.fetchone() is not None


def migrate(db_path: str):
    if not os.path.exists(db_path):
        print(f"ไม่พบไฟล์ฐานข้อมูล: {db_path}")
        sys.exit(1)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # 1) เพิ่มคอลัมน์ hashed_password ในตาราง users
    if column_exists(cursor, "users", "hashed_password"):
        print("[ข้าม] คอลัมน์ hashed_password มีอยู่แล้วในตาราง users")
    else:
        cursor.execute("ALTER TABLE users ADD COLUMN hashed_password VARCHAR")
        print("[สำเร็จ] เพิ่มคอลัมน์ hashed_password ในตาราง users")

    # 2) สร้างตาราง payslips
    if table_exists(cursor, "payslips"):
        print("[ข้าม] ตาราง payslips มีอยู่แล้ว")
    else:
        cursor.execute("""
            CREATE TABLE payslips (
                id INTEGER PRIMARY KEY,
                user_id INTEGER NOT NULL,
                year INTEGER NOT NULL,
                month INTEGER NOT NULL,
                base_salary FLOAT NOT NULL DEFAULT 0,
                overtime_pay FLOAT NOT NULL DEFAULT 0,
                other_additions FLOAT NOT NULL DEFAULT 0,
                tax_deduction FLOAT NOT NULL DEFAULT 0,
                social_security_deduction FLOAT NOT NULL DEFAULT 0,
                other_deductions FLOAT NOT NULL DEFAULT 0,
                net_salary FLOAT NOT NULL DEFAULT 0,
                pdf_path VARCHAR,
                created_at DATETIME,
                FOREIGN KEY (user_id) REFERENCES users (id),
                UNIQUE (user_id, year, month)
            )
        """)
        print("[สำเร็จ] สร้างตาราง payslips")

    conn.commit()
    conn.close()
    print("\nMigration เสร็จสมบูรณ์ ✅")


if __name__ == "__main__":
    migrate(DB_PATH)