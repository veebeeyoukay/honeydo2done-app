"""Audio transcription service using OpenAI Whisper"""

from openai import AsyncOpenAI
from loguru import logger
from config import get_settings

settings = get_settings()
client = AsyncOpenAI(api_key=settings.openai_api_key)


async def transcribe_audio(audio_data: bytes, filename: str = "recording.mp3") -> str:
    """
    Transcribe audio using Whisper API

    Args:
        audio_data: Audio file bytes
        filename: Filename for the audio (must have extension)

    Returns:
        Transcribed text
    """
    try:
        logger.info(f"Transcribing audio ({len(audio_data)} bytes)")

        # Create a file-like object
        from io import BytesIO

        audio_file = BytesIO(audio_data)
        audio_file.name = filename

        # Call Whisper API
        response = await client.audio.transcriptions.create(
            model="whisper-1",
            file=audio_file,
            language="en",  # Force English for consistency
        )

        transcript = response.text
        logger.info(f"Transcription successful: {len(transcript)} characters")

        return transcript

    except Exception as e:
        logger.error(f"Transcription error: {e}", exc_info=True)
        raise Exception(f"Failed to transcribe audio: {str(e)}")
