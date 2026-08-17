# EnatAI Backend — Frontend Integration & API Guide

> **Base URL**: `http://localhost:8000` (or your deployed backend host)  
> **Target Audience**: Mobile & Web Frontend Developers  
> **Primary Language**: Amharic (speech-to-text, verification read-back phrases, clinical prompt messages)  

---

## Table of Contents

1. [Authentication Flow](#1-authentication-flow)
2. [User Settings & Profile Management](#2-user-settings--profile-management)
3. [Voice Check-in Intake Workflow](#3-voice-check-in-intake-workflow)
   - [Stage 1: Symptoms](#stage-1-symptoms)
   - [Stage 2: Food Log](#stage-2-food-log)
   - [Stage 3: Supplement Tracking](#stage-3-supplement-tracking)
   - [Stage 4: Closing Questions](#stage-4-closing-questions)
4. [Verification & Correction Flows](#4-verification--correction-flows)
   - [Manual Text Verification & Edits](#a-manual-text-verification--edits)
   - [Single-Item Voice Correction](#b-single-item-voice-correction)
   - [Full-Stage Voice Re-recording](#c-full-stage-voice-re-recording)
5. [Check-in History & Details](#5-check-in-history--details)
6. [Clinician Summaries & QR Sharing](#6-clinician-summaries--qr-sharing)
7. [Notifications & Reminders System](#7-notifications--reminders-system)
8. [Error Handling & Best Practices](#8-error-handling--best-practices)

---

## 1. Authentication Flow

All endpoints (except `/auth/*` and `/summary/public/*`) require a Bearer Access Token in the HTTP Request Header:

```http
Authorization: Bearer <access_token>
```

### Sign Up
- **Endpoint**: `POST /auth/signup`
- **Request Body**:
```json
{
  "email": "mother@example.com",
  "password": "securepassword123"
}
```
- **Response** `(200 OK)`:
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "user_id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
  "email": "mother@example.com"
}
```

### Log In
- **Endpoint**: `POST /auth/login`
- **Request Body**:
```json
{
  "email": "mother@example.com",
  "password": "securepassword123"
}
```
- **Response** `(200 OK)`: Returns `access_token`, `user_id`, and `email`.

### Forgot Password (Send Reset Email)
- **Endpoint**: `POST /auth/forgot-password`
- **Request Body**:
```json
{
  "email": "mother@example.com"
}
```
- **Response** `(200 OK)`:
```json
{
  "status": "success",
  "message": "If an account with that email exists, a password reset link has been sent to your email."
}
```

### Reset Password (Update Password with Recovery Token)
- **Endpoint**: `POST /auth/reset-password`
- **Request Body**:
```json
{
  "access_token": "recovery_access_token_from_email_link",
  "new_password": "newsecurepassword123"
}
```
- **Response** `(200 OK)`:
```json
{
  "status": "success",
  "message": "Password updated successfully. You can now log in with your new password."
}
```

> [!NOTE]
> The backend handles Supabase ES256 and HS256 JWT decoding seamlessly. Save the `access_token` securely on device storage.

---

## 2. User Settings & Profile Management

Frontend apps can query `GET /users/me` at launch to load all user configuration states (supplements, appointment date, reminder lead days, active notifications).

### Get Full User Profile & Settings
- **Endpoint**: `GET /users/me`
- **Response** `(200 OK)`:
```json
{
  "id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
  "email": "mother@example.com",
  "created_at": "2026-08-15T10:00:00Z",
  "supplements": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "user_id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
      "name": "iron",
      "active": true,
      "reminder_enabled": true,
      "reminder_time": "09:00:00",
      "created_at": "2026-08-15T10:00:00Z"
    }
  ],
  "appointment": {
    "id": "3a1103c8-8889-4d22-b5e1-77114b001199",
    "user_id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
    "appointment_date": "2026-08-20",
    "reminder_lead_days": 2,
    "last_summary_generated_at": null
  },
  "pending_reminders": []
}
```

### Unified Settings Update (Bulk Update All Settings)
- **Endpoint**: `PUT /users/me/settings` or `PATCH /users/me/settings`
- **Request Body**:
```json
{
  "appointment": {
    "appointment_date": "2026-08-25",
    "reminder_lead_days": 3
  },
  "supplements": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "reminder_enabled": true,
      "reminder_time": "08:30:00"
    }
  ]
}
```
- **Response** `(200 OK)`: Returns updated `UserProfile`.

### Add or Update Supplement
- **Endpoint**: `POST /users/me/supplements` or `PUT /users/me/supplements/{supplement_id}`
- **Request Body**:
```json
{
  "name": "iron",
  "active": true,
  "reminder_enabled": true,
  "reminder_time": "09:00:00"
}
```

### Delete Supplement
- **Endpoint**: `DELETE /users/me/supplements/{supplement_id}`
- **Response** `(200 OK)`: `{"status": "deleted"}`

### Manual Supplement Intake Verification (Skip Stage 3 in Voice Check-in)
Allows the patient to manually confirm supplement intake (e.g. from home screen checklist button). Logging supplement intake for today automatically dismisses pending reminders and **skips Stage 3 (Supplement)** during voice check-in!
- **Endpoint**: `POST /users/me/supplements/verify` or `POST /users/me/supplements/{supplement_id}/verify`
- **Request Body**:
```json
{
  "supplement_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "supplement_name": "iron",
  "taken_today": true
}
```
- **Response** `(200 OK)`:
```json
{
  "status": "verified",
  "supplement_name": "iron",
  "taken_today": true,
  "logged_at": "2026-08-16T13:00:00Z"
}
```

### Set or Update ANC Appointment
- **Endpoint**: `POST /users/me/appointment` or `PUT /users/me/appointment`
- **Request Body**:
```json
{
  "appointment_date": "2026-08-20",
  "reminder_lead_days": 2
}
```

### Delete ANC Appointment
- **Endpoint**: `DELETE /users/me/appointment`
- **Response** `(200 OK)`: `{"status": "deleted"}`

---

## 3. Voice Check-in Intake Workflow

The intake session is a multi-stage conversational state machine:
`symptoms` → `food` → `supplement` (if active supplement exists) → `closing`.

```mermaid
graph TD
    Start[POST /checkin/start] --> Stage1[Stage: symptoms]
    Stage1 --> Voice1[POST /checkin/{id}/respond audio]
    Voice1 --> Verify1[POST /checkin/{id}/verify]
    Verify1 --> Complete1[POST /checkin/{id}/complete]
    Complete1 --> Stage2[Stage: food]
    Stage2 --> Voice2[POST /checkin/{id}/respond audio]
    Voice2 --> Verify2[POST /checkin/{id}/verify]
    Verify2 --> Complete2[POST /checkin/{id}/complete]
    Complete2 --> Stage3{Supplement Active?}
    Stage3 -- Yes --> Stage3Supp[Stage: supplement]
    Stage3Supp --> Complete3[POST /checkin/{id}/complete]
    Stage3 -- No --> Stage4[Stage: closing]
    Complete3 --> Stage4
    Stage4 --> Finish[Intake Complete status: completed]
```

### Step 1: Start Session
- **Endpoint**: `POST /checkin/start`
- **Response** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage": "symptoms",
  "question_prompt": "ዛሬ ወይም በቅርቡ ምንም አይነት ያልተለመደ የጤና እክል ወይም ህመም ተሰምቶዎታል?",
  "question_audio_url": "/tts?text=%E1%8B%AE%E1%88%A5..."
}
```

### Step 2: Send Voice Response (Audio Upload)
- **Endpoint**: `POST /checkin/{session_id}/respond`
- **Content-Type**: `multipart/form-data`
- **Form Field**: `audio` (file upload: `.webm`, `.wav`, `.m4a`, `.mp3`)
- **Response** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage": "symptoms",
  "transcript": "ቀላል የድካም ስሜት አለኝ",
  "pending_items": [
    {
      "item_id": "2e166c60-7461-41fb-86d6-ff99c886c950",
      "raw_text": "ቀላል የድካም ስሜት አለኝ",
      "category": null,
      "duration": {"value": null, "unit": "unspecified"},
      "severity": "mild",
      "danger_sign": false,
      "confirmed": false,
      "verification_phrase": "ቀላል የድካም ስሜት አለኝ — ትክክል ነው?"
    }
  ]
}
```

> [!IMPORTANT]
> **Danger Signs Rule**: If `severity` is `"mild"`, `category` is automatically set to `null` and `danger_sign` is `false`. Danger signs are strictly reserved for severe/persistent protocol conditions.

---

## 4. Verification & Correction Flows

Each stage presents `pending_items` for patient read-back confirmation.

### A. Manual Text Verification & Edits
When the patient confirms or manually edits an item:

- **Endpoint**: `POST /checkin/{session_id}/verify`
- **Request Body (Single Item Verification)**:
```json
{
  "item_id": "2e166c60-7461-41fb-86d6-ff99c886c950",
  "confirmed": true,
  "corrected_value": {
    "raw_text": "ቀላል የድካም ስሜት ብቻ ነው"
  }
}
```

- **Request Body (Bulk Verification for All Items at Once)**:
```json
{
  "items": [
    {
      "item_id": "2e166c60-7461-41fb-86d6-ff99c886c950",
      "confirmed": true
    },
    {
      "item_id": "889bb790-ce6d-4008-8254-9435f3d8642c",
      "confirmed": true,
      "corrected_value": {
        "severity": "mild"
      }
    }
  ]
}
```
- **Response** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage": "symptoms",
  "pending_items": [],
  "confirmed_count": 2
}
```

> [!TIP]
> **Bulk Verification**: When multiple symptoms, foods, or closing questions are returned in `pending_items`, the frontend can present all items at once and confirm them all in a single bulk `POST /verify` call!
> **Single-Item Fallback**: On single-item stages (`food`, `supplement`), if the client accidentally sends the `session_id` in `item_id`, the backend automatically targets the single pending item.

### B. Single-Item Voice Correction
If the patient taps "Re-record voice for this item":

- **Endpoint**: `POST /checkin/{session_id}/items/{item_id}/voice-correct`
- **Content-Type**: `multipart/form-data`
- **Form Field**: `audio` (file upload)
- **Response** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage": "symptoms",
  "correction_transcript": "ከባድ ራስ ምታት ለሁለት ቀን",
  "item_updated": true,
  "pending_items": [
    {
      "item_id": "2e166c60-7461-41fb-86d6-ff99c886c950",
      "raw_text": "ከባድ ራስ ምታት ለሁለት ቀን",
      "category": "severe_headache",
      "duration": {"value": 2, "unit": "day"},
      "severity": "severe",
      "danger_sign": true,
      "confirmed": false,
      "verification_phrase": "ከባድ ራስ ምታት፣ 2 ቀን — ትክክል ነው?"
    }
  ]
}
```

### C. Complete Stage & Advance
Once all pending items in a stage are verified (or if `pending_items` is `[]` because "Nothing" was reported):

- **Endpoint**: `POST /checkin/{session_id}/complete`
- **Response (Intermediate Stage)** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage_completed": "symptoms",
  "next_stage": "food",
  "question_prompt": "ዛሬ ምን አይነት ምግቦች ተመገቡ?",
  "session_completed": false,
  "danger_sign_triggered": false
}
```

- **Response (Final Stage Completed)** `(200 OK)`:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage_completed": "closing",
  "next_stage": null,
  "question_prompt": null,
  "session_completed": true,
  "danger_sign_triggered": false,
  "check_in_id": "f589c311-2090-482f-b441-11883c5112ab"
}
```

---

## 5. Check-in History & Details

### List User Check-in History
- **Endpoint**: `GET /checkin/history`
- **Response** `(200 OK)`:
```json
[
  {
    "id": "f589c311-2090-482f-b441-11883c5112ab",
    "timestamp": "2026-08-15T12:00:00Z",
    "symptoms": [{"raw_text": "ቀላል የድካም ስሜት", "danger_sign": false, "confirmed": true}],
    "food_log": {"raw_text": "እንጀራ በሽሮ", "confirmed": true},
    "supplement_check": {"supplement_name": "iron", "taken_today": true, "confirmed": true},
    "closing_mentions": [],
    "danger_sign_triggered": false
  }
]
```

### Get Single Check-in Detail
- **Endpoint**: `GET /checkin/history/{checkin_id}`
- **Response** `(200 OK)`: Returns full breakdown for that specific intake session.

---

## 6. Clinician Summaries & QR Sharing

Summaries aggregate all confirmed check-ins over a period for ANC doctor visits.

### Generate Manual Summary
- **Endpoint**: `POST /summary/generate`
- **Response** `(200 OK)`:
```json
{
  "id": "c138861d-91b4-4b51-bdf1-897711200119",
  "period_start": "2026-08-01",
  "period_end": "2026-08-17",
  "generated_at": "2026-08-17T11:29:32Z",
  "content_json": {
    "danger_signs": [],
    "general_symptoms": [
      {
        "date": "2026-08-17",
        "category": "no_danger_sign_detected",
        "category_display": "ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)",
        "category_display_en": "no danger sign detected (normal)",
        "raw_text": "አይ ምንም ይለኛል",
        "duration": {"value": null, "unit": "unspecified"},
        "severity": "unspecified"
      }
    ],
    "food_logs": [{"date": "2026-08-17", "raw_text": "እንጀራ በሽሮ"}],
    "supplement_adherence": {"taken_days": 5, "tracked_days": 6},
    "closing_mentions": [],
    "muac_reminder": "MUAC screening due — check at visit",
    "provenance_note": "All data in this summary is self-reported by the patient (no device-measured data)."
  },
  "share_link_slug": "tvkr1JopCeoZQJqG",
  "qr_code_url": "https://.../tvkr1JopCeoZQJqG.png"
}
```

### Check & Trigger Automatic Summary
- **Endpoint**: `POST /summary/check-automatic`
- **Rules**:
  - Automatically generates **1 day before appointment date**.
  - If no appointment is set, automatically generates **every 30 days**.

### Get Latest Summary
- **Endpoint**: `GET /summary/latest`

### Public Doctor View (No Auth Required)
- **Endpoint**: `GET /summary/public/{share_link_slug}`
- Returns de-identified summary for clinical review.

---

## 7. Notifications & Reminders System

### Get Active Notifications
- **Endpoint**: `GET /notifications`
- **Response** `(200 OK)`:
```json
[
  {
    "id": "4b911200-7c22-411a-8800-9a8b77665511",
    "user_id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
    "type": "supplement",
    "message": "Reminder to take your iron supplement.",
    "due_at": "2026-08-15T09:00:00Z",
    "dismissed": false,
    "created_at": "2026-08-15T09:00:00Z"
  },
  {
    "id": "9a112233-4455-6677-8899-aabbccddeeff",
    "user_id": "e81acbf1-5f43-4afc-90be-b2d86c9a6802",
    "type": "report_generated",
    "message": "Your clinician summary report for your ANC appointment has been generated.",
    "due_at": "2026-08-15T12:00:00Z",
    "dismissed": false,
    "created_at": "2026-08-15T12:00:00Z"
  }
]
```

### Dismiss Notification
- **Endpoint**: `POST /notifications/{notification_id}/dismiss`

### 1-Tap Google Calendar Link & iCal Export (.ics)
Add ANC appointment directly to Google Calendar or Apple Calendar with automated device reminders (1 day & 2 hours before):
- **Get Calendar Links**: `GET /users/me/appointment/calendar-link`
  - **Response** `(200 OK)`:
  ```json
  {
    "google_calendar_url": "https://calendar.google.com/calendar/render?action=TEMPLATE&text=...",
    "ical_download_url": "/users/me/appointment/calendar.ics"
  }
  ```
- **Download iCal File**: `GET /users/me/appointment/calendar.ics`
  - Returns downloadable `.ics` calendar file with built-in device notification alarms.

### Register Device Push Notification Tokens (FCM / Web Push)
Register device token for lockscreen push notifications when the app or browser is closed:
- **Endpoint**: `POST /users/me/push-tokens`
- **Request Body**:
```json
{
  "token": "fcm_device_token_or_web_push_subscription_string",
  "platform": "web"
}
```
- **Response** `(200 OK)`: `{"status": "registered", "token": "..."}`

---

## 8. Error Handling & Best Practices

| HTTP Status | Detail Example | Cause / Action |
|---|---|---|
| `401 Unauthorized` | `"Invalid or expired token"` | Access token missing or expired; redirect user to login. |
| `400 Bad Request` | `"All pending items must be verified before completing the stage"` | Patient hasn't verified `pending_items`; call `/verify` first. |
| `404 Not Found` | `"Check-in record not found"` | Resource ID doesn't exist or belongs to another user. |
| `409 Conflict` | `"Appointment already exists"` | Use `PUT /users/me/appointment` to update an existing appointment. |

### Frontend UI Checklist
1. **Always display `verification_phrase`** returned by backend directly on screen.
2. **Audio File Formats**: Send `.webm` or `.wav` recorded at 16kHz for Addis AI ASR accuracy.
3. **Empty Stage Handling**: When user says "No / nothing", `pending_items` is `[]`. Directly call `/complete` to move forward.

---

## 9. Text-to-Speech (TTS) Voice Synthesis

The backend includes native **Text-to-Speech (TTS)** via Addis AI so the AI can speak stage prompts and read-back verification phrases in Amharic voice.

### 1. Automatic Audio URLs in Check-in Responses
All check-in endpoints automatically attach `question_audio_url` and `verification_audio_url`:

- **Start / Advance Stage Response**:
```json
{
  "session_id": "93b761d2-42ba-4270-9bb2-dffd19256ab1",
  "stage": "symptoms",
  "question_prompt": "ዛሬ ወይም በቅርቡ ምንም አይነት ያልተለመደ የጤና እክል ወይም ህመም ተሰምቶዎታል?",
  "question_audio_url": "/tts?text=%E1%8B%AE%E1%88%A5..."
}
```

- **Respond / Verify Pending Items Response**:
```json
{
  "item_id": "2e166c60-7461-41fb-86d6-ff99c886c950",
  "raw_text": "ቀላል የድካም ስሜት",
  "verification_phrase": "ቀላል የድካም ስሜት — ትክክል ነው?",
  "verification_audio_url": "/tts?text=%E1%88%A8%E1%8B%AE..."
}
```

### 2. Direct TTS Endpoints
- **Stream Audio via GET (HTML `<audio src="...">` / Mobile Audio Player)**:  
  `GET /tts?text=ከፍተኛ+ትኩሳት+—+ትክክል+ነው%3F` -> Returns `audio/mpeg` MP3 stream.
- **Synthesize Audio via POST**:  
  `POST /tts`  
  `{"text": "ከፍተኛ ትኩሳት — ትክክል ነው?"}` -> Returns `audio/mpeg` MP3 stream.
