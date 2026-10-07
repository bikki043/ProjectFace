const form = document.getElementById('admin-login-form');
const loginError = document.getElementById('login-error');
const loginBtn = document.getElementById('login-btn');
const employeeInput = document.getElementById('employee-id');
const passwordInput = document.getElementById('password');

async function submitLogin() {
  loginError.textContent = '';

  const employeeId = employeeInput.value.trim();
  const password = passwordInput.value.trim();

  if (!employeeId || !password) {
    loginError.textContent = 'กรุณากรอกรหัสพนักงานและรหัสผ่าน';
    return;
  }

  loginBtn.disabled = true;
  loginBtn.textContent = 'กำลังเข้าสู่ระบบ...';

  try {
    const response = await fetch('/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ employee_id: employeeId, password })
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.detail || 'เข้าสู่ระบบไม่สำเร็จ');
    }

    localStorage.setItem('attendance_token', data.access_token);
    localStorage.setItem('attendance_user', JSON.stringify(data.user));
    window.location.href = '/admin/dashboard';
  } catch (error) {
    loginError.textContent = error.message || 'เข้าสู่ระบบไม่สำเร็จ';
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'เข้าสู่ระบบ';
  }
}

form?.addEventListener('submit', async (event) => {
  event.preventDefault();
  await submitLogin();
});

const params = new URLSearchParams(window.location.search);
const autoEmployeeId = params.get('employee_id');
const autoPassword = params.get('password');

if (autoEmployeeId && autoPassword) {
  employeeInput.value = autoEmployeeId;
  passwordInput.value = autoPassword;
  window.history.replaceState({}, '', '/admin/login');
  setTimeout(() => {
    submitLogin();
  }, 150);
}
