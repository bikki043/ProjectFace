"""
auth.py
--------
จัดการเรื่อง authentication สำหรับแอปพนักงาน (แยกจากระบบสแกนหน้าที่ไม่ต้อง login)

- hash / verify รหัสผ่านด้วย bcrypt (ไม่เก็บรหัสผ่านแบบ plain text)
- ออกและตรวจสอบ JWT token (พนักงาน login ครั้งเดียว ได้ token ใช้เรียก API อื่นไปเรื่อยๆ)

⚠️ สำคัญก่อนขึ้น production:
1. เปลี่ยน SECRET_KEY เป็นค่าสุ่มที่ยาวและเก็บเป็นความลับ (เช่นใน environment variable)
   สร้างได้ด้วยคำสั่ง: python -c "import secrets; print(secrets.token_hex(32))"
2. อย่า commit SECRET_KEY ลง git
"""

import os
import datetime
from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from database import get_db, User

# TODO: เปลี่ยนเป็นค่าสุ่มจริงและย้ายไป environment variable ก่อนขึ้น production
SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-only-secret-please-change-this-1234567890")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # token อยู่ได้ 7 วัน (พนักงานไม่ต้อง login บ่อย)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ใช้ระบุว่า endpoint ไหนต้องแนบ Authorization: Bearer <token>
# HTTPBearer ทำให้ปุ่ม Authorize ใน Swagger (/docs) มีแค่ช่องให้แปะ token ตรงๆ
# (ต่างจาก OAuth2PasswordBearer ที่จะเด้งฟอร์ม username/password ซึ่งไม่ตรงกับ endpoint แบบ JSON ของเรา)
bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(plain_password: str) -> str:
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: int) -> str:
    expire = datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """
    Dependency ใส่ใน endpoint ไหนก็ได้ที่ต้องการให้ "ต้อง login ก่อนถึงจะเรียกได้"
    ตรวจ token จาก header Authorization: Bearer <token>
    คืนค่า User object ของคนที่ login อยู่ (ใช้กรองข้อมูลเฉพาะของตัวเอง)
    """
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="กรุณาเข้าสู่ระบบ",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise credentials_error

    token = credentials.credentials

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise credentials_error
    except JWTError:
        raise credentials_error

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise credentials_error

    return user