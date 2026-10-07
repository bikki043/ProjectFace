"""
main.py
--------
FastAPI application หลักของระบบ
รวม endpoint ทั้งหมด: enrollment, recognition, ดูประวัติ, dashboard, export

วิธีรัน:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

จากนั้นเข้า http://localhost:8000/docs เพื่อดู Swagger UI (ทดสอบ API ได้ทันที)
"""

import json
import datetime
import base64
import os
from zoneinfo import ZoneInfo
from typing import List

from fastapi import FastAPI, Depends, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import or_
from sqlalchemy.orm import Session

from database import init_db, get_db, User, FaceEmbedding, AttendanceLog, Payslip
import face_service
import auth

app = FastAPI(title="Face Attendance System", version="1.0")

# อนุญาตให้ frontend (คนละ origin เช่น เปิดจาก Live Server) เรียก API ได้
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

init_db()
UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)
THAILAND_TZ = ZoneInfo("Asia/Bangkok")


def to_thailand_time(value: datetime.datetime) -> datetime.datetime:
    """แปลงเวลา UTC แบบ naive จาก SQLite เป็นเวลาไทยแบบมี timezone"""
    return value.replace(tzinfo=datetime.timezone.utc).astimezone(THAILAND_TZ)


# ---------- Pydantic schemas สำหรับรับ-ส่งข้อมูล ----------

class EnrollRequest(BaseModel):
    full_name: str
    position: str = ""
    images_base64: List[str]  # รับได้หลายรูป (multi-shot enrollment)


class RecognizeRequest(BaseModel):
    image_base64: str
    # หมายเหตุ: ไม่ต้องส่ง log_type มาอีกต่อไป — backend เป็นคนตัดสินใจเองว่าเป็น
    # check-in หรือ check-out โดยดูจาก log ล่าสุดของคนคนนั้น (ดูฟังก์ชัน determine_log_type)


class UserOut(BaseModel):
    id: int
    employee_id: str | None
    full_name: str
    position: str | None
    profile_image_path: str | None
    phone: str | None = None
    employment_status: str | None = None
    pay_basis: str = "daily"
    monthly_salary: float = 0
    daily_wage: float = 0
    overtime_rate: float = 0
    created_at: datetime.datetime | None = None
    class Config:
        from_attributes = True


class EmployeeUpdateRequest(BaseModel):
    full_name: str
    position: str = ""
    phone: str = ""
    employment_status: str = "Active"
    pay_basis: str | None = None
    monthly_salary: float = 0
    daily_wage: float = 0
    overtime_rate: float = 0


class PayrollEntryRequest(BaseModel):
    user_id: int
    year: int
    month: int
    other_additions: float = 0
    tax_deduction: float = 0
    social_security_deduction: float = 0
    other_deductions: float = 0


def require_admin(current_user: User = Depends(auth.get_current_user)) -> User:
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="ต้องใช้สิทธิ์ผู้ดูแลระบบ")
    return current_user


class LoginRequest(BaseModel):
    employee_id: str
    password: str


class SetPasswordRequest(BaseModel):
    employee_id: str
    new_password: str
    admin_secret: str  # กันไม่ให้ใครก็ได้มาตั้งรหัสผ่านแทนคนอื่น
    
class UpdateProfileRequest(BaseModel):
    name: str
    phone: str

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

# TODO: ย้ายไป environment variable ก่อนขึ้น production เหมือน SECRET_KEY
ADMIN_SETUP_SECRET = os.environ.get("ADMIN_SETUP_SECRET", "dev-only-admin-secret-change-me")

# ระยะเวลาที่ต้องรอ หลังสแกนครั้งก่อน ก่อนจะสแกนครั้งถัดไปได้ (กันสแกนซ้ำโดยไม่ตั้งใจ)
COOLDOWN_MINUTES = 2
NEW_SESSION_GAP_HOURS = 18


def determine_log_type(db: Session, user_id: int) -> tuple[str | None, bool, int]:
    """
    ตัดสินใจแทน frontend ว่าการสแกนครั้งนี้ควรเป็น check-in หรือ check-out
    โดยดูจาก log ล่าสุดของคนคนนี้ (ไม่จำกัดแค่วันนี้ เพราะกะข้ามวันก็ยังทำงานถูกต้อง)

    คืนค่า (log_type, blocked, seconds_remaining):
    - ยังไม่เคยมี log เลย -> ("check-in", False, 0)
    - มี log ล่าสุด และผ่านมาแล้ว >= COOLDOWN_MINUTES -> (ประเภทตรงข้ามกับล่าสุด, False, 0)
    - มี log ล่าสุด แต่ยังไม่ถึง COOLDOWN_MINUTES -> (None, True, วินาทีที่เหลือ)
    """
    logs = (
        db.query(AttendanceLog)
        .filter(AttendanceLog.user_id == user_id)
        .order_by(AttendanceLog.timestamp.asc())
        .all()
    )

    if not logs:
        return "check-in", False, 0

    now_utc = datetime.datetime.utcnow()
    elapsed_seconds = (now_utc - logs[-1].timestamp).total_seconds()
    cooldown_seconds = COOLDOWN_MINUTES * 60

    if elapsed_seconds < cooldown_seconds:
        return None, True, int(cooldown_seconds - elapsed_seconds)

    previous_timestamp = None
    previous_type = None
    for log in logs:
        gap_seconds = (
            (log.timestamp - previous_timestamp).total_seconds()
            if previous_timestamp is not None
            else None
        )
        if gap_seconds is None or gap_seconds >= NEW_SESSION_GAP_HOURS * 60 * 60:
            inferred_type = "check-in"
        else:
            inferred_type = "check-out" if previous_type == "check-in" else "check-in"
        previous_timestamp = log.timestamp
        previous_type = inferred_type

    if elapsed_seconds >= NEW_SESSION_GAP_HOURS * 60 * 60:
        return "check-in", False, 0

    next_type = "check-out" if previous_type == "check-in" else "check-in"
    return next_type, False, 0


def upsert_daily_attendance_scan(
    db: Session,
    user_id: int,
    log_type: str,
    confidence_score: float,
    timestamp: datetime.datetime | None = None,
) -> tuple[AttendanceLog, bool]:
    """Keep at most one check-in and one check-out record per Thailand-local day."""
    scan_time = timestamp or datetime.datetime.utcnow()
    local_day = to_thailand_time(scan_time).date()
    local_start = datetime.datetime.combine(local_day, datetime.time.min, tzinfo=THAILAND_TZ)
    local_end = local_start + datetime.timedelta(days=1)
    utc_start = local_start.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    utc_end = local_end.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    day_logs = (
        db.query(AttendanceLog)
        .filter(
            AttendanceLog.user_id == user_id,
            AttendanceLog.timestamp >= utc_start,
            AttendanceLog.timestamp < utc_end,
        )
        .order_by(AttendanceLog.timestamp.desc(), AttendanceLog.id.desc())
        .all()
    )

    slots: dict[str, list[AttendanceLog]] = {"check-in": [], "check-out": []}
    for existing in day_logs:
        if existing.log_type in slots:
            slots[existing.log_type].append(existing)

    target_slot = slots[log_type]
    replaced = bool(target_slot)
    if target_slot:
        saved_log = target_slot[0]
        saved_log.timestamp = scan_time
        saved_log.confidence_score = confidence_score
        for duplicate in target_slot[1:]:
            db.delete(duplicate)
    else:
        saved_log = AttendanceLog(
            user_id=user_id,
            timestamp=scan_time,
            log_type=log_type,
            confidence_score=confidence_score,
        )
        db.add(saved_log)

    for slot_type, records in slots.items():
        if slot_type == log_type or not records:
            continue
        for duplicate in records[1:]:
            db.delete(duplicate)

    db.flush()
    return saved_log, replaced


# ---------- Endpoints ----------

@app.get("/")
def root():
    from fastapi.responses import FileResponse

    return FileResponse(os.path.join(os.path.dirname(__file__), "..", "frontend", "user.html"))


@app.get("/user")
def user_page():
    from fastapi.responses import FileResponse

    return FileResponse(os.path.join(os.path.dirname(__file__), "..", "frontend", "user.html"))


@app.get("/admin")
@app.get("/admin/login")
def admin_login_page():
    from fastapi.responses import FileResponse

    return FileResponse(os.path.join(os.path.dirname(__file__), "..", "frontend", "admin-login.html"))


@app.get("/admin/dashboard")
def admin_dashboard_page():
    from fastapi.responses import FileResponse

    return FileResponse(os.path.join(os.path.dirname(__file__), "..", "frontend", "admin-dashboard.html"))


@app.post("/api/enroll")
def enroll_user(payload: EnrollRequest, db: Session = Depends(get_db)):
    """
    ลงทะเบียนผู้ใช้ใหม่พร้อมรูปใบหน้า (รับได้หลายรูปเพื่อความแม่นยำ)
    ขั้นตอน: สร้าง user -> สกัด embedding จากแต่ละรูป -> เก็บลง DB
    """
    if not payload.images_base64:
        raise HTTPException(status_code=400, detail="กรุณาส่งรูปอย่างน้อย 1 รูป")

    user = User(full_name=payload.full_name, position=payload.position)
    db.add(user)
    db.commit()
    db.refresh(user)

    # สร้างรหัสพนักงานอัตโนมัติจาก id ที่ auto-increment ได้ (เช่น id=1 -> "001")
    user.employee_id = f"{user.id:03d}"
    db.commit()

    saved_count = 0
    errors = []
    for idx, img_b64 in enumerate(payload.images_base64):
        try:
            img = face_service.decode_base64_image(img_b64)
            embedding = face_service.extract_embedding(img)
            face_emb = FaceEmbedding(
                user_id=user.id,
                embedding=json.dumps(embedding),
                model_name=face_service.MODEL_NAME,
            )
            db.add(face_emb)
            if user.profile_image_path is None:
                image_data = img_b64.split(",", 1)[-1]
                image_path = os.path.join(UPLOADS_DIR, f"user_{user.id}.jpg")
                with open(image_path, "wb") as image_file:
                    image_file.write(base64.b64decode(image_data))
                user.profile_image_path = f"/uploads/user_{user.id}.jpg"
            saved_count += 1
        except Exception as e:
            errors.append(f"รูปที่ {idx + 1}: ไม่พบใบหน้า หรือประมวลผลไม่สำเร็จ ({str(e)})")

    db.commit()

    if saved_count == 0:
        # ไม่มีรูปไหนใช้ได้เลย ลบ user ทิ้งเพื่อไม่ให้ค้างข้อมูลเปล่า
        db.delete(user)
        db.commit()
        raise HTTPException(status_code=400, detail={"message": "ไม่สามารถลงทะเบียนได้ ไม่พบใบหน้าในรูปใดเลย", "errors": errors})

    return {
        "message": f"ลงทะเบียนสำเร็จ: {user.full_name}",
        "user_id": user.id,
        "employee_id": user.employee_id,
        "images_saved": saved_count,
        "images_failed": len(errors),
        "errors": errors,
    }


@app.post("/api/recognize")
def recognize_face(payload: RecognizeRequest, db: Session = Depends(get_db)):
    """
    สแกนใบหน้าเพื่อเช็คอิน/เช็คเอาท์
    ขั้นตอน: สกัด embedding จากรูปที่ส่งมา -> เทียบกับทุกคนในระบบ -> ถ้าตรง บันทึก log
    """
    try:
        img = face_service.decode_base64_image(payload.image_base64)
        query_embedding = face_service.extract_embedding(img)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"ไม่พบใบหน้าในภาพ: {str(e)}")

    # ดึง embedding ของทุกคนมาเทียบ
    all_embeddings = {}
    rows = db.query(FaceEmbedding).all()
    for row in rows:
        all_embeddings.setdefault(row.user_id, []).append(row.embedding)

    if not all_embeddings:
        raise HTTPException(status_code=404, detail="ยังไม่มีผู้ใช้ลงทะเบียนในระบบ")

    matched_user_id, score = face_service.find_best_match(query_embedding, all_embeddings)

    if matched_user_id is None:
        return {
            "matched": False,
            "message": "ไม่รู้จักใบหน้านี้ กรุณาลงทะเบียนก่อน",
            "confidence": round(score * 100, 2),
        }

    user = db.query(User).filter(User.id == matched_user_id).first()

    log_type, blocked, seconds_remaining = determine_log_type(db, user.id)

    if blocked:
        # จำหน้าคนได้ แต่ยังไม่ถึงเวลาที่อนุญาตให้สแกนซ้ำ -> ไม่บันทึก log ใหม่
        minutes_left = seconds_remaining // 60
        seconds_left = seconds_remaining % 60
        return {
            "matched": True,
            "on_cooldown": True,
            "user_id": user.id,
            "employee_id": user.employee_id,
            "full_name": user.full_name,
            "confidence": round(score * 100, 2),
            "seconds_remaining": seconds_remaining,
            "message": f"สแกนไปแล้วเมื่อครู่ กรุณารออีก {minutes_left} นาที {seconds_left} วินาที",
        }

    log, replaced_existing = upsert_daily_attendance_scan(
        db,
        user_id=user.id,
        log_type=log_type,
        confidence_score=round(score * 100, 2),
    )
    db.commit()

    return {
        "matched": True,
        "on_cooldown": False,
        "user_id": user.id,
        "employee_id": user.employee_id,
        "full_name": user.full_name,
        "position": user.position,
        "confidence": round(score * 100, 2),
        "log_type": log_type,
        "replaced_existing": replaced_existing,
        "message": "อัปเดตเวลาสแกนรายการเดิมแล้ว" if replaced_existing else "บันทึกเวลาสแกนแล้ว",
        "timestamp": to_thailand_time(log.timestamp).isoformat(),
    }


@app.get("/api/users", response_model=List[UserOut])
def list_users(
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """แสดงรายชื่อผู้ใช้ทั้งหมดในระบบ"""
    return db.query(User).filter(User.is_admin.is_(False)).order_by(User.id.desc()).all()


@app.patch("/api/users/{user_id}", response_model=UserOut)
def update_user(
    user_id: int,
    payload: EmployeeUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id, User.is_admin.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบพนักงาน")
    if not payload.full_name.strip():
        raise HTTPException(status_code=400, detail="กรุณาระบุชื่อพนักงาน")
    if payload.employment_status not in {"Active", "On Leave", "Inactive"}:
        raise HTTPException(status_code=400, detail="สถานะพนักงานไม่ถูกต้อง")
    pay_basis = payload.pay_basis or ("monthly" if payload.monthly_salary > 0 else "daily")
    if pay_basis not in {"daily", "monthly"}:
        raise HTTPException(status_code=400, detail="ประเภทค่าจ้างไม่ถูกต้อง")
    if any(value < 0 for value in (payload.monthly_salary, payload.daily_wage, payload.overtime_rate)):
        raise HTTPException(status_code=400, detail="อัตราค่าจ้างต้องไม่ติดลบ")
    user.full_name = payload.full_name.strip()
    user.position = payload.position.strip() or None
    user.phone = payload.phone.strip() or None
    user.employment_status = payload.employment_status.strip() or "Active"
    user.pay_basis = pay_basis
    user.monthly_salary = payload.monthly_salary
    user.daily_wage = payload.daily_wage
    user.overtime_rate = payload.overtime_rate
    db.commit()
    db.refresh(user)
    return user


@app.delete("/api/users/{user_id}")
def delete_user(
    user_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id, User.is_admin.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบผู้ใช้")
    if user.profile_image_path:
        image_path = os.path.join(os.path.dirname(__file__), user.profile_image_path.lstrip("/"))
        if os.path.isfile(image_path):
            os.remove(image_path)
    db.delete(user)
    db.commit()
    return {"message": f"ลบผู้ใช้ {user.full_name} เรียบร้อย"}


@app.get("/api/logs")
def get_logs(
    limit: int = 100,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """ดึงประวัติการเข้า-ออกงานล่าสุด (เรียงใหม่ไปเก่า)"""
    logs = (
        db.query(AttendanceLog)
        .order_by(AttendanceLog.timestamp.desc())
        .limit(limit)
        .all()
    )
    result = []
    for log in logs:
        result.append({
            "id": log.id,
            "user_id": log.user_id,
            "employee_id": log.user.employee_id if log.user else "-",
            "full_name": log.user.full_name if log.user else "ไม่ทราบชื่อ",
            "profile_image_path": log.user.profile_image_path if log.user else None,
            "timestamp": to_thailand_time(log.timestamp).isoformat(),
            "log_type": log.log_type,
            "confidence_score": log.confidence_score,
        })
    return result


@app.get("/api/dashboard/summary")
def dashboard_summary(
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """สรุปข้อมูลภาพรวมสำหรับหน้า dashboard"""
    employees = db.query(User).filter(User.is_admin.is_(False))
    total_users = employees.count()
    active_statuses = ("", "Active", "พนักงานประจำ (Active)")
    is_active = or_(User.employment_status.is_(None), User.employment_status.in_(active_statuses))
    active_users = employees.filter(is_active).count()
    thailand_today = datetime.datetime.now(THAILAND_TZ).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    utc_today = thailand_today.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    today_logs = db.query(AttendanceLog).filter(AttendanceLog.timestamp >= utc_today)
    total_logs_today = today_logs.count()
    checkins_today = today_logs.filter(AttendanceLog.log_type == "check-in").count()
    checkouts_today = today_logs.filter(AttendanceLog.log_type == "check-out").count()
    checked_in_employees = db.query(AttendanceLog.user_id).join(User).filter(
        AttendanceLog.timestamp >= utc_today,
        AttendanceLog.log_type == "check-in",
        User.is_admin.is_(False),
        is_active,
    ).distinct().count()
    total_logs_all = db.query(AttendanceLog).count()

    return {
        "total_users": total_users,
        "active_users": active_users,
        "checkins_today": total_logs_today,
        "checkin_events_today": checkins_today,
        "checkout_events_today": checkouts_today,
        "checked_in_employees": checked_in_employees,
        "employees_pending": max(0, active_users - checked_in_employees),
        "attendance_rate": round(checked_in_employees / active_users * 100, 1) if active_users else 0,
        "total_logs": total_logs_all,
    }


@app.get("/api/logs/export")
def export_logs_csv(
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Export ประวัติเข้า-ออกเป็นไฟล์ CSV"""
    import pandas as pd
    from fastapi.responses import FileResponse

    logs = db.query(AttendanceLog).order_by(AttendanceLog.timestamp.desc()).all()
    data = [{
        "employee_id": log.user.employee_id if log.user else "",
        "user_id": log.user_id,
        "full_name": log.user.full_name if log.user else "",
        "timestamp": to_thailand_time(log.timestamp).isoformat(),
        "log_type": log.log_type,
        "confidence_score": log.confidence_score,
    } for log in logs]

    df = pd.DataFrame(data)
    export_path = "attendance_export.csv"
    df.to_csv(export_path, index=False, encoding="utf-8-sig")  # utf-8-sig ให้ Excel เปิดภาษาไทยได้ถูกต้อง
    return FileResponse(export_path, filename="attendance_export.csv", media_type="text/csv")


def calculate_payroll_estimate(
    db: Session,
    user: User,
    year: int,
    month: int,
) -> dict:
    if not 1 <= month <= 12 or not 2000 <= year <= 2100:
        raise HTTPException(status_code=400, detail="เดือนหรือปีไม่ถูกต้อง")

    period_start = datetime.datetime(year, month, 1, tzinfo=THAILAND_TZ)
    next_month_start = (
        datetime.datetime(year + 1, 1, 1, tzinfo=THAILAND_TZ)
        if month == 12
        else datetime.datetime(year, month + 1, 1, tzinfo=THAILAND_TZ)
    )
    utc_start = period_start.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    utc_end = next_month_start.astimezone(datetime.timezone.utc).replace(tzinfo=None)
    logs = (
        db.query(AttendanceLog)
        .filter(AttendanceLog.user_id == user.id, AttendanceLog.timestamp < utc_end)
        .order_by(AttendanceLog.timestamp.asc())
        .all()
    )

    open_check_in = None
    previous_scan_time = None
    previous_scan_type = None
    days: dict[datetime.date, dict] = {}
    minimum_shift_seconds = 2 * 60

    for log in logs:
        local_time = to_thailand_time(log.timestamp)
        gap_seconds = (
            (local_time - previous_scan_time).total_seconds()
            if previous_scan_time is not None
            else None
        )
        if gap_seconds is None:
            scan_type = log.log_type
        elif gap_seconds >= NEW_SESSION_GAP_HOURS * 60 * 60:
            scan_type = "check-in"
            open_check_in = None
        else:
            scan_type = "check-out" if previous_scan_type == "check-in" else "check-in"

        previous_scan_time = local_time
        previous_scan_type = scan_type

        if scan_type == "check-in":
            in_pay_period = period_start <= local_time < next_month_start
            day_sessions = days.setdefault(local_time.date(), {"sessions": []})["sessions"] if in_pay_period else []
            current_session = day_sessions[0] if day_sessions else {}
            current_session.update({
                "check_in": local_time,
                "check_out": None,
                "duration_seconds": None,
                "elapsed_seconds": None,
                "is_complete": False,
            })
            open_check_in = current_session
            if in_pay_period and not day_sessions:
                day_sessions.append(current_session)
        elif scan_type == "check-out" and open_check_in is not None:
            check_in_time = open_check_in["check_in"]
            duration = max(0, int((local_time - check_in_time).total_seconds()))
            open_check_in["check_out"] = local_time
            open_check_in["duration_seconds"] = duration
            open_check_in["is_complete"] = True
            open_check_in = None

    now_thai = datetime.datetime.now(THAILAND_TZ)
    if open_check_in is not None:
        check_in_time = open_check_in["check_in"]
        if period_start <= check_in_time < next_month_start:
            open_check_in["elapsed_seconds"] = max(0, int((now_thai - check_in_time).total_seconds()))

    completed_days = 0
    work_seconds = 0
    overtime_seconds = 0
    attendance_days = []
    scheduled_workdays = 0
    elapsed_scheduled_days = 0
    attended_workdays = 0
    attended_workday_dates: set[datetime.date] = set()
    scheduled_dates: list[datetime.date] = []
    current_local_date = datetime.datetime.now(THAILAND_TZ).date()
    period_last_day = (next_month_start - datetime.timedelta(days=1)).date()
    attendance_cutoff = min(current_local_date, period_last_day)
    current_day = period_start.date()
    while current_day <= period_last_day:
        if current_day.weekday() < 5:
            scheduled_dates.append(current_day)
        current_day += datetime.timedelta(days=1)
    scheduled_workdays = len(scheduled_dates)
    elapsed_scheduled_days = sum(day <= attendance_cutoff for day in scheduled_dates)

    for workday, day_data in sorted(days.items(), reverse=True):
        sessions = day_data["sessions"]
        daily_seconds = sum(
            session["duration_seconds"] or 0
            for session in sessions
            if session["is_complete"]
        )
        day_qualifies = daily_seconds >= minimum_shift_seconds
        daily_overtime_seconds = max(0, daily_seconds - minimum_shift_seconds) if day_qualifies else 0
        if daily_seconds >= minimum_shift_seconds:
            completed_days += 1
            work_seconds += daily_seconds
            overtime_seconds += daily_overtime_seconds
            if workday.weekday() < 5:
                attended_workday_dates.add(workday)
                attended_workdays += 1
        session_details = []
        for session in sessions:
            duration_seconds = session.get("duration_seconds")
            if duration_seconds is None:
                duration_seconds = session.get("elapsed_seconds", 0)
            session_details.append({
                "check_in": session["check_in"].isoformat(),
                "check_out": session["check_out"].isoformat() if session["check_out"] else None,
                "duration_minutes": round(duration_seconds / 60, 2),
                "is_complete": session["is_complete"],
            })
        day_overtime_minutes = daily_overtime_seconds / 60
        attendance_days.append({
            "date": workday.isoformat(),
            "sessions": session_details,
            "worked_minutes": round(daily_seconds / 60, 2),
            "completed_sessions": sum(1 for session in sessions if session["is_complete"]),
            "is_qualifying_day": day_qualifies,
            "is_scheduled_workday": workday.weekday() < 5,
            "is_absent": (
                workday.weekday() < 5
                and workday <= attendance_cutoff
                and workday not in attended_workday_dates
            ),
            "overtime_minutes": round(day_overtime_minutes, 2),
            "overtime_pay": round((daily_overtime_seconds / 3600) * float(user.overtime_rate or 0), 2),
        })

    for workday in scheduled_dates:
        if workday > attendance_cutoff or workday in days:
            continue
        attendance_days.append({
            "date": workday.isoformat(),
            "sessions": [],
            "worked_minutes": 0,
            "completed_sessions": 0,
            "is_qualifying_day": False,
            "is_scheduled_workday": True,
            "is_absent": True,
            "overtime_minutes": 0,
            "overtime_pay": 0,
        })

    attendance_days.sort(key=lambda day: day["date"], reverse=True)

    daily_pay = completed_days * float(user.daily_wage or 0)
    monthly_salary = float(user.monthly_salary or 0)
    base_pay = (
        daily_pay
        if user.pay_basis == "daily"
        else round(monthly_salary * attended_workdays / scheduled_workdays, 2) if scheduled_workdays else 0
    )
    overtime_hours = overtime_seconds / 3600
    overtime_pay = round(overtime_hours * float(user.overtime_rate or 0), 2)
    return {
        "user_id": user.id,
        "employee_id": user.employee_id,
        "full_name": user.full_name,
        "year": year,
        "month": month,
        "pay_basis": user.pay_basis,
        "monthly_salary": float(user.monthly_salary or 0),
        "daily_wage": float(user.daily_wage or 0),
        "overtime_rate": float(user.overtime_rate or 0),
        "completed_days": completed_days,
        "scheduled_workdays": scheduled_workdays,
        "elapsed_scheduled_days": elapsed_scheduled_days,
        "attended_workdays": attended_workdays,
        "absence_days": max(0, elapsed_scheduled_days - attended_workdays),
        "work_minutes": round(work_seconds / 60, 2),
        "overtime_minutes": round(overtime_seconds / 60, 2),
        "overtime_hours": round(overtime_hours, 4),
        "base_pay": round(base_pay, 2),
        "daily_pay": round(daily_pay, 2),
        "overtime_pay": overtime_pay,
        "attendance_days": attendance_days,
    }


@app.get("/api/payroll/estimate")
def payroll_estimate(
    user_id: int,
    year: int,
    month: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id, User.is_admin.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบพนักงาน")
    return calculate_payroll_estimate(db, user, year, month)


@app.get("/api/payroll")
def list_payroll(
    year: int | None = None,
    month: int | None = None,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Payslip).join(User).filter(User.is_admin.is_(False))
    if year is not None:
        query = query.filter(Payslip.year == year)
    if month is not None:
        query = query.filter(Payslip.month == month)
    payslips = query.order_by(Payslip.year.desc(), Payslip.month.desc(), User.full_name).all()
    return [{
        "id": item.id,
        "user_id": item.user_id,
        "employee_id": item.user.employee_id,
        "full_name": item.user.full_name,
        "year": item.year,
        "month": item.month,
        "pay_basis": item.pay_basis or item.user.pay_basis,
        "base_salary": item.base_salary,
        "overtime_pay": item.overtime_pay,
        "other_additions": item.other_additions,
        "tax_deduction": item.tax_deduction,
        "social_security_deduction": item.social_security_deduction,
        "other_deductions": item.other_deductions,
        "net_salary": item.net_salary,
    } for item in payslips]


@app.post("/api/payroll")
def save_payroll(
    payload: PayrollEntryRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    amounts = (
        payload.other_additions,
        payload.tax_deduction,
        payload.social_security_deduction,
        payload.other_deductions,
    )
    if not 1 <= payload.month <= 12 or not 2000 <= payload.year <= 2100:
        raise HTTPException(status_code=400, detail="เดือนหรือปีไม่ถูกต้อง")
    if any(amount < 0 for amount in amounts):
        raise HTTPException(status_code=400, detail="จำนวนเงินต้องไม่ติดลบ")
    user = db.query(User).filter(User.id == payload.user_id, User.is_admin.is_(False)).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบพนักงาน")
    estimate = calculate_payroll_estimate(db, user, payload.year, payload.month)

    item = db.query(Payslip).filter_by(
        user_id=user.id,
        year=payload.year,
        month=payload.month,
    ).first()
    if item is None:
        item = Payslip(user_id=user.id, year=payload.year, month=payload.month)
        db.add(item)
    item.base_salary = estimate["base_pay"]
    item.pay_basis = estimate["pay_basis"]
    item.overtime_pay = estimate["overtime_pay"]
    item.other_additions = payload.other_additions
    item.tax_deduction = payload.tax_deduction
    item.social_security_deduction = payload.social_security_deduction
    item.other_deductions = payload.other_deductions
    item.net_salary = max(
        0,
        item.base_salary
        + item.overtime_pay
        + item.other_additions
        - item.tax_deduction
        - item.social_security_deduction
        - item.other_deductions,
    )
    db.commit()
    db.refresh(item)
    return {
        "id": item.id,
        "base_salary": item.base_salary,
        "pay_basis": item.pay_basis,
        "overtime_pay": item.overtime_pay,
        "net_salary": item.net_salary,
        "completed_days": estimate["completed_days"],
        "overtime_hours": estimate["overtime_hours"],
        "message": "บันทึกเงินเดือนแล้ว",
    }


# ---------- Auth: login พนักงาน ----------

@app.post("/auth/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """พนักงาน login ด้วยรหัสพนักงาน + รหัสผ่าน คืน JWT token"""
    user = db.query(User).filter(User.employee_id == payload.employee_id).first()

    if payload.employee_id == "admin" and payload.password == "admin123":
        if user is None:
            user = db.query(User).filter(User.employee_id == "admin").first()
        if user is None:
            user = User(
                employee_id="admin",
                full_name="Administrator",
                position="Admin",
                is_admin=True,
                hashed_password=auth.hash_password("admin123"),
            )
            db.add(user)
            db.commit()
            db.refresh(user)

    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail="รหัสพนักงานหรือรหัสผ่านไม่ถูกต้อง")

    if not auth.verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="รหัสพนักงานหรือรหัสผ่านไม่ถูกต้อง")

    token = auth.create_access_token(user.id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "employee_id": user.employee_id,
            "full_name": user.full_name,
            "position": user.position,
            "is_admin": bool(user.is_admin),
        },
    }


@app.post("/auth/set-password")
def set_password(payload: SetPasswordRequest, db: Session = Depends(get_db)):
    """
    ตั้ง/รีเซ็ตรหัสผ่านให้พนักงาน (ใช้สำหรับตั้งรหัสผ่านครั้งแรกให้พนักงานเก่าที่ยังไม่มี
    หรือแอดมินช่วยรีเซ็ตให้เวลาลืมรหัสผ่าน)
    ต้องใส่ admin_secret ให้ถูกต้อง กันคนนอกมาตั้งรหัสผ่านแทนคนอื่น
    """
    if payload.admin_secret != ADMIN_SETUP_SECRET:
        raise HTTPException(status_code=403, detail="admin_secret ไม่ถูกต้อง")

    user = db.query(User).filter(User.employee_id == payload.employee_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="ไม่พบพนักงานรหัสนี้")

    user.hashed_password = auth.hash_password(payload.new_password)
    db.commit()
    return {"message": f"ตั้งรหัสผ่านให้ {user.full_name} เรียบร้อย"}


# ---------- แอปพนักงาน: ดูประวัติของตัวเอง ----------

@app.get("/attendance/me")
def my_attendance(
    month: int | None = None,
    year: int | None = None,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """พนักงาน login แล้วดูประวัติเข้า-ออกงานของตัวเองเท่านั้น กรองตามเดือน/ปีได้"""
    query = db.query(AttendanceLog).filter(AttendanceLog.user_id == current_user.id)

    if month and year:
        start = datetime.datetime(year, month, 1)
        end = datetime.datetime(year + (1 if month == 12 else 0), (month % 12) + 1, 1)
        query = query.filter(AttendanceLog.timestamp >= start, AttendanceLog.timestamp < end)

    logs = query.order_by(AttendanceLog.timestamp.desc()).all()
    return [
        {
            "id": log.id,
            "timestamp": to_thailand_time(log.timestamp).isoformat(),
            "log_type": log.log_type,
            "confidence_score": log.confidence_score,
        }
        for log in logs
    ]


@app.get("/payroll/me")
def my_payslips(
    year: int | None = None,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """พนักงาน login แล้วดูสลิปเงินเดือนของตัวเองเท่านั้น กรองตามปีได้"""
    query = db.query(Payslip).filter(Payslip.user_id == current_user.id)
    if year:
        query = query.filter(Payslip.year == year)

    payslips = query.order_by(Payslip.year.desc(), Payslip.month.desc()).all()
    return [
        {
            "id": p.id,
            "year": p.year,
            "month": p.month,
            "pay_basis": p.pay_basis or current_user.pay_basis,
            "base_salary": p.base_salary,
            "overtime_pay": p.overtime_pay,
            "other_additions": p.other_additions,
            "tax_deduction": p.tax_deduction,
            "social_security_deduction": p.social_security_deduction,
            "other_deductions": p.other_deductions,
            "net_salary": p.net_salary,
            "pdf_path": p.pdf_path,
        }
        for p in payslips
    ]


@app.get("/payroll/me/estimate")
def my_payroll_estimate(
    year: int | None = None,
    month: int | None = None,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """Return the signed-in employee's current scan-based payroll estimate."""
    now = datetime.datetime.now(THAILAND_TZ)
    estimate_year = year or now.year
    estimate_month = month or now.month
    estimate = calculate_payroll_estimate(db, current_user, estimate_year, estimate_month)
    issued = db.query(Payslip).filter_by(
        user_id=current_user.id,
        year=estimate_year,
        month=estimate_month,
    ).first()
    additions = float(issued.other_additions or 0) if issued else 0
    tax = float(issued.tax_deduction or 0) if issued else 0
    social = float(issued.social_security_deduction or 0) if issued else 0
    deductions = float(issued.other_deductions or 0) if issued else 0
    return {
        **estimate,
        "other_additions": additions,
        "tax_deduction": tax,
        "social_security_deduction": social,
        "other_deductions": deductions,
        "net_pay": max(0, estimate["base_pay"] + estimate["overtime_pay"] + additions - tax - social - deductions),
        "is_finalized": issued is not None,
        "updated_at": issued.created_at.isoformat() if issued and issued.created_at else None,
    }


def build_avatar_url(request: Request, path: str | None) -> str | None:
    """แปลง path สัมพัทธ์ที่เก็บใน DB (เช่น /uploads/user_1.jpg) ให้เป็น URL เต็ม
    ที่ Flutter เอาไปใช้กับ NetworkImage ได้ตรงๆ"""
    if not path:
        return None
    return str(request.base_url).rstrip("/") + path


def profile_dict(request: Request, user: User) -> dict:
    return {
        "employee_id": user.employee_id,
        "name": user.full_name,
        "phone": user.phone or "",
        "position": user.position or "",
        "employment_status": user.employment_status or "พนักงานประจำ (Active)",
        "avatar_url": build_avatar_url(request, user.profile_image_path),
    }


@app.get("/employee/me")
def get_my_profile(
    request: Request,
    current_user: User = Depends(auth.get_current_user),
):
    """พนักงาน login แล้วดึงข้อมูลโปรไฟล์ของตัวเอง"""
    return profile_dict(request, current_user)


@app.patch("/employee/me")
def update_my_profile(
    payload: UpdateProfileRequest,
    request: Request,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):

    """พนักงาน login แล้วแก้ไขชื่อ/เบอร์โทรของตัวเอง"""
    current_user.full_name = payload.name
    current_user.phone = payload.phone
    db.commit()
    db.refresh(current_user)
    return profile_dict(request, current_user)

@app.post("/employee/me/change-password")
def change_my_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """พนักงาน login แล้วเปลี่ยนรหัสผ่านของตัวเอง ต้องใส่รหัสผ่านเดิมให้ถูกก่อน"""
    if not current_user.hashed_password or not auth.verify_password(
        payload.current_password, current_user.hashed_password
    ):
        raise HTTPException(status_code=401, detail="รหัสผ่านเดิมไม่ถูกต้อง")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร")

    current_user.hashed_password = auth.hash_password(payload.new_password)
    db.commit()
    return {"message": "เปลี่ยนรหัสผ่านสำเร็จ"}

@app.post("/employee/me/avatar")
async def upload_my_avatar(
    request: Request,
    avatar: UploadFile = File(...),
    current_user: User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """พนักงาน login แล้วเปลี่ยนรูปโปรไฟล์ของตัวเอง"""
    ext = os.path.splitext(avatar.filename or "")[1].lower() or ".jpg"
    if ext not in (".jpg", ".jpeg", ".png", ".webp"):
        raise HTTPException(status_code=400, detail="รองรับเฉพาะไฟล์ .jpg .jpeg .png .webp")

    filename = f"user_{current_user.id}_avatar{ext}"
    file_path = os.path.join(UPLOADS_DIR, filename)

    contents = await avatar.read()
    with open(file_path, "wb") as f:
        f.write(contents)

    current_user.profile_image_path = f"/uploads/{filename}"
    db.commit()

    return {"avatar_url": build_avatar_url(request, current_user.profile_image_path)}

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOADS_DIR),
    name="uploads",
)

app.mount(
    "/",
    StaticFiles(directory=os.path.join(os.path.dirname(__file__), "..", "frontend"), html=True),
    name="frontend",
)