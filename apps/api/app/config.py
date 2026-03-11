from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    DATABASE_URL: str

    # Supabase Auth
    SUPABASE_URL: str = ""
    SUPABASE_JWT_SECRET: str = ""  # Legacy HS256 — 비워두면 JWKS(ES256) 사용

    @property
    def supabase_jwks_url(self) -> str:
        return f"{self.SUPABASE_URL}/auth/v1/.well-known/jwks.json"

    # Google AI
    GOOGLE_API_KEY: str = ""

    # Google Cloud Storage
    GCS_BUCKET_NAME: str = "harukoto-tts"
    GCS_CDN_BASE_URL: str = "https://storage.googleapis.com/harukoto-tts"

    # PortOne V2
    PORTONE_API_SECRET: str = ""
    PORTONE_STORE_ID: str = ""
    PORTONE_CHANNEL_KEY: str = ""
    PORTONE_WEBHOOK_SECRET: str = ""

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # VAPID (Web Push)
    VAPID_PRIVATE_KEY: str = ""
    VAPID_PUBLIC_KEY: str = ""
    VAPID_EMAIL: str = "mailto:admin@harukoto.app"

    # CORS
    CORS_ORIGINS: str = "http://localhost:3000"

    # Cron
    CRON_SECRET: str = ""

    # Sentry
    SENTRY_DSN: str = ""

    # Environment
    ENVIRONMENT: str = "development"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()  # type: ignore[call-arg]
