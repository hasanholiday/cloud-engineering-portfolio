"""Safety checks. Stage 6: plan for prompt injection and data leaks.

Three layers: (1) screen the user's question, (2) quarantine retrieved text that
tries to give orders, (3) redact secrets and personal data from the answer.
"""
import re

INJECTION_PATTERNS = [
    r"ignore (all |any )?(of )?(the |your )?(previous|prior|above|earlier)? ?(rules|instructions|prompts?)",
    r"disregard (all |any )?(the |your )?(previous|prior|above)? ?(rules|instructions)",
    r"(reveal|print|show|repeat|output) (me )?(your |the )?(system )?(prompt|instructions)",
    r"you are now",
    r"send (the |a )?(full |entire )?[\w ]{0,30}(list|data|records|passwords?|keys?) to",
    r"\bact as\b.{0,40}\b(admin|root|developer mode)\b",
]
_INJ = [re.compile(p, re.I) for p in INJECTION_PATTERNS]

REDACTIONS = [
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[email removed]"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "[aws key removed]"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "[private key removed]"),
    (re.compile(r"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"), "[phone removed]"),
]

MAX_QUESTION_CHARS = 500


def looks_like_injection(text: str) -> bool:
    return any(p.search(text) for p in _INJ)


def check_input(question: str):
    """Return (ok, reason). Blocks empty, oversized and order-giving questions."""
    q = (question or "").strip()
    if not q:
        return False, "empty question"
    if len(q) > MAX_QUESTION_CHARS:
        return False, "question too long"
    if looks_like_injection(q):
        return False, "question tries to change the assistant's rules"
    return True, ""


def quarantine(passages):
    """Split retrieved passages into (safe, quarantined). Poisoned text never reaches the model."""
    safe, bad = [], []
    for p in passages:
        (bad if looks_like_injection(p["text"]) else safe).append(p)
    return safe, bad


def redact(text: str) -> str:
    for pattern, repl in REDACTIONS:
        text = pattern.sub(repl, text)
    return text
