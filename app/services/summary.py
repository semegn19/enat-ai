from datetime import date, datetime, timezone
from typing import Any
from uuid import UUID

from app.db.repositories.appointments import AppointmentRepository
from app.db.repositories.check_ins import CheckInRepository
from app.db.repositories.summaries import SummaryRepository
from app.db.repositories.users import UserRepository
from app.services.extraction import _category_display
from app.services.qr import build_share_url, generate_share_slug, upload_qr_code

# Included in every clinician summary per PRD §6.2:
# MUAC < 23 cm indicates acute malnutrition but cannot be self-reported via voice.
# The clinician should measure this at the visit.
_MUAC_REMINDER = "MUAC screening due — check at visit"

# Provenance note per PRD §6.5: all MVP data is self-reported.
_PROVENANCE_NOTE = "All data in this summary is self-reported by the patient (no device-measured data)."


def _parse_datetime(val: str | datetime) -> datetime:
    if isinstance(val, datetime):
        dt = val
    else:
        dt = datetime.fromisoformat(val.replace("Z", "+00:00"))
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


class SummaryService:
    def __init__(self) -> None:
        self.summaries = SummaryRepository()
        self.check_ins = CheckInRepository()
        self.appointments = AppointmentRepository()
        self.users = UserRepository()

    def generate(self, user_id: UUID) -> dict[str, Any]:
        user = self.users.get_by_id(user_id)
        if not user:
            raise ValueError("User not found")

        appointment = self.appointments.get_by_user(user_id)
        period_end = datetime.utcnow()

        # Determine the start of this summary period.
        # Priority: (1) last_summary_generated_at on the appointment record,
        #           (2) period_end of the most recent existing summary,
        #           (3) account creation date.
        if appointment and appointment.get("last_summary_generated_at"):
            period_start = _parse_datetime(appointment["last_summary_generated_at"])
        else:
            latest_summary = self.summaries.get_latest(user_id)
            if latest_summary and latest_summary.get("period_end"):
                period_start = _parse_datetime(latest_summary["period_end"])
            else:
                period_start = _parse_datetime(user["created_at"])

        check_ins = self.check_ins.list_in_period(user_id, period_start, period_end)
        content_json = self._aggregate(check_ins)

        slug = generate_share_slug()
        share_url = build_share_url(slug)
        qr_code_url = upload_qr_code(slug, share_url)

        summary = self.summaries.create(
            user_id,
            {
                "period_start": period_start.date().isoformat(),
                "period_end": period_end.date().isoformat(),
                "content_json": content_json,
                "share_link_slug": slug,
                "qr_code_url": qr_code_url,
            },
        )

        if appointment:
            self.appointments.update_last_summary_generated_at(user_id, period_end)

        try:
            from app.db.repositories.reminders import ReminderRepository
            ReminderRepository().create(
                user_id,
                {
                    "type": "report_generated",
                    "message": "Your clinician summary report for your ANC appointment has been generated.",
                    "due_at": datetime.utcnow().isoformat(),
                },
            )
        except Exception:
            pass

        return summary

    def get_latest(self, user_id: UUID) -> dict[str, Any] | None:
        return self.summaries.get_latest(user_id)

    def get_public(self, slug: str) -> dict[str, Any] | None:
        return self.summaries.get_by_slug(slug)

    def check_and_generate_auto_summary(self, user_id: UUID) -> dict[str, Any] | None:
        """Check whether an automatic summary is due for the user and generate it if so.

        Rules per PRD / user requirement:
        1. If an appointment is set: automatically generate 1 day before the appointment date
           (or on the day of appointment if not yet generated for this cycle).
        2. If no appointment is set: automatically generate every 30 days (1 month)
           since the last summary or account creation.
        """
        user = self.users.get_by_id(user_id)
        if not user:
            return None

        appointment = self.appointments.get_by_user(user_id)
        today = date.today()
        now = datetime.utcnow()

        should_generate = False
        reason = ""

        if appointment and appointment.get("appointment_date"):
            appointment_date = date.fromisoformat(appointment["appointment_date"])
            days_until = (appointment_date - today).days

            # 1 day before appointment (or day of appointment if not yet generated)
            if 0 <= days_until <= 1:
                last_generated = appointment.get("last_summary_generated_at")
                if not last_generated:
                    should_generate = True
                    reason = "pre_appointment_1_day_before"
                else:
                    last_gen_dt = _parse_datetime(last_generated)
                    # If not generated within the last 3 days for this appointment cycle
                    if (now - last_gen_dt).days >= 3:
                        should_generate = True
                        reason = "pre_appointment_1_day_before"
        else:
            # No appointment set -> generate every 30 days (monthly)
            latest_summary = self.summaries.get_latest(user_id)
            if latest_summary and latest_summary.get("generated_at"):
                last_gen_dt = _parse_datetime(latest_summary["generated_at"])
                if (now - last_gen_dt).days >= 30:
                    should_generate = True
                    reason = "monthly_auto_summary"
            else:
                created_at = _parse_datetime(user["created_at"])
                if (now - created_at).days >= 30:
                    should_generate = True
                    reason = "monthly_auto_summary"

        if should_generate:
            summary = self.generate(user_id)
            summary["auto_reason"] = reason
            return summary

        return None

    @staticmethod
    def _aggregate(check_ins: list[dict[str, Any]]) -> dict[str, Any]:
        """Aggregate confirmed check-in data into a clinician-ready summary.

        Sections per PRD §7.1:
        - danger_signs: listed individually with dates (not yes/no)
        - general_symptoms: non-danger confirmed symptoms (wellbeing trend)
        - food_logs: daily food log table (no scoring)
        - supplement_adherence: taken/tracked count if applicable
        - closing_mentions: anything raised in the open-ended closing question
        - muac_reminder: standing measurement reminder for the clinician
        - provenance_note: all data is self-reported
        """
        danger_signs: list[dict[str, Any]] = []
        general_symptoms: list[dict[str, Any]] = []
        food_logs: list[dict[str, Any]] = []
        closing_mentions: list[dict[str, Any]] = []
        supplement_taken_days = 0
        supplement_tracked_days = 0

        for check_in in check_ins:
            check_in_date = check_in.get("timestamp", "")[:10]

            for symptom in check_in.get("symptoms") or []:
                if not symptom.get("confirmed"):
                    continue
                raw_cat = symptom.get("category")
                if not raw_cat or raw_cat in ("none", "null", "no_danger_sign_detected") or not symptom.get("danger_sign"):
                    category_key = "no_danger_sign_detected"
                else:
                    category_key = raw_cat

                entry = {
                    "date": check_in_date,
                    "category": category_key,
                    "category_display": _category_display(category_key, lang="am"),
                    "category_display_en": _category_display(category_key, lang="en"),
                    "raw_text": symptom.get("raw_text"),
                    "duration": symptom.get("duration"),
                    "severity": symptom.get("severity") or "unspecified",
                }
                if symptom.get("danger_sign"):
                    danger_signs.append(entry)
                else:
                    # General wellbeing trend — PRD §7.1
                    general_symptoms.append(entry)

            food_log = check_in.get("food_log")
            if food_log and food_log.get("confirmed"):
                food_logs.append({"date": check_in_date, "raw_text": food_log.get("raw_text")})

            supplement = check_in.get("supplement_check")
            if supplement and supplement.get("confirmed"):
                supplement_tracked_days += 1
                if supplement.get("taken_today"):
                    supplement_taken_days += 1

            for mention in check_in.get("closing_mentions") or []:
                if mention.get("confirmed"):
                    closing_mentions.append(
                        {
                            "date": check_in_date,
                            "topic": mention.get("topic"),
                            "raw_text": mention.get("raw_text"),
                        }
                    )

        adherence = None
        if supplement_tracked_days:
            adherence = {
                "taken_days": supplement_taken_days,
                "tracked_days": supplement_tracked_days,
            }

        return {
            "danger_signs": danger_signs,
            "general_symptoms": general_symptoms,
            "food_logs": food_logs,
            "supplement_adherence": adherence,
            "closing_mentions": closing_mentions,
            "muac_reminder": _MUAC_REMINDER,
            "provenance_note": _PROVENANCE_NOTE,
        }
