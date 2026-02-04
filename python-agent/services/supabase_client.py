"""Supabase client for database and edge function integration"""

from supabase import create_client, AsyncClient
from loguru import logger
from typing import Dict, Any, Optional
import httpx

from config import get_settings

settings = get_settings()


class SupabaseClient:
    """Wrapper for Supabase operations"""

    def __init__(self):
        self.client: AsyncClient = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
        )
        self.functions_base = f"{settings.supabase_url}/functions/v1"

    async def create_task_from_voice(
        self,
        phone_number: str,
        transcript: str,
        call_sid: str,
    ) -> Dict[str, Any]:
        """
        Create task from voice call

        Args:
            phone_number: User's phone number
            transcript: Transcribed audio
            call_sid: Twilio call SID

        Returns:
            Created task dict
        """
        try:
            # Call the generic intake endpoint
            payload = {
                "event": "voice_call",
                "phone_number": phone_number,
                "transcript": transcript,
                "metadata": {"call_sid": call_sid, "source": "voice"},
                "timestamp": self._now_iso(),
            }

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.functions_base}/intake-webhook",
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {settings.supabase_service_role_key}",
                        "Content-Type": "application/json",
                    },
                    timeout=30.0,
                )

                response.raise_for_status()
                result = response.json()

                if not result.get("success"):
                    raise Exception(f"Intake failed: {result.get('error')}")

                return result["data"]

        except Exception as e:
            logger.error(f"Error creating task from voice: {e}", exc_info=True)
            raise

    async def create_task_from_sms(
        self,
        phone_number: str,
        message: str,
    ) -> Dict[str, Any]:
        """
        Create task from SMS

        Args:
            phone_number: User's phone number
            message: SMS message body

        Returns:
            Created task dict
        """
        try:
            payload = {
                "event": "sms_message",
                "phone_number": phone_number,
                "transcript": message,
                "metadata": {"source": "sms"},
                "timestamp": self._now_iso(),
            }

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.functions_base}/intake-webhook",
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {settings.supabase_service_role_key}",
                        "Content-Type": "application/json",
                    },
                    timeout=30.0,
                )

                response.raise_for_status()
                result = response.json()

                if not result.get("success"):
                    raise Exception(f"Intake failed: {result.get('error')}")

                return result["data"]

        except Exception as e:
            logger.error(f"Error creating task from SMS: {e}", exc_info=True)
            raise

    async def get_task(self, task_id: str) -> Optional[Dict[str, Any]]:
        """
        Get task by ID

        Args:
            task_id: Task UUID

        Returns:
            Task dict or None
        """
        try:
            response = (
                await self.client.table("tasks")
                .select("*")
                .eq("id", task_id)
                .single()
                .execute()
            )

            return response.data if response.data else None

        except Exception as e:
            logger.error(f"Error getting task: {e}", exc_info=True)
            return None

    async def complete_triage(self, task_id: str, answers: Dict[str, str]):
        """
        Complete triage by calling edge function

        Args:
            task_id: Task UUID
            answers: Dictionary of question answers
        """
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.functions_base}/task-triage-answer/{task_id}",
                    json={"answers": answers},
                    headers={
                        "Authorization": f"Bearer {settings.supabase_service_role_key}",
                        "Content-Type": "application/json",
                    },
                    timeout=30.0,
                )

                response.raise_for_status()

        except Exception as e:
            logger.error(f"Error completing triage: {e}", exc_info=True)
            raise

    def _now_iso(self) -> str:
        """Get current timestamp in ISO format"""
        from datetime import datetime

        return datetime.utcnow().isoformat() + "Z"
