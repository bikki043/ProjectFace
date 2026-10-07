import sys
import unittest
import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))

from auth import hash_password
from database import AttendanceLog, Payslip, SessionLocal, User
from main import app, determine_log_type, upsert_daily_attendance_scan


class FrontendPageRoutesTests(unittest.TestCase):
    def test_user_root_serves_user_page(self):
        client = TestClient(app)

        response = client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("สแกนเข้า-ออก", response.text)
        self.assertIn("ลงทะเบียนพนักงาน", response.text)

    def test_admin_login_page_exists(self):
        client = TestClient(app)

        response = client.get("/admin-login.html")
        self.assertEqual(response.status_code, 200)
        self.assertIn("เข้าสู่ระบบฝ่ายบุคคล", response.text)

    def test_admin_dashboard_page_exists(self):
        client = TestClient(app)

        response = client.get("/admin-dashboard.html")
        self.assertEqual(response.status_code, 200)
        self.assertIn("ประวัติ", response.text)
        self.assertIn("สรุปผล", response.text)
        self.assertIn("ส่งออก CSV", response.text)
        self.assertIn("ค้นหาประวัติ", response.text)
        self.assertIn("<th>รูป</th>", response.text)
        self.assertIn('data-view="employees"', response.text)
        self.assertIn('data-view="attendance"', response.text)
        self.assertIn('data-view="rates"', response.text)
        self.assertIn('data-view="payroll"', response.text)
        self.assertIn("OT ต่อชั่วโมง", response.text)
        self.assertIn('id="employee-edit-pay-basis"', response.text)
        self.assertIn('id="refresh-status"', response.text)
        self.assertIn('id="payroll-attendance-breakdown"', response.text)
        self.assertIn("OT เริ่มนับเมื่อเวลาที่จับคู่ได้เกิน 2 นาทีต่อวัน", response.text)

    def test_default_admin_login_works(self):
        client = TestClient(app)

        response = client.post(
            "/auth/login",
            json={"employee_id": "admin", "password": "admin123"},
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertIn("access_token", payload)
        self.assertEqual(payload["user"]["employee_id"], "admin")

    def test_hr_management_api_requires_admin_login(self):
        client = TestClient(app)

        response = client.get("/api/users")

        self.assertEqual(response.status_code, 401)

    def test_regular_employee_cannot_access_hr_management_api(self):
        client = TestClient(app)
        db = SessionLocal()
        employee = User(
            employee_id=f"STAFF-{id(self)}",
            full_name="HR Access Test",
            hashed_password=hash_password("staff-password"),
            is_admin=False,
        )
        db.add(employee)
        db.commit()

        try:
            login = client.post(
                "/auth/login",
                json={"employee_id": employee.employee_id, "password": "staff-password"},
            )
            headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
            response = client.get("/api/users", headers=headers)
            self.assertEqual(response.status_code, 403)
        finally:
            db.delete(employee)
            db.commit()
            db.close()

    def test_checkout_cooldown_is_two_minutes(self):
        db = SessionLocal()
        employee = User(employee_id=f"COOLDOWN-{id(self)}", full_name="Cooldown Test")
        db.add(employee)
        db.commit()
        db.refresh(employee)
        check_in = AttendanceLog(
            user_id=employee.id,
            timestamp=datetime.datetime.utcnow() - datetime.timedelta(seconds=90),
            log_type="check-in",
            confidence_score=99,
        )
        db.add(check_in)
        db.commit()

        try:
            next_type, blocked, seconds_left = determine_log_type(db, employee.id)
            self.assertIsNone(next_type)
            self.assertTrue(blocked)
            self.assertGreaterEqual(seconds_left, 1)

            check_in.timestamp = datetime.datetime.utcnow() - datetime.timedelta(seconds=121)
            db.commit()
            next_type, blocked, _ = determine_log_type(db, employee.id)
            self.assertEqual(next_type, "check-out")
            self.assertFalse(blocked)
        finally:
            db.delete(employee)
            db.commit()
            db.close()

    def test_repeated_daily_scans_replace_slots_and_pay_once(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        db = SessionLocal()
        employee = User(
            employee_id=f"REPLACE-{id(self)}",
            full_name="Daily Replacement Test",
            pay_basis="daily",
            daily_wage=800,
            monthly_salary=0,
            overtime_rate=60,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")

        def utc(day_hour: int, minute: int) -> datetime.datetime:
            local = datetime.datetime(2026, 10, 6, day_hour, minute, tzinfo=thailand)
            return local.astimezone(datetime.timezone.utc).replace(tzinfo=None)

        try:
            first_in, replaced_in = upsert_daily_attendance_scan(db, employee.id, "check-in", 80, utc(9, 0))
            db.commit()
            second_in, replaced_in_again = upsert_daily_attendance_scan(db, employee.id, "check-in", 95, utc(9, 10))
            db.commit()
            first_out, replaced_out = upsert_daily_attendance_scan(db, employee.id, "check-out", 85, utc(9, 20))
            db.commit()
            second_out, replaced_out_again = upsert_daily_attendance_scan(db, employee.id, "check-out", 98, utc(9, 25))
            db.commit()

            self.assertFalse(replaced_in)
            self.assertTrue(replaced_in_again)
            self.assertFalse(replaced_out)
            self.assertTrue(replaced_out_again)
            self.assertEqual(first_in.id, second_in.id)
            self.assertEqual(first_out.id, second_out.id)
            self.assertEqual(
                db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).count(),
                2,
            )

            estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                headers=headers,
            )
            self.assertEqual(estimate.status_code, 200, estimate.text)
            payload = estimate.json()
            self.assertEqual(payload["completed_days"], 1)
            self.assertEqual(payload["base_pay"], 800)
            self.assertEqual(payload["work_minutes"], 15)
            self.assertEqual(payload["overtime_minutes"], 13)
            self.assertEqual(payload["overtime_pay"], 13)
            workday = next(day for day in payload["attendance_days"] if day["date"] == "2026-10-06")
            self.assertEqual(len(workday["sessions"]), 1)
            self.assertEqual(workday["sessions"][0]["duration_minutes"], 15)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_payroll_legacy_multiple_pairs_do_not_add_workdays(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        db = SessionLocal()
        employee = User(
            employee_id=f"LEGACY-{id(self)}",
            full_name="Legacy Duplicate Test",
            pay_basis="daily",
            daily_wage=800,
            overtime_rate=60,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")
        pair_starts = [datetime.datetime(2026, 10, 6, hour, 0, tzinfo=thailand) for hour in (9, 13)]
        for start in pair_starts:
            for scan_time, scan_type in (
                (start, "check-in"),
                (start + datetime.timedelta(minutes=12), "check-out"),
            ):
                db.add(AttendanceLog(
                    user_id=employee.id,
                    timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                    log_type=scan_type,
                    confidence_score=90,
                ))
        db.commit()

        try:
            estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                headers=headers,
            )
            self.assertEqual(estimate.status_code, 200, estimate.text)
            payload = estimate.json()
            self.assertEqual(payload["completed_days"], 1)
            self.assertEqual(payload["base_pay"], 800)
            self.assertEqual(payload["work_minutes"], 12)
            self.assertEqual(payload["overtime_minutes"], 10)
            workday = next(day for day in payload["attendance_days"] if day["date"] == "2026-10-06")
            self.assertEqual(len(workday["sessions"]), 1)
            self.assertEqual(workday["sessions"][0]["check_in"], pair_starts[1].isoformat())
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_stale_scan_state_starts_new_checkin_and_recovers_payroll_pair(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        db = SessionLocal()
        employee = User(
            employee_id=f"STALE-{id(self)}",
            full_name="Stale Session Test",
            monthly_salary=0,
            daily_wage=0,
            overtime_rate=45,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")
        old_scan = datetime.datetime(2026, 9, 1, 9, tzinfo=thailand)
        bad_direction_start = datetime.datetime(2026, 10, 7, 10, tzinfo=thailand)
        scans = [
            (old_scan, "check-in"),
            (bad_direction_start, "check-out"),
            (bad_direction_start + datetime.timedelta(minutes=6), "check-in"),
        ]
        for scan_time, scan_type in scans:
            db.add(AttendanceLog(
                user_id=employee.id,
                timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                log_type=scan_type,
                confidence_score=99,
            ))
        db.commit()

        try:
            next_type, blocked, _ = determine_log_type(db, employee.id)
            self.assertEqual(next_type, "check-in")
            self.assertFalse(blocked)

            estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                headers=headers,
            )
            self.assertEqual(estimate.status_code, 200, estimate.text)
            self.assertEqual(estimate.json()["completed_days"], 1)
            self.assertEqual(estimate.json()["overtime_minutes"], 4)
            self.assertEqual(estimate.json()["overtime_pay"], 3)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_pay_basis_selects_daily_or_monthly_base_pay(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        db = SessionLocal()
        employee = User(
            employee_id=f"BASIS-{id(self)}",
            full_name="Pay Basis Test",
            monthly_salary=12000,
            daily_wage=800,
            overtime_rate=60,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")
        start = datetime.datetime(2026, 10, 5, 9, tzinfo=thailand)
        for scan_time, log_type in (
            (start, "check-in"),
            (start + datetime.timedelta(minutes=12), "check-out"),
        ):
            db.add(AttendanceLog(
                user_id=employee.id,
                timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                log_type=log_type,
                confidence_score=99,
            ))
        db.commit()

        try:
            for basis, expected_base in (("daily", 800), ("monthly", 12000)):
                response = client.patch(
                    f"/api/users/{employee.id}",
                    headers=headers,
                    json={
                        "full_name": employee.full_name,
                        "position": "",
                        "phone": "",
                        "employment_status": "Active",
                        "pay_basis": basis,
                        "monthly_salary": 12000,
                        "daily_wage": 800,
                        "overtime_rate": 60,
                    },
                )
                self.assertEqual(response.status_code, 200, response.text)
                estimate = client.get(
                    f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                    headers=headers,
                )
                self.assertEqual(estimate.status_code, 200, estimate.text)
                self.assertEqual(estimate.json()["pay_basis"], basis)
                if basis == "monthly":
                    self.assertEqual(estimate.json()["scheduled_workdays"], 22)
                    self.assertEqual(estimate.json()["attended_workdays"], 1)
                    self.assertEqual(
                        estimate.json()["absence_days"],
                        estimate.json()["elapsed_scheduled_days"] - 1,
                    )
                    self.assertEqual(estimate.json()["base_pay"], round(12000 / 22, 2))
                    absence_rows = [day for day in estimate.json()["attendance_days"] if day["is_absent"]]
                    self.assertEqual(len(absence_rows), estimate.json()["absence_days"])
                    self.assertTrue(all(not day["is_qualifying_day"] for day in absence_rows))
                else:
                    self.assertEqual(estimate.json()["base_pay"], expected_base)
                self.assertEqual(estimate.json()["overtime_pay"], 10)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_monthly_employee_gets_full_base_after_attending_all_scheduled_days(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        db = SessionLocal()
        employee = User(
            employee_id=f"FULLMONTH-{id(self)}",
            full_name="Full Attendance Monthly Test",
            pay_basis="monthly",
            monthly_salary=22000,
            daily_wage=0,
            overtime_rate=0,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")
        day = datetime.date(2026, 9, 1)
        while day.month == 9:
            if day.weekday() < 5:
                start = datetime.datetime.combine(day, datetime.time(9), tzinfo=thailand)
                for scan_time, scan_type in (
                    (start, "check-in"),
                    (start + datetime.timedelta(minutes=12), "check-out"),
                ):
                    db.add(AttendanceLog(
                        user_id=employee.id,
                        timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                        log_type=scan_type,
                        confidence_score=99,
                    ))
            day += datetime.timedelta(days=1)
        db.commit()

        try:
            estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=9",
                headers=headers,
            )
            self.assertEqual(estimate.status_code, 200, estimate.text)
            payload = estimate.json()
            self.assertEqual(payload["scheduled_workdays"], 22)
            self.assertEqual(payload["attended_workdays"], 22)
            self.assertEqual(payload["absence_days"], 0)
            self.assertEqual(payload["base_pay"], 22000)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_employee_can_fetch_own_live_payroll_estimate(self):
        client = TestClient(app)
        db = SessionLocal()
        employee = User(
            employee_id=f"LIVE-{id(self)}",
            full_name="Live Payroll Test",
            hashed_password=hash_password("employee-password"),
            monthly_salary=0,
            daily_wage=800,
            overtime_rate=60,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        thailand = ZoneInfo("Asia/Bangkok")
        start = datetime.datetime(2026, 10, 6, 9, tzinfo=thailand)
        for scan_time, log_type in (
            (start, "check-in"),
            (start + datetime.timedelta(minutes=12), "check-out"),
            (start + datetime.timedelta(hours=4), "check-in"),
        ):
            db.add(AttendanceLog(
                user_id=employee.id,
                timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                log_type=log_type,
                confidence_score=99,
            ))
        db.commit()

        try:
            login = client.post(
                "/auth/login",
                json={"employee_id": employee.employee_id, "password": "employee-password"},
            )
            headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
            response = client.get("/payroll/me/estimate?year=2026&month=10", headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()["pay_basis"], "daily")
            self.assertEqual(response.json()["completed_days"], 0)
            self.assertEqual(response.json()["base_pay"], 0)
            self.assertEqual(response.json()["overtime_pay"], 0)
            self.assertEqual(response.json()["is_finalized"], False)
            day = next(day for day in response.json()["attendance_days"] if day["date"] == "2026-10-06")
            self.assertEqual(day["date"], "2026-10-06")
            self.assertFalse(day["is_qualifying_day"])
            self.assertEqual(day["overtime_minutes"], 0)
            self.assertEqual(day["overtime_pay"], 0)
            self.assertEqual(len(day["sessions"]), 1)
            self.assertEqual(day["sessions"][0]["check_in"], (start + datetime.timedelta(hours=4)).isoformat())
            self.assertIsNone(day["sessions"][0]["check_out"])
            self.assertFalse(day["sessions"][0]["is_complete"])
            self.assertEqual(day["worked_minutes"], 0)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()

    def test_admin_can_manage_employee_and_payroll(self):
        client = TestClient(app)
        login = client.post("/auth/login", json={"employee_id": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        suffix = str(id(self))
        db = SessionLocal()
        employee = User(
            employee_id=f"HR-{suffix}",
            full_name="HR Test Employee",
            position="Tester",
            phone="0800000000",
            employment_status="Active",
            monthly_salary=0,
            daily_wage=1000,
            overtime_rate=60,
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)

        try:
            update_response = client.patch(
                f"/api/users/{employee.id}",
                headers=headers,
                json={
                    "full_name": "HR Test Employee Updated",
                    "position": "Analyst",
                    "phone": "0811111111",
                    "employment_status": "On Leave",
                    "monthly_salary": 0,
                    "daily_wage": 1000,
                    "overtime_rate": 60,
                },
            )
            self.assertEqual(update_response.status_code, 200, update_response.text)
            self.assertEqual(update_response.json()["employment_status"], "On Leave")
            self.assertEqual(update_response.json()["overtime_rate"], 60)

            thai_tz = ZoneInfo("Asia/Bangkok")
            scan_pairs = [(1, 9, 1), (2, 9, 2), (3, 9, 3)]
            for day, start_minute, duration in scan_pairs:
                check_in = datetime.datetime(2026, 10, day, 9, start_minute, tzinfo=thai_tz)
                check_out = check_in + datetime.timedelta(minutes=duration)
                for scan_time, log_type in ((check_in, "check-in"), (check_out, "check-out")):
                    db.add(AttendanceLog(
                        user_id=employee.id,
                        timestamp=scan_time.astimezone(datetime.timezone.utc).replace(tzinfo=None),
                        log_type=log_type,
                        confidence_score=99,
                    ))
            db.commit()

            estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                headers=headers,
            )
            self.assertEqual(estimate.status_code, 200, estimate.text)
            self.assertEqual(estimate.json()["completed_days"], 2)
            self.assertEqual(estimate.json()["overtime_minutes"], 1)
            self.assertEqual(estimate.json()["base_pay"], 2000)
            self.assertEqual(estimate.json()["overtime_pay"], 1)

            monthly_update = client.patch(
                f"/api/users/{employee.id}",
                headers=headers,
                json={
                    "full_name": "HR Test Employee Updated",
                    "position": "Analyst",
                    "phone": "0811111111",
                    "employment_status": "On Leave",
                    "monthly_salary": 12000,
                    "daily_wage": 1000,
                    "overtime_rate": 60,
                },
            )
            self.assertEqual(monthly_update.status_code, 200, monthly_update.text)
            monthly_estimate = client.get(
                f"/api/payroll/estimate?user_id={employee.id}&year=2026&month=10",
                headers=headers,
            )
            self.assertEqual(monthly_estimate.json()["pay_basis"], "monthly")
            self.assertEqual(monthly_estimate.json()["attended_workdays"], 1)
            self.assertEqual(monthly_estimate.json()["base_pay"], round(12000 / 22, 2))

            client.patch(
                f"/api/users/{employee.id}",
                headers=headers,
                json={
                    "full_name": "HR Test Employee Updated",
                    "position": "Analyst",
                    "phone": "0811111111",
                    "employment_status": "On Leave",
                    "monthly_salary": 0,
                    "daily_wage": 1000,
                    "overtime_rate": 60,
                },
            )

            payroll_response = client.post(
                "/api/payroll",
                headers=headers,
                json={
                    "user_id": employee.id,
                    "year": 2026,
                    "month": 10,
                    "other_additions": 100,
                    "tax_deduction": 100,
                    "social_security_deduction": 50,
                    "other_deductions": 50,
                },
            )
            self.assertEqual(payroll_response.status_code, 200, payroll_response.text)
            self.assertEqual(payroll_response.json()["base_salary"], 2000)
            self.assertEqual(payroll_response.json()["overtime_pay"], 1)
            self.assertEqual(payroll_response.json()["net_salary"], 1901)
        finally:
            db.query(AttendanceLog).filter(AttendanceLog.user_id == employee.id).delete()
            db.query(Payslip).filter(Payslip.user_id == employee.id).delete()
            db.delete(employee)
            db.commit()
            db.close()


if __name__ == "__main__":
    unittest.main()
