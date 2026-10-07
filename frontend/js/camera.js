export async function startCamera(videoEl, statusEl) {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480 } });
    videoEl.srcObject = stream;
    statusEl.textContent = "กล้องพร้อมใช้งาน";
    statusEl.classList.add('live');
  } catch (err) {
    statusEl.textContent = "ไม่สามารถเข้าถึงกล้องได้";
  }
}

export function triggerCaptureFlash() {
  const stage = document.querySelector('.camera-stage') || document.querySelector('.cam-wrap');
  if (!stage) return;
  const flash = document.createElement('div');
  flash.className = 'capture-flash';
  stage.appendChild(flash);
  flash.addEventListener('animationend', () => flash.remove());
}