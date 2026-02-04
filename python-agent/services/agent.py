"""Conversational AI agent using Claude for triage"""

from anthropic import AsyncAnthropic
from loguru import logger
from typing import Dict, Any, List
import json

from config import get_settings
from services.supabase_client import SupabaseClient
from services.state_manager import StateManager

settings = get_settings()
client = AsyncAnthropic(api_key=settings.anthropic_api_key)
supabase = SupabaseClient()
state_manager = StateManager()


class ConversationalAgent:
    """AI agent for conversational triage via SMS"""

    def __init__(self):
        self.model = "claude-opus-4-5"

    async def start_triage_via_sms(self, task_id: str, phone_number: str) -> str:
        """
        Start triage conversation via SMS

        Args:
            task_id: Task UUID
            phone_number: User's phone number

        Returns:
            SMS message to send
        """
        try:
            logger.info(f"Starting triage for task {task_id}")

            # Get task details
            task = await supabase.get_task(task_id)

            if not task:
                raise Exception(f"Task {task_id} not found")

            # Generate triage questions using Claude
            questions = await self._generate_triage_questions(
                task["description"],
                task.get("structured_data", {}),
            )

            # Save state
            await state_manager.save_state(
                phone_number,
                {
                    "task_id": task_id,
                    "state": "triaging",
                    "current_question": 0,
                    "total_questions": len(questions),
                    "questions": questions,
                    "answers": {},
                },
            )

            # Format first question
            first_question = questions[0]
            message = self._format_question_sms(first_question, 1, len(questions))

            logger.info(f"Triage started for task {task_id}")

            return message

        except Exception as e:
            logger.error(f"Error starting triage: {e}", exc_info=True)
            return "I've captured your task. A team member will follow up shortly!"

    async def process_triage_answer(
        self, task_id: str, phone_number: str, answer: str
    ) -> str:
        """
        Process triage answer and send next question or decision

        Args:
            task_id: Task UUID
            phone_number: User's phone number
            answer: User's answer text

        Returns:
            SMS message to send
        """
        try:
            # Get conversation state
            state = await state_manager.get_state(phone_number)

            if not state:
                return "Sorry, I couldn't find our conversation. Please start over."

            # Save answer
            current_q = state["current_question"]
            questions = state["questions"]
            question_id = questions[current_q]["id"]

            state["answers"][question_id] = answer

            # Move to next question
            state["current_question"] += 1

            # Check if triage is complete
            if state["current_question"] >= state["total_questions"]:
                # Triage complete - update task and send decision
                await self._complete_triage(task_id, state["answers"])

                # Clear state
                await state_manager.clear_state(phone_number)

                return (
                    "Thanks! I have everything I need. "
                    "Check the app for my recommendation on how to handle this."
                )

            else:
                # Send next question
                next_question = questions[state["current_question"]]
                await state_manager.save_state(phone_number, state)

                return self._format_question_sms(
                    next_question,
                    state["current_question"] + 1,
                    state["total_questions"],
                )

        except Exception as e:
            logger.error(f"Error processing answer: {e}", exc_info=True)
            return "Sorry, I encountered an error. Please try again."

    async def _generate_triage_questions(
        self, description: str, structured_data: Dict[str, Any]
    ) -> List[Dict[str, str]]:
        """
        Generate triage questions using Claude

        Args:
            description: Task description
            structured_data: Existing structured data

        Returns:
            List of questions
        """
        system_prompt = """You are an AI assistant for HoneyDo2Done.
Generate 2-3 clarifying questions to understand a home task better.

CRITICAL: Return ONLY valid JSON. No explanations.

Output format:
{
  "questions": [
    {
      "id": "q1",
      "prompt": "When did you first notice this issue?",
      "answer_type": "text"
    }
  ]
}

Keep questions conversational and short (good for SMS).
Focus on MISSING information needed to decide DIY vs Pro."""

        user_prompt = f"""Task: "{description}"

Current data: {json.dumps(structured_data, indent=2)}

Generate 2-3 questions. Return ONLY the JSON object."""

        try:
            response = await client.messages.create(
                model=self.model,
                max_tokens=1024,
                temperature=0.3,
                system=system_prompt,
                messages=[{"role": "user", "content": user_prompt}],
            )

            content = response.content[0].text
            parsed = json.loads(content)

            return parsed.get("questions", [])

        except Exception as e:
            logger.error(f"Error generating questions: {e}", exc_info=True)

            # Fallback questions
            return [
                {
                    "id": "q1",
                    "prompt": "When did you first notice this issue?",
                    "answer_type": "text",
                },
                {
                    "id": "q2",
                    "prompt": "Have you tried anything to fix it?",
                    "answer_type": "text",
                },
            ]

    async def _complete_triage(self, task_id: str, answers: Dict[str, str]):
        """
        Complete triage and update task

        Args:
            task_id: Task UUID
            answers: Dictionary of answers
        """
        try:
            # Call Supabase edge function to process triage
            await supabase.complete_triage(task_id, answers)

            logger.info(f"Triage completed for task {task_id}")

        except Exception as e:
            logger.error(f"Error completing triage: {e}", exc_info=True)

    def _format_question_sms(
        self, question: Dict[str, str], number: int, total: int
    ) -> str:
        """
        Format question for SMS

        Args:
            question: Question dict
            number: Question number (1-indexed)
            total: Total questions

        Returns:
            Formatted SMS message
        """
        prompt = question["prompt"]

        if total > 1:
            return f"Question {number}/{total}: {prompt}"
        else:
            return prompt
