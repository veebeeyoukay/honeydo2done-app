"""Conversation state management using Redis or in-memory store"""

from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import json
from loguru import logger

try:
    import redis.asyncio as redis
    from config import get_settings

    settings = get_settings()
    REDIS_AVAILABLE = True
except Exception:
    REDIS_AVAILABLE = False


class StateManager:
    """
    Manage conversation state for SMS triage

    Uses Redis if available, otherwise in-memory dict (not production-safe)
    """

    def __init__(self):
        self.use_redis = REDIS_AVAILABLE

        if self.use_redis:
            try:
                settings = get_settings()
                self.redis = redis.from_url(
                    settings.redis_url,
                    decode_responses=True,
                )
                logger.info("Using Redis for state management")
            except Exception as e:
                logger.warning(f"Redis connection failed: {e}. Using in-memory store.")
                self.use_redis = False
                self._memory_store: Dict[str, Dict[str, Any]] = {}
        else:
            logger.warning("Redis not available. Using in-memory store (not production-safe).")
            self._memory_store: Dict[str, Dict[str, Any]] = {}

    async def save_state(
        self,
        phone_number: str,
        state: Dict[str, Any],
        ttl_seconds: int = 3600,  # 1 hour default
    ):
        """
        Save conversation state

        Args:
            phone_number: User's phone number (key)
            state: State dictionary
            ttl_seconds: Time to live in seconds
        """
        key = self._make_key(phone_number)

        if self.use_redis:
            try:
                await self.redis.setex(
                    key,
                    ttl_seconds,
                    json.dumps(state, default=str),
                )
                logger.debug(f"Saved state for {phone_number}")
            except Exception as e:
                logger.error(f"Error saving to Redis: {e}")
        else:
            # In-memory store
            state["_expires_at"] = (
                datetime.utcnow() + timedelta(seconds=ttl_seconds)
            ).isoformat()
            self._memory_store[key] = state
            logger.debug(f"Saved state to memory for {phone_number}")

    async def get_state(self, phone_number: str) -> Optional[Dict[str, Any]]:
        """
        Get conversation state

        Args:
            phone_number: User's phone number

        Returns:
            State dict or None if not found/expired
        """
        key = self._make_key(phone_number)

        if self.use_redis:
            try:
                data = await self.redis.get(key)
                if data:
                    return json.loads(data)
                return None
            except Exception as e:
                logger.error(f"Error getting from Redis: {e}")
                return None
        else:
            # In-memory store
            state = self._memory_store.get(key)

            if not state:
                return None

            # Check expiration
            expires_at = state.get("_expires_at")
            if expires_at:
                if datetime.fromisoformat(expires_at) < datetime.utcnow():
                    # Expired
                    del self._memory_store[key]
                    return None

            return state

    async def clear_state(self, phone_number: str):
        """
        Clear conversation state

        Args:
            phone_number: User's phone number
        """
        key = self._make_key(phone_number)

        if self.use_redis:
            try:
                await self.redis.delete(key)
                logger.debug(f"Cleared state for {phone_number}")
            except Exception as e:
                logger.error(f"Error deleting from Redis: {e}")
        else:
            # In-memory store
            if key in self._memory_store:
                del self._memory_store[key]
                logger.debug(f"Cleared state from memory for {phone_number}")

    def _make_key(self, phone_number: str) -> str:
        """Make Redis/dict key from phone number"""
        normalized = phone_number.replace("+", "").replace("-", "").replace(" ", "")
        return f"conversation:{normalized}"

    async def close(self):
        """Close Redis connection"""
        if self.use_redis:
            await self.redis.close()
