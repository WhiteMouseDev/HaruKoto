from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db.session import engine

if settings.SENTRY_DSN and settings.SENTRY_DSN.startswith("https://"):
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        traces_sample_rate=0.1,
        environment=settings.ENVIRONMENT,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="HaruKoto API",
    description="일본어 학습 앱 HaruKoto의 백엔드 API",
    version="0.1.0",
    docs_url="/docs",
    lifespan=lifespan,
)

from app.error_handlers import register_error_handlers  # noqa: E402

register_error_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

# Include routers
from app.routers.achievements import router as achievements_router
from app.routers.admin_content import router as admin_content_router
from app.routers.auth import router as auth_router
from app.routers.chat import router as chat_router
from app.routers.chat_data import router as chat_data_router
from app.routers.cron import router as cron_router
from app.routers.health import router as health_router
from app.routers.kana import router as kana_router
from app.routers.kana_tts import router as kana_tts_router
from app.routers.lessons import router as lessons_router
from app.routers.missions import router as missions_router
from app.routers.notifications import router as notifications_router
from app.routers.payments import router as payments_router
from app.routers.push import router as push_router
from app.routers.quiz import router as quiz_router
from app.routers.stats import router as stats_router
from app.routers.study import router as study_router
from app.routers.subscription import router as subscription_router
from app.routers.tts import router as tts_router
from app.routers.user import router as user_router
from app.routers.webhook import router as webhook_router
from app.routers.wordbook import router as wordbook_router

app.include_router(health_router)
app.include_router(admin_content_router)
app.include_router(achievements_router)
app.include_router(auth_router)
app.include_router(user_router)
app.include_router(quiz_router)
app.include_router(kana_router)
app.include_router(kana_tts_router)
app.include_router(chat_router)
app.include_router(chat_data_router)
app.include_router(stats_router)
app.include_router(missions_router)
app.include_router(wordbook_router)
app.include_router(subscription_router)
app.include_router(payments_router)
app.include_router(webhook_router)
app.include_router(cron_router)
app.include_router(push_router)
app.include_router(notifications_router)
app.include_router(tts_router)
app.include_router(study_router)
app.include_router(lessons_router)
