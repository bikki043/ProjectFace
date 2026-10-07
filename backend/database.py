"""
database.py
------------
กำหนดโครงสร้างฐานข้อมูล (schema) และการเชื่อมต่อฐานข้อมูล
ใช้ SQLite เพื่อความง่ายในการรัน/เดโม (ไม่ต้องติดตั้ง Postgres)
ถ้าจะขึ้น production จริง เปลี่ยน DATABASE_URL เป็น Postgres ได้ทันที
เพราะ SQLAlchemy รองรับทั้งคู่โดยไม่ต้องแก้โค้ดส่วนอื่น
"""

from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Text, UniqueConstraint, Boolean, text
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
import datetime

DATABASE_URL = "sqlite:///./attendance.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class User(Base):
    """ตารางเก็บข้อมูลผู้ใช้/พนักงาน"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    employee_id = Column(String, unique=True, index=True, nullable=True)
    full_name = Column(String, nullable=False)
    position = Column(String, nullable=True)
    profile_image_path = Column(String, nullable=True)
    phone = Column(String, nullable=True)
    employment_status = Column(String, nullable=True)
    pay_basis = Column(String, nullable=False, default="daily")
    monthly_salary = Column(Float, nullable=False, default=0)
    daily_wage = Column(Float, nullable=False, default=0)
    overtime_rate = Column(Float, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # สำหรับ login เข้าแอปมือถือพนักงาน (แยกจากระบบสแกนหน้าที่ไม่ต้อง login)
    # nullable=True เพราะ user เก่าที่ enroll ไว้แล้วยังไม่มีรหัสผ่าน ต้องตั้งทีหลัง
    hashed_password = Column(String, nullable=True)
    is_admin = Column(Boolean, default=False, nullable=False)

    embeddings = relationship("FaceEmbedding", back_populates="user", cascade="all, delete-orphan")
    logs = relationship("AttendanceLog", back_populates="user", cascade="all, delete-orphan")
    payslips = relationship("Payslip", back_populates="user", cascade="all, delete-orphan")


class FaceEmbedding(Base):
    """ตารางเก็บ embedding ใบหน้า (อาจมีหลายแถวต่อ 1 คน เพราะถ่ายหลายมุม)"""
    __tablename__ = "face_embeddings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    embedding = Column(Text, nullable=False)  # เก็บเป็น JSON string ของ vector ตัวเลข
    model_name = Column(String, default="Facenet512")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="embeddings")


class AttendanceLog(Base):
    """ตารางเก็บประวัติการสแกนเข้า-ออกงาน"""
    __tablename__ = "attendance_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    log_type = Column(String)  # "check-in" หรือ "check-out"
    confidence_score = Column(Float)  # ความมั่นใจของระบบ (%)

    user = relationship("User", back_populates="logs")


class Payslip(Base):
    """ตารางเก็บสลิปเงินเดือนของพนักงานแต่ละเดือน"""
    __tablename__ = "payslips"
    __table_args__ = (
        UniqueConstraint("user_id", "year", "month", name="uq_payslip_user_month"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)  # 1-12
    pay_basis = Column(String, nullable=True)

    base_salary = Column(Float, nullable=False, default=0)       # เงินเดือนฐาน
    overtime_pay = Column(Float, nullable=False, default=0)      # ค่าล่วงเวลา (OT)
    other_additions = Column(Float, nullable=False, default=0)   # เงินได้อื่นๆ เช่น ค่าคอมมิชชั่น เบี้ยขยัน

    tax_deduction = Column(Float, nullable=False, default=0)          # หักภาษี
    social_security_deduction = Column(Float, nullable=False, default=0)  # หักประกันสังคม
    other_deductions = Column(Float, nullable=False, default=0)       # หักอื่นๆ

    net_salary = Column(Float, nullable=False, default=0)  # ยอดสุทธิที่พนักงานได้รับจริง

    pdf_path = Column(String, nullable=True)  # path ไฟล์ PDF สลิป (ถ้ามีการ generate ไว้ล่วงหน้า)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="payslips")


def init_db():
    Base.metadata.create_all(bind=engine)

    with engine.begin() as conn:
        columns = conn.execute(text("PRAGMA table_info(users)")).fetchall()
        existing_columns = {column[1] for column in columns}
        if "is_admin" not in existing_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT 0"))
        for column_name in ("monthly_salary", "daily_wage", "overtime_rate"):
            if column_name not in existing_columns:
                conn.execute(text(
                    f"ALTER TABLE users ADD COLUMN {column_name} FLOAT NOT NULL DEFAULT 0"
                ))
        if "pay_basis" not in existing_columns:
            conn.execute(text("ALTER TABLE users ADD COLUMN pay_basis VARCHAR NOT NULL DEFAULT 'daily'"))
            conn.execute(text(
                "UPDATE users SET pay_basis = CASE WHEN monthly_salary > 0 THEN 'monthly' ELSE 'daily' END"
            ))

        payslip_columns = {column[1] for column in conn.execute(text("PRAGMA table_info(payslips)")).fetchall()}
        if "pay_basis" not in payslip_columns:
            conn.execute(text("ALTER TABLE payslips ADD COLUMN pay_basis VARCHAR"))
            conn.execute(text(
                "UPDATE payslips SET pay_basis = "
                "(SELECT users.pay_basis FROM users WHERE users.id = payslips.user_id)"
            ))

    with SessionLocal() as db:
        from auth import hash_password

        admin = db.query(User).filter(User.employee_id == "admin").first()
        if admin is None:
            admin = User(
                employee_id="admin",
                full_name="Administrator",
                position="Admin",
                is_admin=True,
                hashed_password=hash_password("admin123"),
            )
            db.add(admin)
            db.commit()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()