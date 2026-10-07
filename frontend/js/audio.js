// เสียงแจ้งเตือนตอนสแกนสำเร็จ/ไม่สำเร็จ
// หมายเหตุสำคัญ: ใช้ audio element ตัวเดิมซ้ำ (ไม่สร้าง new Audio() ทุกครั้ง)
// เพราะโหมด kiosk ไม่มีการคลิกปุ่มอีกต่อไป (สแกนอัตโนมัติทั้งหมด)
// เบราว์เซอร์จะบล็อกเสียงถ้าไม่เคยมี user gesture เลย ต้อง "ปลดล็อก" ด้วย unlockAudio()
// ตอนผู้ใช้แตะหน้าจอครั้งแรก (ดู scan.js) หลังจากนั้นเล่นได้ตลอดทั้งวันโดยไม่ต้องแตะซ้ำ

const soundElements = {
  'check-in': new Audio('sounds/check-in.mp3'),
  'check-out': new Audio('sounds/check-out.mp3'),
  'error': new Audio('sounds/error.mp3'),
};

Object.values(soundElements).forEach(audio => {
  audio.preload = 'auto';
  audio.volume = 0.75;
});

let sharedAudioContext = null;

function getSharedAudioContext() {
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return null;
  if (!sharedAudioContext) sharedAudioContext = new AudioContextClass();
  if (sharedAudioContext.state === 'suspended') sharedAudioContext.resume();
  return sharedAudioContext;
}

// เรียกครั้งเดียวตอนผู้ใช้แตะหน้าจอครั้งแรก (user gesture) เพื่อขอสิทธิ์เล่นเสียงอัตโนมัติไปตลอด session
export function unlockAudio() {
  Object.values(soundElements).forEach(audio => {
    const playPromise = audio.play();
    if (playPromise && typeof playPromise.then === 'function') {
      playPromise
        .then(() => {
          audio.pause();
          audio.currentTime = 0;
        })
        .catch(() => {});
    }
  });
  getSharedAudioContext();
}

function playFallbackTone(logType, success) {
  const context = getSharedAudioContext();
  if (!context) return;

  const oscillator = context.createOscillator();
  const gain = context.createGain();
  const startFrequency = success ? (logType === 'check-in' ? 660 : 520) : 180;
  const endFrequency = success ? (logType === 'check-in' ? 880 : 700) : 120;

  oscillator.type = 'sine';
  oscillator.frequency.setValueAtTime(startFrequency, context.currentTime);
  oscillator.frequency.exponentialRampToValueAtTime(endFrequency, context.currentTime + 0.16);
  gain.gain.setValueAtTime(0.0001, context.currentTime);
  gain.gain.exponentialRampToValueAtTime(success ? 0.16 : 0.12, context.currentTime + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.22);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start();
  oscillator.stop(context.currentTime + 0.24);
}

export function playAttendanceSound(logType, success) {
  const key = success ? logType : 'error';
  const audio = soundElements[key];

  if (!audio) {
    playFallbackTone(logType, success);
    return;
  }

  audio.currentTime = 0;
  const playback = audio.play();
  if (playback && typeof playback.then === 'function') {
    playback.catch(() => playFallbackTone(logType, success));
  }
}

export function playShutterSound() {
  const context = getSharedAudioContext();
  if (!context) return;

  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = 'square';
  oscillator.frequency.setValueAtTime(1200, context.currentTime);
  oscillator.frequency.exponentialRampToValueAtTime(400, context.currentTime + 0.08);
  gain.gain.setValueAtTime(0.15, context.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.1);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start();
  oscillator.stop(context.currentTime + 0.1);
}