import os
import json
import re
from google import genai
from google.genai import types

# Newest first. Each model has its own separate free-tier daily quota
# (confirmed via the RESOURCE_EXHAUSTED error, which is scoped per-model),
# so falling back through several effectively multiplies our daily headroom
# instead of hitting one shared 20-requests-a-day wall.
FALLBACK_MODELS = [
    "gemini-3.6-flash",
    "gemini-3.5-flash",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash",
]


def get_client() -> genai.Client:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not set")
    return genai.Client(api_key=api_key)


def extract_json(text: str) -> dict:
    text = text.strip()
    text = re.sub(r'^```(?:json)?\s*', '', text)
    text = re.sub(r'\s*```\s*$', '', text)
    return json.loads(text.strip())


def generate_with_fallback(
    client: genai.Client,
    contents,
    system_instruction: str | None = None,
):
    """Try each model in FALLBACK_MODELS in order until one succeeds.

    Per-attempt retries are disabled (attempts=1) so a single overloaded or
    quota-exhausted model fails in ~1 request instead of stalling behind the
    SDK's own multi-minute exponential backoff — that's what let an earlier
    503 on gemini-3.7-flash hang for 2 minutes on its own. Fast failure here
    is what makes cycling through 5 models in one request actually practical.
    """
    fast_fail = types.HttpOptions(retry_options=types.HttpRetryOptions(attempts=1))
    config = types.GenerateContentConfig(http_options=fast_fail, system_instruction=system_instruction)

    last_error: Exception | None = None
    for model in FALLBACK_MODELS:
        try:
            return client.models.generate_content(model=model, contents=contents, config=config)
        except Exception as e:
            last_error = e
            continue
    raise last_error
