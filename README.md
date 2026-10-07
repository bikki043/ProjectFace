# FaceGate — ระบบสแกนใบหน้าเข้า-ออกงาน

โปรเจคจบสาขา IT: เว็บแอปสำหรับลงทะเบียนใบหน้าและสแกนเข้า-ออกงานด้วยกล้องเว็บแคม

## โครงสร้างโปรเจค

```
face-attendance-system/
├── backend/
│   ├── main.py          # FastAPI app + API endpoints ทั้งหมด
│   ├── database.py      # SQLAlchemy models (users, embeddings, logs)
│   └── face_service.py  # ฟังก์ชัน AI: สกัด embedding + เปรียบเทียบใบหน้า
├── frontend/
│   ├── index.html       # shell หลัก: header, navigation และจุดโหลด view
│   ├── views/
│   │   ├── scan.html    # หน้าสแกนเข้า-ออก
│   │   ├── enroll.html  # หน้าลงทะเบียนผู้ใช้
│   │   └── dashboard.html # หน้าสรุปผลและประวัติ
│   ├── css/
│   │   └── styles.css   # สไตล์ทั้งหมดของ frontend
│   ├── js/
│   │   ├── app.js       # loader สำหรับโหลด view
│   │   └── attendance.js # กล้อง, API, ลงทะเบียน และ dashboard
│   ├── sounds/
│   │   └── README.md     # รายละเอียดการเพิ่มเสียง custom
│   └── https_server.py  # server HTTPS สำหรับมือถือ
└── requirements.txt
```

## วิธีติดตั้งและรัน

### 1. ติดตั้ง dependencies (Windows)

โปรเจกต์นี้ใช้ DeepFace และ TensorFlow ซึ่งยังไม่รองรับ Python 3.14 อย่างเหมาะสม ให้ใช้ Python 3.11 และสร้าง virtual environment ก่อนติดตั้ง:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

ถ้า PowerShell แจ้งว่าไม่อนุญาตให้รันสคริปต์ ให้เปิด PowerShell แบบผู้ใช้ปัจจุบันแล้วรันครั้งเดียว:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

จากนั้นเปิด terminal ใหม่และ activate `.venv` อีกครั้ง

### 1.1 ติดตั้ง dependencies (macOS / Linux)

```bash
python3 -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

หมายเหตุ: การติดตั้งครั้งแรกจะโหลดโมเดล DeepFace (Facenet512) อัตโนมัติตอนใช้งานครั้งแรก อาจใช้เวลาสักครู่และต้องต่ออินเทอร์เน็ต

### 2. รัน backend

```bash
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- ตรวจสอบว่าทำงานได้ที่ http://localhost:8000
- ดู API docs (Swagger) อัตโนมัติที่ http://localhost:8000/docs — มีประโยชน์มากตอนทดสอบ/สอบ demo
- ฐานข้อมูล SQLite (`attendance.db`) จะถูกสร้างอัตโนมัติในโฟลเดอร์ backend ตอนรันครั้งแรก

### 3. เปิด frontend

เปิดไฟล์ `frontend/index.html` ผ่านเบราว์เซอร์ตรงๆ ได้เลย หรือใช้ local server เช่น:

```bash
cd frontend
python3 -m http.server 5500
```

แล้วเข้า http://localhost:5500

### ใช้งานจากมือถือใน Wi-Fi เดียวกัน

1. ให้คอมพิวเตอร์และมือถือเชื่อมต่อ Wi-Fi เดียวกัน
2. รัน backend และ frontend ให้รับการเชื่อมต่อจากเครือข่าย:

```powershell
# Terminal 1
Push-Location backend
..\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 --ssl-keyfile ..\.cert\facegate-key.pem --ssl-certfile ..\.cert\facegate.pem

# Terminal 2
Push-Location frontend
..\.venv\Scripts\python.exe https_server.py
```

3. ดู IPv4 ของคอมด้วย `ipconfig` แล้วเปิด URL นี้บนมือถือ โดยแทนที่ IP ให้ตรงกับเครื่อง:

```text
https://192.168.1.39:5500
```

หน้าเว็บจะเลือก API ของคอมให้อัตโนมัติ หาก Windows Firewall ถาม ให้กดอนุญาตบนเครือข่าย Private ครั้งแรกมือถืออาจเตือน certificate ให้กด Advanced แล้วดำเนินการต่อ หรือเพิ่มไฟล์ root CA จาก `C:\Users\bikki\AppData\Local\mkcert\rootCA.pem` ในการตั้งค่าความปลอดภัยของมือถือ

**สำคัญ:** `getUserMedia` (การเข้าถึงกล้อง) ใช้งานได้เฉพาะบน `https://` หรือ `localhost` เท่านั้น ถ้าเปิดไฟล์ตรงๆ (`file://`) บางเบราว์เซอร์อาจบล็อกกล้อง แนะนำให้รันผ่าน local server เสมอ

## วิธีใช้งาน

1. ไปที่แท็บ **"ลงทะเบียนใหม่"** → กรอกชื่อ-ตำแหน่ง → ถ่ายรูป 3-5 มุม (หน้าตรง/เอียงซ้าย/เอียงขวา) → กดบันทึก
2. ไปที่แท็บ **"สแกนเข้า-ออก"** → กดปุ่มเช็คอิน/เช็คเอาท์ ระบบจะจับภาพและตรวจว่าเป็นใคร
3. ไปที่แท็บ **"ประวัติ & สรุปผล"** → ดูสถิติและ export เป็น CSV ได้

## จุดที่ปรับแต่งได้ (สำหรับพัฒนาต่อ / เขียนในรายงาน)

| จุด | ไฟล์ | รายละเอียด |
|---|---|---|
| Threshold ความคล้าย | `backend/face_service.py` → `SIMILARITY_THRESHOLD` | ค่าเริ่มต้น 0.65 ปรับตามความแม่นยำที่ต้องการ ยิ่งสูงยิ่งเข้มงวด (false positive น้อยลง แต่ false negative มากขึ้น) |
| โมเดล face recognition | `backend/face_service.py` → `MODEL_NAME` | เปลี่ยนเป็น `"ArcFace"` หรือ `"VGG-Face"` ได้ตามที่ DeepFace รองรับ |
| Detector backend | `backend/face_service.py` → `DETECTOR_BACKEND` | เปลี่ยนเป็น `"retinaface"` เพื่อความแม่นยำสูงขึ้น (แต่ช้าลง) |
| ฐานข้อมูล | `backend/database.py` → `DATABASE_URL` | เปลี่ยนจาก SQLite เป็น PostgreSQL ได้โดยไม่ต้องแก้โค้ดส่วนอื่น |

## สิ่งที่ยังไม่ได้ทำ (พูดถึงในรายงานได้ว่าเป็น "future work")

- **Liveness detection** — ป้องกันการเอารูปถ่าย/วิดีโอมาหลอกระบบ (เช่น ให้กระพริบตาหรือหันหน้า)
- **Authentication สำหรับแอดมิน** — ตอนนี้ทุกคนเข้าถึง API ได้หมด ควรเพิ่ม JWT login ก่อนใช้งานจริง
- **การเข้ารหัสข้อมูลใบหน้า** — เนื่องจากข้อมูลใบหน้าเป็นข้อมูลอ่อนไหว ควรเข้ารหัส embedding ก่อนเก็บลงฐานข้อมูลจริง และขอ consent จากผู้ใช้ก่อนลงทะเบียน
- **Deploy จริง** — ต้องมี HTTPS (เช่น Let's Encrypt) เพราะ `getUserMedia` ต้องใช้ HTTPS นอกเหนือจาก localhost
