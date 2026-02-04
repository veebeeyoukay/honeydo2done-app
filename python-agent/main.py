"""
HoneyDo2Done Python Agent - Main Application

FastAPI server handling voice and SMS intake for task management.
"""

from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import Response, JSONResponse
from twilio.twiml.voice_response import VoiceResponse, Gather
from twilio.twiml.messaging_response import MessagingResponse
from twilio.request_validator import RequestValidator
import httpx
from loguru import logger
import sys

from config import get_settings
from services.transcription import transcribe_audio
from services.agent import ConversationalAgent
from services.supabase_client import SupabaseClient
from services.state_manager import StateManager
from models import IncomingSMS, OutgoingSMS

# Initialize settings
settings = get_settings()

# Configure logging
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>",
    level=settings.log_level,
)

# Initialize app
app = FastAPI(title="HoneyDo2Done Agent", version="1.0.0")

# Initialize services
supabase = SupabaseClient()
agent = ConversationalAgent()
state_manager = StateManager()
twilio_validator = RequestValidator(settings.twilio_auth_token)


def validate_twilio_request(request: Request, body: bytes) -> bool:
    """Validate that request came from Twilio"""
    signature = request.headers.get("X-Twilio-Signature", "")
    url = str(request.url)
    params = dict(request.query_params)

    # For POST requests, include form data
    if request.method == "POST":
        # Parse form data from body
        form_data = {}
        if body:
            for item in body.decode().split("&"):
                if "=" in item:
                    key, value = item.split("=", 1)
                    form_data[key] = value
        params.update(form_data)

    return twilio_validator.validate(url, params, signature)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "honeydone-agent"}


@app.post("/voice/incoming")
async def handle_incoming_call(request: Request):
    """
    Handle inbound voice call from Twilio

    Flow:
    1. Greet user
    2. Ask them to describe the issue
    3. Record their response
    4. Process recording via /voice/recording
    """
    # Validate Twilio signature
    body = await request.body()
    if not validate_twilio_request(request, body):
        logger.warning("Invalid Twilio signature on voice call")
        raise HTTPException(status_code=403, detail="Invalid signature")

    from_number = (await request.form()).get("From")
    logger.info(f"Incoming call from {from_number}")

    # Create TwiML response
    response = VoiceResponse()

    # Greet and prompt
    response.say(
        "Hi! This is HoneyDo2Done. I'm here to help with your home tasks. "
        "Please describe what you need help with after the beep. "
        "When you're done, just hang up or press any key.",
        voice="Polly.Joanna",
    )

    # Record the message
    response.record(
        action=f"{settings.base_url}/voice/recording",
        method="POST",
        max_length=120,  # 2 minutes max
        transcribe=False,  # We'll use Whisper instead
        play_beep=True,
    )

    # Fallback
    response.say("I didn't receive your message. Please try again.")

    return Response(content=str(response), media_type="application/xml")


@app.post("/voice/recording")
async def handle_voice_recording(
    request: Request,
    From: str = Form(...),
    RecordingUrl: str = Form(...),
    CallSid: str = Form(...),
):
    """
    Process voice recording

    Flow:
    1. Download recording from Twilio
    2. Transcribe with Whisper
    3. Create task in Supabase
    4. Send SMS confirmation with task link
    """
    # Validate Twilio signature
    body = await request.body()
    if not validate_twilio_request(request, body):
        logger.warning("Invalid Twilio signature on recording")
        raise HTTPException(status_code=403, detail="Invalid signature")

    logger.info(f"Processing recording from {From}, CallSid: {CallSid}")

    try:
        # Download recording
        recording_url = f"{RecordingUrl}.mp3"

        async with httpx.AsyncClient() as client:
            recording_response = await client.get(
                recording_url,
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
            )
            recording_data = recording_response.content

        # Transcribe with Whisper
        transcript = await transcribe_audio(recording_data)

        logger.info(f"Transcribed: {transcript[:100]}...")

        # Create task via Supabase
        task = await supabase.create_task_from_voice(
            phone_number=From,
            transcript=transcript,
            call_sid=CallSid,
        )

        logger.info(f"Created task {task['id']} for {From}")

        # Send SMS confirmation
        await send_sms(
            to=From,
            message=f"Thanks for calling! I've captured your task: '{task['title']}'. "
            f"I'll text you a couple quick questions to understand what's needed.",
        )

        # Start triage via SMS
        await agent.start_triage_via_sms(task["id"], From)

        # TwiML response (call is ending)
        response = VoiceResponse()
        response.say(
            "Thank you! I've captured your request and will send you a text message shortly.",
            voice="Polly.Joanna",
        )
        response.hangup()

        return Response(content=str(response), media_type="application/xml")

    except Exception as e:
        logger.error(f"Error processing recording: {e}", exc_info=True)

        # Error response
        response = VoiceResponse()
        response.say(
            "I'm sorry, there was an error processing your request. Please try again later.",
            voice="Polly.Joanna",
        )

        return Response(content=str(response), media_type="application/xml")


@app.post("/sms/incoming")
async def handle_incoming_sms(
    request: Request,
    From: str = Form(...),
    Body: str = Form(...),
    MessageSid: str = Form(...),
):
    """
    Handle inbound SMS from Twilio

    Flow:
    1. Check for active conversation state
    2. If new: Create task, start triage
    3. If existing: Process triage answer
    4. Send response SMS
    """
    # Validate Twilio signature
    body_bytes = await request.body()
    if not validate_twilio_request(request, body_bytes):
        logger.warning("Invalid Twilio signature on SMS")
        raise HTTPException(status_code=403, detail="Invalid signature")

    logger.info(f"Incoming SMS from {From}: {Body}")

    try:
        # Get conversation state
        state = await state_manager.get_state(From)

        if not state:
            # New conversation - create task
            task = await supabase.create_task_from_sms(
                phone_number=From,
                message=Body,
            )

            logger.info(f"Created task {task['id']} from SMS")

            # Start triage
            reply = await agent.start_triage_via_sms(task["id"], From)

        else:
            # Existing conversation - process answer
            task_id = state.get("task_id")
            reply = await agent.process_triage_answer(task_id, From, Body)

        # Send SMS response
        response = MessagingResponse()
        response.message(reply)

        return Response(content=str(response), media_type="application/xml")

    except Exception as e:
        logger.error(f"Error handling SMS: {e}", exc_info=True)

        response = MessagingResponse()
        response.message(
            "Sorry, I encountered an error. Please try again or call us for help."
        )

        return Response(content=str(response), media_type="application/xml")


@app.post("/sms/outgoing")
async def send_outbound_sms(sms: OutgoingSMS):
    """
    Send outbound SMS (for system-initiated messages)
    """
    try:
        result = await send_sms(to=sms.to, message=sms.message)
        return {"success": True, "sid": result.sid}
    except Exception as e:
        logger.error(f"Error sending SMS: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/voice/status")
async def handle_voice_status(request: Request):
    """Handle voice call status callbacks from Twilio"""
    body = await request.body()

    # Log status but don't validate (status callbacks don't always have valid signatures)
    form_data = await request.form()
    call_sid = form_data.get("CallSid")
    call_status = form_data.get("CallStatus")

    logger.info(f"Call {call_sid} status: {call_status}")

    return {"status": "ok"}


async def send_sms(to: str, message: str):
    """Send SMS via Twilio"""
    from twilio.rest import Client

    client = Client(settings.twilio_account_sid, settings.twilio_auth_token)

    result = client.messages.create(
        to=to,
        from_=settings.twilio_phone_number,
        body=message,
    )

    logger.info(f"Sent SMS to {to}, SID: {result.sid}")
    return result


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
    )
