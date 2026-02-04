"""Pydantic models for API requests and responses"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime


class IncomingSMS(BaseModel):
    """Inbound SMS from Twilio"""

    From: str = Field(..., description="Sender phone number")
    To: str = Field(..., description="Recipient phone number (our number)")
    Body: str = Field(..., description="SMS message body")
    MessageSid: str = Field(..., description="Twilio message SID")
    AccountSid: str = Field(..., description="Twilio account SID")


class OutgoingSMS(BaseModel):
    """Outbound SMS request"""

    to: str = Field(..., description="Recipient phone number")
    message: str = Field(..., description="Message to send")


class ConversationState(BaseModel):
    """Conversation state for triage"""

    phone_number: str
    task_id: str
    state: str = "triaging"  # triaging, awaiting_decision, completed
    current_question: int = 0
    total_questions: int = 3
    answers: Dict[str, Any] = Field(default_factory=dict)
    persona: str = "household_ceo"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: Optional[datetime] = None


class TaskCreate(BaseModel):
    """Task creation payload"""

    phone_number: str
    transcript: str
    source: str = "voice"  # voice or sms
    call_sid: Optional[str] = None
    message_sid: Optional[str] = None
