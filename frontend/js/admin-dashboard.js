const token = localStorage.getItem('attendance_token');
let allLogs = [];
let allEmployees = [];
let activeView = sessionStorage.getItem('hr_active_view') || 'overview';

if (!token) {
  window.location.href = '/admin/login';
}

function formatLogType(type) {
  return type === 'check-in' ? 'เข้างาน' : 'ออกงาน';
}

function applyLogFilter() {
  const input = document.getElementById('search-input');
  const filterType = document.getElementById('filter-type');

  if (!input || !filterType) {
    return;
  }

  const keyword = input.value.trim().toLowerCase();
  const selectedType = filterType.value;

  const filteredLogs = allLogs.filter((log) => {
    const matchesText = !keyword ||
      (log.employee_id && log.employee_id.toLowerCase().includes(keyword)) ||
      (log.full_name && log.full_name.toLowerCase().includes(keyword)) ||
      (log.log_type && log.log_type.toLowerCase().includes(keyword));
    const matchesType = selectedType === 'all' || log.log_type === selectedType;
    return matchesText && matchesType;
  });

  renderLogs(filteredLogs);
}

function renderLogs(logs) {
  const tbody = document.getElementById('logs-table-body');
  const empty = document.getElementById('logs-empty');
  tbody.innerHTML = '';

  if (!logs.length) {
    empty.style.display = 'block';
    return;
  }

  empty.style.display = 'none';
  logs.forEach((log) => {
    const row = document.createElement('tr');
    const photoCell = document.createElement('td');
    photoCell.className = 'photo-cell';
    if (log.profile_image_path) {
      const photo = document.createElement('img');
      photo.className = 'person-photo';
      photo.src = log.profile_image_path;
      photo.alt = `รูปของ ${log.full_name || 'พนักงาน'}`;
      photo.loading = 'lazy';
      photo.onerror = () => {
        const initials = document.createElement('span');
        initials.className = 'person-initials';
        initials.textContent = (log.full_name || '?').trim().charAt(0).toUpperCase();
        photo.replaceWith(initials);
      };
      photoCell.appendChild(photo);
    } else {
      const initials = document.createElement('span');
      initials.className = 'person-initials';
      initials.textContent = (log.full_name || '?').trim().charAt(0).toUpperCase();
      photoCell.appendChild(initials);
    }

    const employeeCell = document.createElement('td');
    employeeCell.textContent = log.employee_id || '-';
    const nameCell = document.createElement('td');
    nameCell.textContent = log.full_name || '-';
    const timeCell = document.createElement('td');
    timeCell.textContent = new Date(log.timestamp).toLocaleString('th-TH', { dateStyle: 'short', timeStyle: 'short' });
    const typeCell = document.createElement('td');
    const typeTag = document.createElement('span');
    typeTag.className = `tag ${log.log_type === 'check-in' ? 'in' : 'out'}`;
    typeTag.textContent = formatLogType(log.log_type);
    typeCell.appendChild(typeTag);
    const confidenceCell = document.createElement('td');
    confidenceCell.textContent = `${formatPercent(log.confidence_score)}%`;

    row.append(photoCell, employeeCell, nameCell, timeCell, typeCell, confidenceCell);
    tbody.appendChild(row);
  });
}

function renderStatusSummary(summary) {
  document.getElementById('stat-checkin').textContent = summary.checkin_events_today ?? 0;
  document.getElementById('stat-checkout').textContent = summary.checkout_events_today ?? 0;
  document.getElementById('stat-today').textContent = summary.checkins_today ?? 0;
  document.getElementById('status-checkin').textContent = summary.checked_in_employees ?? 0;
  document.getElementById('status-checkout').textContent = summary.checkout_events_today ?? 0;
  document.getElementById('status-pending').textContent = summary.employees_pending ?? 0;
  document.getElementById('attendance-rate').textContent = `${formatPercent(summary.attendance_rate)}%`;
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      ...(options.headers || {}),
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    throw new Error(payload.detail || 'โหลดข้อมูลไม่สำเร็จ');
  }

  return response.json();
}

async function loadSummary() {
  const summary = await fetchJson('/api/dashboard/summary');
  const logs = await fetchJson('/api/logs?limit=200');

  allLogs = logs;

  document.getElementById('stat-users').textContent = summary.total_users ?? 0;
  document.getElementById('stat-total').textContent = summary.total_logs ?? 0;

  renderStatusSummary(summary);
  applyLogFilter();
}

function employeeStatus(employee) {
  const rawStatus = (employee.employment_status || '').toLowerCase();
  if (rawStatus.includes('leave') || rawStatus.includes('ลา')) return 'On Leave';
  if (rawStatus.includes('inactive') || rawStatus.includes('ออก')) return 'Inactive';
  return 'Active';
}

function renderEmployees() {
  const body = document.getElementById('employees-table-body');
  const keyword = document.getElementById('employee-search').value.trim().toLowerCase();
  const statusFilter = document.getElementById('employee-status-filter').value;
  const employees = allEmployees.filter((employee) => {
    const status = employeeStatus(employee);
    const matchesStatus = statusFilter === 'all' || status === statusFilter;
    const searchable = [employee.employee_id, employee.full_name, employee.position, employee.phone]
      .filter(Boolean).join(' ').toLowerCase();
    return matchesStatus && searchable.includes(keyword);
  });

  body.replaceChildren();
  document.getElementById('employee-count').textContent = `${employees.length} จาก ${allEmployees.length} คน`;
  employees.forEach((employee) => {
    const row = document.createElement('tr');
    const status = employeeStatus(employee);
    const statusClass = status === 'Inactive' ? 'inactive' : status === 'On Leave' ? 'leave' : '';
    const values = [
      employee.employee_id || '-',
      employee.full_name || '-',
      employee.position || '-',
      employee.phone || '-',
    ];
    values.forEach((value) => {
      const cell = document.createElement('td');
      cell.textContent = value;
      row.appendChild(cell);
    });
    const statusCell = document.createElement('td');
    const badge = document.createElement('span');
    badge.className = `status-badge ${statusClass}`;
    badge.textContent = status;
    statusCell.appendChild(badge);
    row.appendChild(statusCell);
    const dateCell = document.createElement('td');
    dateCell.textContent = employee.created_at
      ? new Date(employee.created_at).toLocaleDateString('th-TH')
      : '-';
    row.appendChild(dateCell);
    const actionCell = document.createElement('td');
    const editButton = document.createElement('button');
    editButton.className = 'small-btn';
    editButton.type = 'button';
    editButton.textContent = 'แก้ไข';
    editButton.addEventListener('click', () => openEmployeeEditor(employee));
    actionCell.appendChild(editButton);
    row.appendChild(actionCell);
    body.appendChild(row);
  });
}

function renderRates() {
  const body = document.getElementById('rates-table-body');
  const keyword = document.getElementById('rate-search').value.trim().toLowerCase();
  const employees = allEmployees.filter((employee) =>
    `${employee.employee_id || ''} ${employee.full_name || ''}`.toLowerCase().includes(keyword)
  );
  body.replaceChildren();
  document.getElementById('rates-count').textContent = `${employees.length} จาก ${allEmployees.length} คน`;

  employees.forEach((employee) => {
    const row = document.createElement('tr');
    [
      employee.employee_id || '-',
      employee.full_name || '-',
      employee.pay_basis === 'monthly' ? 'รายเดือน' : 'รายวัน',
      formatMoney(employee.monthly_salary),
      formatMoney(employee.daily_wage),
      formatMoney(employee.overtime_rate),
    ].forEach((value) => {
      const cell = document.createElement('td');
      cell.textContent = value;
      row.appendChild(cell);
    });
    const actionCell = document.createElement('td');
    const editButton = document.createElement('button');
    editButton.className = 'small-btn';
    editButton.type = 'button';
    editButton.textContent = 'แก้ไขอัตรา';
    editButton.addEventListener('click', () => openEmployeeEditor(employee));
    actionCell.appendChild(editButton);
    row.appendChild(actionCell);
    body.appendChild(row);
  });
}

async function loadEmployees() {
  const selectedPayrollEmployee = document.getElementById('payroll-employee').value;
  allEmployees = await fetchJson('/api/users');
  renderEmployees();
  renderRates();
  const select = document.getElementById('payroll-employee');
  select.replaceChildren();
  allEmployees.filter((employee) => employeeStatus(employee) !== 'Inactive').forEach((employee) => {
    const option = document.createElement('option');
    option.value = employee.id;
    option.textContent = `${employee.employee_id} - ${employee.full_name}`;
    select.appendChild(option);
  });
  if (allEmployees.some((employee) => String(employee.id) === selectedPayrollEmployee && employeeStatus(employee) !== 'Inactive')) {
    select.value = selectedPayrollEmployee;
  }
  await updatePayrollEstimate();
  await loadSelectedPayrollValues();
}

function openEmployeeEditor(employee) {
  document.getElementById('employee-edit-id').value = employee.id;
  document.getElementById('employee-edit-name').value = employee.full_name || '';
  document.getElementById('employee-edit-position').value = employee.position || '';
  document.getElementById('employee-edit-phone').value = employee.phone || '';
  document.getElementById('employee-edit-status').value = employeeStatus(employee);
  document.getElementById('employee-edit-pay-basis').value = employee.pay_basis || (employee.monthly_salary > 0 ? 'monthly' : 'daily');
  document.getElementById('employee-edit-monthly').value = employee.monthly_salary || 0;
  document.getElementById('employee-edit-daily').value = employee.daily_wage || 0;
  document.getElementById('employee-edit-overtime').value = employee.overtime_rate || 0;
  document.getElementById('employee-edit-notice').textContent = '';
  document.getElementById('employee-dialog').showModal();
}

const monthOptions = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

function populateMonthOptions() {
  ['payroll-month', 'payroll-filter-month'].forEach((id) => {
    const select = document.getElementById(id);
    select.replaceChildren();
    const allOption = document.createElement('option');
    allOption.value = id === 'payroll-filter-month' ? 'all' : '1';
    allOption.textContent = id === 'payroll-filter-month' ? 'ทุกเดือน' : monthOptions[0];
    select.appendChild(allOption);
    monthOptions.forEach((label, index) => {
      if (id === 'payroll-month' && index === 0) return;
      const option = document.createElement('option');
      option.value = String(index + 1);
      option.textContent = label;
      select.appendChild(option);
    });
  });
}

function formatMoney(value) {
  const amount = Number(value || 0);
  return (Number.isFinite(amount) ? amount : 0).toLocaleString('th-TH', {
    maximumFractionDigits: 2,
  });
}

function formatPercent(value) {
  const percentage = Number(value || 0);
  return (Number.isFinite(percentage) ? percentage : 0).toLocaleString('th-TH', {
    maximumFractionDigits: 0,
  });
}

function formatDuration(minutes) {
  const roundedMinutes = Math.round(Number(minutes || 0));
  const hours = Math.floor(roundedMinutes / 60);
  const remainder = roundedMinutes % 60;
  if (hours === 0) return `${remainder} นาที`;
  if (remainder === 0) return `${hours} ชม.`;
  return `${hours} ชม. ${remainder} นาที`;
}

function formatThaiDate(value) {
  return new Date(`${value}T00:00:00+07:00`).toLocaleDateString('th-TH', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Bangkok',
  });
}

function formatThaiTime(value) {
  return new Date(value).toLocaleTimeString('th-TH', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Bangkok',
  });
}

function makeTextElement(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  element.textContent = text;
  return element;
}

function renderPayrollAttendance(estimate, employee) {
  const container = document.getElementById('payroll-attendance-breakdown');
  const identity = document.getElementById('payroll-employee-summary');
  const employeeName = employee?.full_name || 'ไม่พบข้อมูลพนักงาน';
  const employeeCode = employee?.employee_id || '-';
  const payBasis = estimate.pay_basis === 'monthly' ? 'พนักงานรายเดือน' : 'พนักงานรายวัน';
  identity.replaceChildren(
    makeTextElement('strong', '', `${employeeName} · ${employeeCode}`),
    makeTextElement('span', '', `${payBasis} · OT ${formatMoney(estimate.overtime_rate)} บาท/ชั่วโมง`),
  );
  container.replaceChildren();

  const days = estimate.attendance_days || [];
  if (!days.length) {
    container.appendChild(makeTextElement('div', 'breakdown-empty', 'ไม่มีรายการสแกนเข้า-ออกในงวดที่เลือก'));
    return;
  }

  days.forEach((day) => {
    const dayCard = makeTextElement('article', 'attendance-day', '');
    const hasOpenSession = (day.sessions || []).some((session) => !session.is_complete);
    const dayHeader = makeTextElement('div', 'attendance-day-head', '');
    dayHeader.appendChild(makeTextElement('strong', '', formatThaiDate(day.date)));
    const status = estimate.pay_basis === 'monthly' && !day.is_scheduled_workday
      ? makeTextElement('span', 'attendance-state open', 'วันหยุดตามตาราง')
      : day.is_absent
      ? makeTextElement('span', 'attendance-state short', 'ขาดงาน · ไม่คิดฐานเงิน')
      : day.is_qualifying_day
        ? makeTextElement('span', 'attendance-state qualifies', 'มาทำงาน · ผ่านเกณฑ์')
        : makeTextElement('span', `attendance-state ${hasOpenSession ? 'open' : 'short'}`,
          hasOpenSession ? 'กำลังทำงาน' : 'ยังไม่ครบ 2 นาที');
    dayHeader.appendChild(status);
    dayCard.appendChild(dayHeader);

    (day.sessions || []).forEach((session) => {
      const row = makeTextElement('div', 'scan-pair', '');
      row.appendChild(makeTextElement('span', 'scan-time', formatThaiTime(session.check_in)));
      row.appendChild(makeTextElement('span', '', 'เข้า'));
      row.appendChild(makeTextElement('span', 'scan-time', session.check_out ? formatThaiTime(session.check_out) : 'ยังไม่สแกนออก'));
      row.appendChild(makeTextElement('span', '', session.check_out ? 'ออก' : ''));
      row.appendChild(makeTextElement(
        'span',
        'scan-duration',
        session.is_complete
          ? `ระยะเวลา ${formatDuration(session.duration_minutes)}`
          : `กำลังทำงาน ${formatDuration(session.duration_minutes)}`,
      ));
      dayCard.appendChild(row);
    });

    const total = makeTextElement('div', 'attendance-day-total', '');
    total.appendChild(makeTextElement('span', '', `เวลาที่จับคู่ได้ ${formatDuration(day.worked_minutes)}`));
    const overtimeLabel = day.overtime_minutes > 0
      ? `OT ${formatDuration(day.overtime_minutes)} · ${formatMoney(day.overtime_pay)} บาท`
      : 'OT 0 นาที · 0 บาท';
    total.appendChild(makeTextElement('strong', '', overtimeLabel));
    dayCard.appendChild(total);
    container.appendChild(dayCard);
  });
}

async function loadPayroll() {
  const year = document.getElementById('payroll-filter-year').value;
  const month = document.getElementById('payroll-filter-month').value;
  const query = new URLSearchParams();
  if (year) query.set('year', year);
  if (month !== 'all') query.set('month', month);
  const records = await fetchJson(`/api/payroll?${query.toString()}`);
  const body = document.getElementById('payroll-table-body');
  body.replaceChildren();
  document.getElementById('payroll-list-notice').textContent = records.length
    ? `${records.length} รายการ`
    : 'ยังไม่มีรายการเงินเดือนในงวดนี้';
  records.forEach((record) => {
    const row = document.createElement('tr');
    const deductions = Number(record.tax_deduction) + Number(record.social_security_deduction) + Number(record.other_deductions);
    [
      `${monthOptions[record.month - 1]} ${record.year}`,
      record.employee_id,
      record.full_name,
      record.pay_basis === 'monthly' ? 'รายเดือน' : 'รายวัน',
      formatMoney(record.base_salary),
      formatMoney(record.overtime_pay),
      formatMoney(record.other_additions),
      formatMoney(deductions),
      formatMoney(record.net_salary),
    ].forEach((value) => {
      const cell = document.createElement('td');
      cell.textContent = value;
      row.appendChild(cell);
    });
    body.appendChild(row);
  });
}

async function updatePayrollEstimate() {
  const userId = document.getElementById('payroll-employee').value;
  const year = document.getElementById('payroll-year').value;
  const month = document.getElementById('payroll-month').value;
  if (!userId || !year || !month) return;

  const query = new URLSearchParams({ user_id: userId, year, month });
  const estimate = await fetchJson(`/api/payroll/estimate?${query.toString()}`);
  const employee = allEmployees.find((item) => String(item.id) === String(userId));
  document.getElementById('payroll-days-preview').textContent = estimate.pay_basis === 'monthly'
    ? `${estimate.attended_workdays} / ${estimate.scheduled_workdays} วัน`
    : `${estimate.completed_days} วัน`;
  document.getElementById('payroll-absence-preview').textContent = estimate.pay_basis === 'monthly'
    ? `${estimate.absence_days} วัน`
    : 'ไม่ใช้กับรายวัน';
  document.getElementById('payroll-base-preview').textContent = `${formatMoney(estimate.base_pay)} บาท`;
  document.getElementById('payroll-hours-preview').textContent = `${estimate.overtime_hours} ชั่วโมง`;
  document.getElementById('payroll-overtime-preview').textContent = `${formatMoney(estimate.overtime_pay)} บาท`;
  renderPayrollAttendance(estimate, employee);
}

async function loadSelectedPayrollValues() {
  const userId = document.getElementById('payroll-employee').value;
  const year = document.getElementById('payroll-year').value;
  const month = document.getElementById('payroll-month').value;
  if (!userId || !year || !month) return;

  const query = new URLSearchParams({ year, month });
  const records = await fetchJson(`/api/payroll?${query.toString()}`);
  const current = records.find((record) => String(record.user_id) === String(userId));
  document.getElementById('payroll-additions').value = current?.other_additions ?? 0;
  document.getElementById('payroll-tax').value = current?.tax_deduction ?? 0;
  document.getElementById('payroll-social').value = current?.social_security_deduction ?? 0;
  document.getElementById('payroll-deductions').value = current?.other_deductions ?? 0;
}

function setView(viewName) {
  activeView = viewName;
  sessionStorage.setItem('hr_active_view', viewName);
  document.querySelectorAll('.hr-nav button').forEach((button) => {
    button.classList.toggle('active', button.dataset.view === viewName);
  });
  document.querySelectorAll('.hr-view').forEach((view) => {
    view.hidden = view.id !== `view-${viewName}`;
  });
}

async function refreshCurrentView() {
  const refreshButton = document.getElementById('refresh-btn');
  const refreshStatus = document.getElementById('refresh-status');
  if (refreshButton.disabled) return;

  refreshButton.disabled = true;
  refreshButton.textContent = 'กำลังรีเฟรช...';
  refreshStatus.textContent = '';
  try {
    if (activeView === 'overview' || activeView === 'attendance') {
      await loadSummary();
    } else if (activeView === 'employees' || activeView === 'rates') {
      await loadEmployees();
    } else if (activeView === 'payroll') {
      await Promise.all([loadSummary(), loadEmployees(), loadPayroll()]);
    }
    refreshStatus.textContent = 'อัปเดตข้อมูลแล้ว';
  } catch (error) {
    refreshStatus.textContent = `รีเฟรชไม่สำเร็จ: ${error.message}`;
  } finally {
    refreshButton.disabled = false;
    refreshButton.textContent = 'รีเฟรชข้อมูล';
  }
}

document.querySelectorAll('.hr-nav button').forEach((button) => {
  button.addEventListener('click', () => setView(button.dataset.view));
});

document.getElementById('refresh-btn')?.addEventListener('click', refreshCurrentView);

document.getElementById('search-input')?.addEventListener('input', applyLogFilter);
document.getElementById('filter-type')?.addEventListener('change', applyLogFilter);
document.getElementById('employee-search')?.addEventListener('input', renderEmployees);
document.getElementById('employee-status-filter')?.addEventListener('change', renderEmployees);
document.getElementById('rate-search')?.addEventListener('input', renderRates);
['payroll-employee', 'payroll-month', 'payroll-year'].forEach((id) => {
  document.getElementById(id)?.addEventListener('change', () => {
    Promise.all([updatePayrollEstimate(), loadSelectedPayrollValues()]).catch((error) => {
      document.getElementById('payroll-notice').textContent = error.message;
    });
  });
});
document.getElementById('payroll-filter-btn')?.addEventListener('click', () => {
  loadPayroll().catch((error) => {
    document.getElementById('payroll-list-notice').textContent = error.message;
  });
});

document.getElementById('employee-cancel')?.addEventListener('click', () => {
  document.getElementById('employee-dialog').close();
});

document.getElementById('employee-form')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const employeeId = document.getElementById('employee-edit-id').value;
  const payload = {
    full_name: document.getElementById('employee-edit-name').value,
    position: document.getElementById('employee-edit-position').value,
    phone: document.getElementById('employee-edit-phone').value,
    employment_status: document.getElementById('employee-edit-status').value,
    pay_basis: document.getElementById('employee-edit-pay-basis').value,
    monthly_salary: Number(document.getElementById('employee-edit-monthly').value),
    daily_wage: Number(document.getElementById('employee-edit-daily').value),
    overtime_rate: Number(document.getElementById('employee-edit-overtime').value),
  };
  try {
    await fetchJson(`/api/users/${employeeId}`, { method: 'PATCH', body: JSON.stringify(payload) });
    document.getElementById('employee-dialog').close();
    await loadEmployees();
    document.getElementById('payroll-notice').textContent = 'บันทึกข้อมูลพนักงานแล้ว';
  } catch (error) {
    document.getElementById('employee-edit-notice').textContent = error.message;
  }
});

document.getElementById('payroll-form')?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const payload = {
    user_id: Number(document.getElementById('payroll-employee').value),
    month: Number(document.getElementById('payroll-month').value),
    year: Number(document.getElementById('payroll-year').value),
    other_additions: Number(document.getElementById('payroll-additions').value),
    tax_deduction: Number(document.getElementById('payroll-tax').value),
    social_security_deduction: Number(document.getElementById('payroll-social').value),
    other_deductions: Number(document.getElementById('payroll-deductions').value),
  };
  try {
    const result = await fetchJson('/api/payroll', { method: 'POST', body: JSON.stringify(payload) });
    document.getElementById('payroll-notice').textContent = `${result.message} ${result.completed_days} วัน, OT ${result.overtime_hours} ชั่วโมง, สุทธิ ${formatMoney(result.net_salary)} บาท`;
    document.getElementById('payroll-filter-month').value = String(payload.month);
    document.getElementById('payroll-filter-year').value = String(payload.year);
    await loadPayroll();
    await updatePayrollEstimate();
  } catch (error) {
    document.getElementById('payroll-notice').textContent = error.message;
  }
});

populateMonthOptions();
setView(['overview', 'employees', 'attendance', 'rates', 'payroll'].includes(activeView) ? activeView : 'overview');
const currentDate = new Date();
document.getElementById('payroll-month').value = String(currentDate.getMonth() + 1);
document.getElementById('payroll-year').value = String(currentDate.getFullYear());
document.getElementById('payroll-filter-month').value = 'all';
document.getElementById('payroll-filter-year').value = String(currentDate.getFullYear());

document.getElementById('export-btn')?.addEventListener('click', async (event) => {
  event.preventDefault();
  try {
    const response = await fetch('/api/logs/export', { headers: { Authorization: `Bearer ${token}` } });
    if (!response.ok) throw new Error('ส่งออกข้อมูลไม่สำเร็จ');
    const blobUrl = URL.createObjectURL(await response.blob());
    const link = document.createElement('a');
    link.href = blobUrl;
    link.download = 'attendance_export.csv';
    link.click();
    URL.revokeObjectURL(blobUrl);
  } catch (error) {
    document.getElementById('logs-empty').textContent = error.message;
    document.getElementById('logs-empty').style.display = 'block';
  }
});

document.getElementById('logout-btn')?.addEventListener('click', () => {
  localStorage.removeItem('attendance_token');
  localStorage.removeItem('attendance_user');
  window.location.href = '/admin/login';
});

Promise.all([loadSummary(), loadEmployees(), loadPayroll()]).catch((error) => {
  document.getElementById('payroll-list-notice').textContent = error.message;
});
