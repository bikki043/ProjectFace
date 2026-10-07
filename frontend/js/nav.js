function activateView(viewName) {
  document.querySelectorAll('.tab-btn').forEach(button => {
    const isActive = button.dataset.view === viewName;
    button.classList.toggle('active', isActive);
    button.setAttribute('aria-pressed', String(isActive));
  });
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.getElementById('view-' + viewName).classList.add('active');

  localStorage.setItem('lastView', viewName);

}

document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => activateView(btn.dataset.view));
});

// ตอนโหลดหน้าเว็บ ให้กลับไปหน้าที่ค้างไว้ล่าสุด
const lastView = localStorage.getItem('lastView');
if (lastView && document.getElementById('view-' + lastView)) {
  activateView(lastView);
}