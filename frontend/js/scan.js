import { API_BASE, thailandTime, captureFrameAsBase64 } from './utils.js?v=20260909c';
import { playAttendanceSound, unlockAudio } from './audio.js?v=20260909c';
import { startCamera, triggerCaptureFlash } from './camera.js?v=20260909c';

const scanVideo = document.getElementById('scan-video');
const camStatusEl = document.getElementById('scan-cam-status');
const countdownEl = document.getElementById('scan-countdown');
const startOverlay = document.getElementById('kiosk-start-overlay');

// โหลด face-api.js จาก CDN (ไม่ต้องติดตั้งอะไรเพิ่มในเครื่อง)
const FACE_API_SCRIPT_URL = 'https://cdn.jsdelivr.net/npm/face-api.js@0.22.2/dist/face-api.min.js';
const FACE_API_MODEL_URL = 'https://cdn.jsdelivr.net/gh/justadudewhohacks/face-api.js@master/weights';

const COUNTDOWN_SECONDS = 3;
const DETECT_INTERVAL_MS = 300;   // ความถี่ในการตรวจจับหน้าในเฟรมวิดีโอ
const FACE_LOST_GRACE_MS = 600;   // เผื่อเฟรมหลุดไปเฟรมเดียว ไม่ให้ยกเลิกการนับทันที
const RESULT_DISPLAY_MS = 4000;   // แสดงผลลัพธ์ค้างไว้กี่ ms ก่อนกลับไปตรวจจับหน้าใหม่

let faceApiReady = false;
let detectTimer = null;
let countdownTimer = null;
let countdownValue = COUNTDOWN_SECONDS;
let lastFaceSeenAt = 0;
let isBusy = false; // true ระหว่างกำลังสแกน/แสดงผลลัพธ์ค้างอยู่ -> พักการตรวจจับหน้าไว้ก่อน

function loadScriptOnce(src) {
  return new Promise((resolve, reject) => {
    if (window.faceapi) { resolve(); return; }
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    script.onerror = () => reject(new Error(`โหลดสคริปต์ไม่สำเร็จ: ${src}`));
    document.head.appendChild(script);
  });
}

async function initFaceApi() {
  try {
    camStatusEl.textContent = 'กำลังเตรียมระบบตรวจจับใบหน้า...';
    await loadScriptOnce(FACE_API_SCRIPT_URL);
    await window.faceapi.nets.tinyFaceDetector.loadFromUri(FACE_API_MODEL_URL);
    faceApiReady = true;
    camStatusEl.textContent = 'กล้องพร้อมใช้งาน';
    camStatusEl.classList.add('live');
    startDetectionLoop();
  } catch (err) {
    console.error('โหลด face-api.js ไม่สำเร็จ:', err);
    camStatusEl.textContent = 'ไม่สามารถโหลดระบบตรวจจับใบหน้าได้ (เช็คอินเทอร์เน็ต)';
  }
}

function startDetectionLoop() {
  clearInterval(detectTimer);
  detectTimer = setInterval(detectFaceTick, DETECT_INTERVAL_MS);
}

async function detectFaceTick() {
  if (isBusy || !faceApiReady) return;
  if (!scanVideo.videoWidth) return;

  const options = new window.faceapi.TinyFaceDetectorOptions({ inputSize: 224, scoreThreshold: 0.5 });
  let detection = null;
  try {
    detection = await window.faceapi.detectSingleFace(scanVideo, options);
  } catch (err) {
    return; // เฟรมพลาดเป็นครั้งคราวได้ ไม่ต้องทำอะไร รอเฟรมถัดไป
  }

  if (isBusy) return; // เผื่อสถานะเปลี่ยนระหว่างรอผล detect (เช่นเริ่ม scan ไปแล้ว)

  if (detection) {
    lastFaceSeenAt = Date.now();
    if (!countdownTimer) startCountdown();
  } else if (countdownTimer && Date.now() - lastFaceSeenAt > FACE_LOST_GRACE_MS) {
    cancelCountdown();
  }
}

function startCountdown() {
  countdownValue = COUNTDOWN_SECONDS;
  updateCountdownDisplay();
  countdownTimer = setInterval(() => {
    countdownValue -= 1;
    if (countdownValue <= 0) {
      clearInterval(countdownTimer);
      countdownTimer = null;
      countdownEl.classList.remove('active');
      runAutoScan();
    } else {
      updateCountdownDisplay();
    }
  }, 1000);
}

function cancelCountdown() {
  clearInterval(countdownTimer);
  countdownTimer = null;
  countdownEl.classList.remove('active');
}

function updateCountdownDisplay() {
  countdownEl.textContent = String(countdownValue);
  countdownEl.classList.add('active');
}

function formatLogType(logType) {
  return logType === 'check-in' ? 'เช็คอิน' : 'เช็คเอาท์';
}

async function runAutoScan() {
  isBusy = true;
  clearInterval(detectTimer); // หยุดตรวจจับหน้าไว้ระหว่างสแกน/แสดงผล

  const img = captureFrameAsBase64(scanVideo);
  triggerCaptureFlash();

  const emptyState = document.getElementById('scan-empty');
  emptyState.style.display = 'none';
  emptyState.hidden = true;
  const box = document.getElementById('scan-result');
  box.style.display = 'block';
  box.className = 'result-box scan-result-card';
  document.getElementById('result-name').textContent = 'กำลังประมวลผล...';
  document.getElementById('result-meta').textContent = '';

  try {
    const res = await fetch(`${API_BASE}/api/recognize`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ image_base64: img })
    });
    const data = await res.json();

    if (!res.ok) {
      playAttendanceSound('check-in', false);
      box.classList.add('fail');
      document.getElementById('result-name').textContent = 'เกิดข้อผิดพลาด';
      document.getElementById('result-meta').textContent = data.detail || 'ไม่สามารถประมวลผลได้';
    } else if (data.matched && data.on_cooldown) {
      // จำหน้าได้ แต่ยังไม่ถึงเวลาที่อนุญาตให้สแกนซ้ำ
      box.classList.add('fail');
      document.getElementById('result-name').textContent = data.full_name;
      document.getElementById('result-meta').textContent = data.message;
    } else if (data.matched) {
      playAttendanceSound(data.log_type, true);
      box.classList.add('ok');
      document.getElementById('result-name').textContent = data.full_name;
      document.getElementById('result-meta').textContent =
        `${data.position || ''} · ${formatLogType(data.log_type)} · ${thailandTime.format(new Date(data.timestamp))}` +
        (data.replaced_existing ? ' · อัปเดตเวลาสแกนเดิมของวันนี้แล้ว' : '');
      document.getElementById('result-confidence-fill').style.width = data.confidence + '%';
      document.getElementById('result-confidence-text').textContent = `ความมั่นใจ: ${data.confidence}%`;
    } else {
      playAttendanceSound('check-in', false);
      box.classList.add('fail');
      document.getElementById('result-name').textContent = 'ไม่รู้จักใบหน้านี้';
      document.getElementById('result-meta').textContent = data.message || 'กรุณาลงทะเบียนก่อนใช้งาน';
      document.getElementById('result-confidence-fill').style.width = (data.confidence || 0) + '%';
      document.getElementById('result-confidence-text').textContent = `ความมั่นใจ: ${data.confidence || 0}%`;
    }
  } catch (err) {
    playAttendanceSound('check-in', false);
    box.classList.add('fail');
    document.getElementById('result-name').textContent = 'เชื่อมต่อ Backend ไม่ได้';
    document.getElementById('result-meta').textContent = 'ตรวจสอบว่า server รันอยู่ที่ ' + API_BASE;
  }

  // แสดงผลลัพธ์ค้างไว้สักพัก แล้วกลับไปพร้อมตรวจจับหน้าคนถัดไป
  setTimeout(() => {
    box.style.display = 'none';
    emptyState.hidden = false;
    emptyState.style.display = 'flex';
    isBusy = false;
    startDetectionLoop();
  }, RESULT_DISPLAY_MS);
}

async function beginKioskSession() {
  unlockAudio(); // ต้องเรียกตรงนี้ ในตัว event handler ของการแตะ เพื่อให้เบราว์เซอร์นับเป็น user gesture
  if (startOverlay) {
    startOverlay.classList.add('hidden');
  }
  await startCamera(scanVideo, camStatusEl);
  await initFaceApi();
}

if (startOverlay) {
  startOverlay.addEventListener('click', beginKioskSession, { once: true });
} else {
  // เผื่อกรณีไม่มี overlay อยู่ในหน้า (fallback) ก็ยังเปิดกล้องได้ตามปกติ
  beginKioskSession();
}