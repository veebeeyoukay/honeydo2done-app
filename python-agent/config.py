from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    # Twilio
    twilio_account_sid: str
    twilio_auth_token: str
    twilio_phone_number: str

    # OpenAI (Whisper)
    openai_api_key: str

    # Anthropic (Claude)
    anthropic_api_key: str

    # Supabase
    supabase_url: str
    supabase_service_role_key: str

    # Server
    port: int = 8000
    host: str = "0.0.0.0"
    base_url: str = "http://localhost:8000"

    # Redis (optional, for conversation state)
    redis_url: str = "redis://localhost:6379"

    # Logging
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()
