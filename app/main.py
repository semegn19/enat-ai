from contextlib import asynccontextmanager

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, checkin, notifications, reminders, summary, users, tts
from app.config import get_settings
from app.services.addis_ai import AddisAIClient
from app.services.reminders import ReminderService

scheduler = BackgroundScheduler()


def _run_reminder_job() -> None:
    ReminderService().run_daily_job()


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    scheduler.add_job(
        _run_reminder_job,
        trigger="cron",
        hour=settings.reminder_cron_hour,
        minute=0,
        id="daily_reminders",
        replace_existing=True,
    )
    scheduler.start()
    yield
    scheduler.shutdown(wait=False)


app = FastAPI(
    title="EnatAI Clinical Intake Backend",
    version="0.1.0",
    lifespan=lifespan,
)

settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(checkin.router)
app.include_router(summary.router)
app.include_router(reminders.router)
app.include_router(notifications.router)
app.include_router(tts.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


if settings.enable_dev_routes:

    @app.post("/dev/asr-test")
    async def dev_asr_test(audio: UploadFile = File(...)) -> dict[str, str]:
        audio_bytes = await audio.read()
        transcript = await AddisAIClient().transcribe(
            audio_bytes,
            audio.filename or "audio.wav",
            audio.content_type or "audio/wav",
        )
        return {"transcript": transcript}
