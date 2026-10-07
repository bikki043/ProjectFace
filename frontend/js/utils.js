export const API_BASE = window.location.origin;
export const THAILAND_TIMEZONE = 'Asia/Bangkok';

export const thailandTime = new Intl.DateTimeFormat('th-TH', {
  timeZone: THAILAND_TIMEZONE,
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

export const thailandDateTime = new Intl.DateTimeFormat('th-TH', {
  timeZone: THAILAND_TIMEZONE,
  dateStyle: 'short',
  timeStyle: 'short',
});

export function showToast(msg, ms = 3000) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.display = 'block';
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.style.display = 'none', ms);
}

export function captureFrameAsBase64(video) {
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  canvas.getContext('2d').drawImage(video, 0, 0);
  return canvas.toDataURL('image/jpeg', 0.9);
}

// key วันแบบ YYYY-MM-DD ตามเวลาไทย ป้องกัน bug กรณี server เป็น UTC
export function getThaiDateKey(dateInput) {
  const d = new Date(dateInput);
  return new Intl.DateTimeFormat('en-CA', { timeZone: THAILAND_TIMEZONE }).format(d);
}