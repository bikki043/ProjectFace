const viewFiles = ['scan', 'enroll', 'dashboard'];

async function loadViews(){
  const viewsRoot = document.getElementById('views-root');
  const views = await Promise.all(
    viewFiles.map(async viewName => {
      const response = await fetch(`views/${viewName}.html?v=20260909c`);
      if(!response.ok) throw new Error(`โหลด view ${viewName} ไม่สำเร็จ`);
      return response.text();
    })
  );
  viewsRoot.innerHTML = views.join('');
}

loadViews()
  .then(() => import('./attendance.js?v=20260909c'))
  .catch(error => {
    const viewsRoot = document.getElementById('views-root');
    viewsRoot.innerHTML = '<div class="load-error">ไม่สามารถโหลดหน้าเว็บได้ กรุณารีเฟรชอีกครั้ง</div>';
    console.error(error);
  });