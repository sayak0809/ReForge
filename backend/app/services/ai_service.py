import asyncio
from google.genai import types
from dotenv import load_dotenv
from app.services.gemini_client import get_client, extract_json

load_dotenv()

FOOD_PROMPT = """Analyze these food image(s) — they may show the same meal from different angles.
For each item, first estimate its portion size/amount (e.g. weight or volume) using visual cues like plate size, \
utensils, and typical serving proportions — you need this estimate to derive accurate calories, protein, fat, \
and carbs, even though the amount itself is not part of the output.
Return ONLY valid JSON in exactly this shape:
{"items": ["item1", "item2"], "calories": number, "protein_g": number, "fat_g": number, "carbs_g": number, "confidence": number between 0 and 1}
No other text, no markdown, just the JSON object."""


def _call_gemini_sync(images: list[bytes]) -> dict:
    """Runs in a thread pool — keeps the httpx client isolated from FastAPI's event loop."""
    client = get_client()
    image_parts = [
        types.Part.from_bytes(data=img, mime_type="image/jpeg")
        for img in images
    ]
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=[FOOD_PROMPT] + image_parts,
    )
    return extract_json(response.text)


async def analyze_food_images(images: list[bytes]) -> dict:
    return await asyncio.to_thread(_call_gemini_sync, images)
