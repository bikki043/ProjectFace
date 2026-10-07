import { API_BASE, thailandDateTime, thailandTime, showToast, getThaiDateKey } from './utils.js?v=20260909c';

let rawUsersList = [];
const DEFAULT_AVATAR = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56"%3E%3Crect width="56" height="56" fill="%23131A22"/%3E%3Ccircle cx="28" cy="22" r="10" fill="%238A97A6"/%3E%3Cpath d="M10 52c2-12 10-18 18-18s16 6 18 18" fill="%238A97A6"/%3E%3C/svg%3E';

let allUsers = [];
let sortKey = 'emp_id';
let sortDir = 1;
let searchTerm = '';

function empIdLabel(user) {
  return user.employee_id || '-';
}

function renderRegisteredUsers(users) {
  allUsers = users;
  drawRegisteredTable();
}

function drawRegisteredTable() {
  const tbody = document.getElementById('registered-users');
  const empty = document.getElementById('registered-empty');
  const table = document.getElementById('registered-users-table');
  const countEl = document.getElementById('registered-count');

  let rows = allUsers.filter(u =>
    (u.employee_id || '').toLowerCase().includes(searchTerm) ||
    u.full_name.toLowerCase().includes(searchTerm) ||
    (u.position || '').toLowerCase().includes(searchTerm)
  );

  rows.sort((a, b) => {
    let av = '';
    let bv = '';
    if (sortKey === 'emp_id') { av = a.employee_id || ''; bv = b.employee_id || ''; }
    else if (sortKey === 'name') { av = a.full_name; bv = b.full_name; }
    else { av = a.position || ''; bv = b.position || ''; }
    return av.toLowerCase().localeCompare(bv.toLowerCase(), 'th') * sortDir;
  });

  countEl.textContent = `${rows.length} คน`;
  tbody.innerHTML = '';

  if (rows.length === 0) {
    table.style.display = 'none';
    empty.style.display = 'block';
    empty.textContent = searchTerm ? 'ไม่พบผู้ใช้ที่ค้นหา' : 'ยังไม่มีผู้ลงทะเบียน';
    return;
  }
  table.style.display = 'table';
  empty.style.display = 'none';

  rows.forEach(user => {
    const tr = document.createElement('tr');

    // คอลัมน์ รหัสพนักงาน
    const empTd = document.createElement('td');
    empTd.innerHTML = `<span class="emp-id-badge">${empIdLabel(user)}</span>`;

    const nameTd = document.createElement('td');
    const cell = document.createElement('div');
    cell.className = 'user-cell';
    const image = document.createElement('img');
    image.src = user.profile_image_path ? `${API_BASE}${user.profile_image_path}?v=${Date.now()}` : DEFAULT_AVATAR;
    image.alt = `รูปของ ${user.full_name}`;
    const name = document.createElement('div');
    name.className = 'user-name';
    name.textContent = user.full_name;
    cell.append(image, name);
    nameTd.appendChild(cell);

    const posTd = document.createElement('td');
    posTd.className = 'user-position';
    posTd.textContent = user.position || 'ไม่ได้ระบุตำแหน่ง';

    const actionTd = document.createElement('td');
    actionTd.style.textAlign = 'right';
    const deleteButton = document.createElement('button');
    deleteButton.className = 'delete-user';
    deleteButton.type = 'button';
    deleteButton.textContent = 'ลบ';
    deleteButton.addEventListener('click', () => deleteUser(user.id, user.full_name));
    actionTd.appendChild(deleteButton);

    tr.append(empTd, nameTd, posTd, actionTd);
    tr.addEventListener('click', (e) => {
      if (e.target.closest('.delete-user')) return;
      showUserDetail(user);
    });
    tbody.appendChild(tr);
  });
}

document.getElementById('registered-search-input').addEventListener('input', (e) => {
  searchTerm = e.target.value.trim().toLowerCase();
  drawRegisteredTable();
});

document.querySelectorAll('#registered-users-table th[data-sort]').forEach(th => {
  th.addEventListener('click', () => {
    const key = th.dataset.sort;
    if (sortKey === key) { sortDir *= -1; } else { sortKey = key; sortDir = 1; }
    document.querySelectorAll('#registered-users-table th[data-sort]').forEach(h => h.classList.remove('sorted'));
    th.classList.add('sorted');
    th.querySelector('.sort-arrow').textContent = sortDir === 1 ? '▲' : '▼';
    drawRegisteredTable();
  });
});

// ฟังก์ชันเปิด Modal พร้อมแมปข้อมูลตรงกับการสมัคร
function showUserDetail(user) {
  const modal = document.getElementById('user-detail-modal');
  if (!modal) return;
  const img = document.getElementById('modal-user-img');

  img.src = user.profile_image_path ? `${API_BASE}${user.profile_image_path}` : DEFAULT_AVATAR;
  img.onerror = () => { img.src = DEFAULT_AVATAR; };

  const positionText = user.position || 'ไม่ได้ระบุตำแหน่ง';

  document.getElementById('modal-user-name').textContent = user.full_name;
  document.getElementById('modal-user-position').textContent = positionText;
  document.getElementById('modal-user-pos-detail').textContent = positionText;
  document.getElementById('modal-user-id').textContent = empIdLabel(user);

  if (user.created_at) {
    document.getElementById('modal-user-created').textContent = thailandDateTime.format(new Date(user.created_at));
  } else {
    document.getElementById('modal-user-created').textContent = 'ไม่มีข้อมูล';
  }

  modal.style.display = 'flex';
}

document.getElementById('close-user-modal')?.addEventListener('click', () => {
  document.getElementById('user-detail-modal').style.display = 'none';
});

document.getElementById('user-detail-modal')?.addEventListener('click', (e) => {
  if (e.target.id === 'user-detail-modal') {
    e.target.style.display = 'none';
  }
});

function computeAttendanceSummary(logs) {
  const todayKey = getThaiDateKey(new Date());
  const todayLogs = logs.filter(l => getThaiDateKey(l.timestamp) === todayKey);

  const byUser = {};
  todayLogs.forEach(l => {
    const key = l.employee_id || l.full_name;
    if (!byUser[key]) byUser[key] = [];
    byUser[key].push(l);
  });

  return Object.keys(byUser).map(key => {
    const entries = byUser[key].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    const checkIns = entries.filter(e => e.log_type === 'check-in');
    const checkOuts = entries.filter(e => e.log_type === 'check-out');
    const firstIn = checkIns.length ? checkIns[0] : null;
    const lastOut = checkOuts.length ? checkOuts[checkOuts.length - 1] : null;

    let totalHours = null;
    if (firstIn && lastOut) {
      const diffMs = new Date(lastOut.timestamp) - new Date(firstIn.timestamp);
      totalHours = diffMs > 0 ? diffMs / 3600000 : null;
    }

    return {
      employeeId: entries[0].employee_id || '-',
      name: entries[0].full_name,
      checkIn: firstIn?.timestamp || null,
      checkOut: lastOut?.timestamp || null,
      totalHours,
    };
  });
}

function formatDuration(hours) {
  if (hours === null || hours === undefined) return '-';
  const h = Math.floor(hours);
  const m = Math.round((hours - h) * 60);
  return `${h} ชม. ${m} นาที`;
}

function renderAttendanceSummary(logs) {
  const summary = computeAttendanceSummary(logs);
  const tbody = document.getElementById('worktime-table-body');
  const empty = document.getElementById('worktime-empty');
  tbody.innerHTML = '';

  if (summary.length === 0) {
    empty.style.display = 'block';
    return;
  }
  empty.style.display = 'none';

  summary.forEach(row => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><span class="emp-id-badge">${row.employeeId}</span></td>
      <td>${row.name}</td>
      <td class="mono">${row.checkIn ? thailandTime.format(new Date(row.checkIn)) : '-'}</td>
      <td class="mono">${row.checkOut ? thailandTime.format(new Date(row.checkOut)) : '-'}</td>
      <td class="mono">${formatDuration(row.totalHours)}</td>
    `;
    tbody.appendChild(tr);
  });
}

export async function loadDashboard() {
  try {
    const summaryRes = await fetch(`${API_BASE}/api/dashboard/summary`);
    const summary = await summaryRes.json();
    document.getElementById('stat-users').textContent = summary.total_users;
    document.getElementById('stat-today').textContent = summary.checkins_today;
    document.getElementById('stat-total').textContent = summary.total_logs;

    const usersRes = await fetch(`${API_BASE}/api/users`);
    rawUsersList = await usersRes.json();
    renderRegisteredUsers(rawUsersList);

    const logsRes = await fetch(`${API_BASE}/api/logs?limit=50`);
    const logs = await logsRes.json();
    const tbody = document.getElementById('logs-table-body');
    tbody.innerHTML = '';
    document.getElementById('logs-empty').style.display = logs.length === 0 ? 'block' : 'none';

    logs.forEach(log => {
      const tr = document.createElement('tr');
      const tagClass = log.log_type === 'check-in' ? 'in' : 'out';
      const tagLabel = log.log_type === 'check-in' ? 'เข้างาน' : 'ออกงาน';
      tr.innerHTML = `
        <td><span class="emp-id-badge">${log.employee_id || '-'}</span></td>
        <td>${log.full_name}</td>
        <td class="mono">${thailandDateTime.format(new Date(log.timestamp))}</td>
        <td><span class="tag ${tagClass}">${tagLabel}</span></td>
        <td class="mono">${log.confidence_score}%</td>
      `;
      tbody.appendChild(tr);
    });

    renderAttendanceSummary(logs);
  } catch (err) {
    showToast("โหลดข้อมูล dashboard ไม่สำเร็จ");
  }
}

async function deleteUser(userId, fullName) {
  if (!window.confirm(`ต้องการลบ ${fullName} ออกจากระบบหรือไม่?`)) return;
  try {
    const response = await fetch(`${API_BASE}/api/users/${userId}`, { method: 'DELETE' });
    const data = await response.json();
    if (!response.ok) {
      showToast(data.detail || 'ลบผู้ใช้ไม่สำเร็จ');
      return;
    }
    showToast('ลบผู้ใช้เรียบร้อย');
    loadDashboard();
  } catch (err) {
    showToast('เชื่อมต่อ Backend ไม่ได้');
  }
}

const searchInput = document.getElementById('search-user-input');
if (searchInput) {
  searchInput.addEventListener('input', (e) => {
    const keyword = e.target.value.toLowerCase().trim();
    const filteredUsers = rawUsersList.filter(user =>
      (user.employee_id || '').toLowerCase().includes(keyword) ||
      user.full_name.toLowerCase().includes(keyword) ||
      (user.position && user.position.toLowerCase().includes(keyword))
    );
    renderRegisteredUsers(filteredUsers);
  });
}

document.getElementById('btn-export').addEventListener('click', (e) => {
  e.preventDefault();
  window.open(`${API_BASE}/api/logs/export`, '_blank');
});

document.getElementById('btn-refresh').addEventListener('click', async (event) => {
  const button = event.currentTarget;
  button.disabled = true;
  button.classList.add('is-loading');
  await loadDashboard();
  button.classList.remove('is-loading');
  button.disabled = false;
  showToast('รีเฟรชข้อมูลแล้ว');
});