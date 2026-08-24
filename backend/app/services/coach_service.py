from sqlalchemy.orm import Session
from google.genai import types
from app.models import CoachMessage
from app.services.gemini_client import get_client
from app.services.user_context import gather_user_context, format_context_text

HISTORY_LIMIT = 20

SYSTEM_PROMPT_TEMPLATE = """You are Coach, an encouraging but direct AI fitness and nutrition coach inside the Reforge app.
You have access to this user's real profile and history — use it to give specific, personalized answers, not generic advice.
Keep responses conversational and concise (a few sentences, unless the user asks for detail). Don't just repeat their raw stats back at them unless it's relevant to the question.

User's current data:
{context}
"""


def chat_with_coach(db: Session, user_id: int, message: str) -> str:
    context = gather_user_context(db, user_id)
    if not context:
        raise ValueError("User not found")

    history = (
        db.query(CoachMessage)
        .filter(CoachMessage.user_id == user_id)
        .order_by(CoachMessage.created_at.desc())
        .limit(HISTORY_LIMIT)
        .all()
    )
    history = list(reversed(history))

    contents = [
        types.Content(
            role="user" if m.role == "user" else "model",
            parts=[types.Part.from_text(text=m.content)],
        )
        for m in history
    ]
    contents.append(types.Content(role="user", parts=[types.Part.from_text(text=message)]))

    system_instruction = SYSTEM_PROMPT_TEMPLATE.format(context=format_context_text(context))

    client = get_client()
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=contents,
        config=types.GenerateContentConfig(system_instruction=system_instruction),
    )
    reply = response.text.strip()

    db.add(CoachMessage(user_id=user_id, role="user", content=message))
    db.add(CoachMessage(user_id=user_id, role="assistant", content=reply))
    db.commit()

    return reply
