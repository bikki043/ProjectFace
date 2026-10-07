import { showToast, captureFrameAsBase64, API_BASE } from './utils.js?v=20260909c';
import { startCamera, triggerCaptureFlash } from './camera.js?v=20260909c';
import { playShutterSound } from './audio.js?v=20260909c';

const enrollVideo = document.getElementById('enroll-video');
startCamera(enrollVideo, document.getElementById('enroll-cam-status'));

let capturedShots = [];

function renderShots(highlightLast = false) {
  const wrap = document.getElementById('enroll-shots');
  wrap.innerHTML = '';
  const shotCount = document.getElementById('shot-count');
  if (shotCount) shotCount.textContent = `${capturedShots.length} ภาพ`;

  capturedShots.forEach((shot, i) => {
    const thumb = document.createElement('div');
    thumb.className = 'shot-thumb';

    const im = document.createElement('img');
    im.src = shot;
    im.alt = `ภาพที่ ${i + 1}`;

    const badge = document.createElement('span');
    badge.className = 'shot-index';
    badge.textContent = i + 1;

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'shot-remove';
    removeBtn.title = 'ลบภาพนี้';
    removeBtn.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none">
        <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
      </svg>
    `;
    removeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      capturedShots.splice(i, 1);
      renderShots();
    });

    thumb.append(im, badge, removeBtn);

    if (highlightLast && i === capturedShots.length - 1) {
      thumb.classList.add('shot-new');
      thumb.addEventListener('animationend', () => thumb.classList.remove('shot-new'), { once: true });
    }

    wrap.appendChild(thumb);
  });

  document.getElementById('btn-submit-enroll').disabled = capturedShots.length === 0;
}

document.getElementById('btn-capture-shot').addEventListener('click', () => {
  try {
    const preview = document.getElementById('enroll-upload-preview');
    const video = document.getElementById('enroll-video');
    if (preview) preview.hidden = true;
    if (video) video.hidden = false;

    const img = captureFrameAsBase64(video || enrollVideo);
    capturedShots.push(img);
    renderShots(true);

    triggerCaptureFlash();
    playShutterSound();
    showToast(`ถ่ายภาพสำเร็จ (${capturedShots.length} ภาพ)`, 1500);
  } catch (err) {
    console.error('ถ่ายภาพไม่สำเร็จ:', err);
    showToast('ถ่ายภาพไม่สำเร็จ กรุณาลองใหม่');
  }
});

document.getElementById('enroll-image-upload').addEventListener('change', event => {
  const files = Array.from(event.target.files || []);
  files.forEach(file => {
    if (!file.type.startsWith('image/')) return;
    const reader = new FileReader();
    reader.addEventListener('load', () => {
      capturedShots.push(reader.result);
      const preview = document.getElementById('enroll-upload-preview');
      const video = document.getElementById('enroll-video');
      preview.src = reader.result;
      preview.hidden = false;
      video.hidden = true;
      document.getElementById('enroll-cam-status').textContent = 'ภาพที่เลือกพร้อมใช้งาน';
      document.getElementById('enroll-cam-status').classList.add('live');
      renderShots(true);
    });
    reader.readAsDataURL(file);
  });
  event.target.value = '';
});

document.getElementById('btn-submit-enroll').addEventListener('click', async () => {
  const name = document.getElementById('enroll-name').value.trim();
  const position = document.getElementById('enroll-position').value.trim();
  if (!name) { showToast("กรุณากรอกชื่อ-นามสกุล"); return; }
  if (capturedShots.length === 0) { showToast("กรุณาถ่ายภาพอย่างน้อย 1 รูป"); return; }

  const btn = document.getElementById('btn-submit-enroll');
  btn.disabled = true; btn.textContent = "กำลังบันทึก...";

  try {
    const res = await fetch(`${API_BASE}/api/enroll`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ full_name: name, position, images_base64: capturedShots })
    });
    const data = await res.json();
    if (!res.ok) {
      showToast((data.detail && data.detail.message) || "ลงทะเบียนไม่สำเร็จ");
    } else {
      showToast(`ลงทะเบียนสำเร็จ (${data.images_saved} รูป)`);
      document.getElementById('enroll-name').value = '';
      document.getElementById('enroll-position').value = '';
      capturedShots = [];
      renderShots();
      document.getElementById('enroll-upload-preview').hidden = true;
      document.getElementById('enroll-video').hidden = false;
      document.getElementById('enroll-cam-status').textContent = 'กล้องพร้อมใช้งาน';
    }
  } catch (err) {
    showToast("เชื่อมต่อ Backend ไม่ได้ ตรวจสอบว่า server รันอยู่");
  } finally {
    btn.textContent = "บันทึกการลงทะเบียน";
    btn.disabled = capturedShots.length === 0;
  }
});