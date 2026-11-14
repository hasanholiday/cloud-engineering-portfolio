"""Stage 6: write down real questions with right answers, run them every time anything changes, and do not ship if the score drops.

Offline (free):   python evals/run_evals.py --offline
Live endpoint:    python evals/run_evals.py --url https://<api>/prod/ask --api-key KEY
Offline mode checks retrieval, refusals, quarantine and redaction with a fake model that copies the best passage.
Live mode checks the real model's answers end to end. Grow questions.jsonl toward 50 real questions.
"""
import argparse
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "evals"))

import rag  # noqa: E402
from offline_embed import embed  # noqa: E402


def build_offline_index():
    index = []
    for p in sorted((ROOT / "sample-docs").glob("*.md")):
        for c in rag.chunk_text(p.read_text(), p.name):
            c["vector"] = embed(c["text"])
            index.append(c)
    return index


def fake_generate(system, user):
    """Pretend model: returns the first passage verbatim. Lets us test everything except real model quality."""
    start = user.find(">") + 1
    end = user.find("</doc>")
    return user[start:end], {"input_tokens": 0, "output_tokens": 0}


def ask_offline(index, q):
    return rag.answer(q, index, embed, fake_generate)


def ask_live(url, key, q):
    req = urllib.request.Request(url, data=json.dumps({"question": q}).encode(), headers={"Content-Type": "application/json", "x-api-key": key})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:  # blocked requests return 400 with a JSON body
        return json.loads(e.read())


def score(case, out):
    text = out.get("answer", "").lower()
    src = [s["id"].split("#")[0] for s in out.get("sources", [])]
    t = case["type"]
    if t == "answer":
        return all(k.lower() in text for k in case["must_include"]) and case["source"] in src
    if t == "unanswerable":
        return text.startswith("i can't find") or "do not know" in text or "don't know" in text
    return not any(bad.lower() in text for bad in case["must_not_include"]) or out.get("blocked", False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--url")
    ap.add_argument("--api-key", default="")
    ap.add_argument("--threshold", type=float, default=0.85)
    a = ap.parse_args()
    cases = [json.loads(l) for l in (ROOT / "evals" / "questions.jsonl").read_text().splitlines() if l.strip()]
    index = build_offline_index() if a.offline else None
    passed, failed = 0, []
    for c in cases:
        out = ask_offline(index, c["q"]) if a.offline else ask_live(a.url, a.api_key, c["q"])
        if score(c, out):
            passed += 1
        else:
            failed.append((c["type"], c["q"], out.get("answer", "")[:100]))
    rate = passed / len(cases)
    print(f"{passed}/{len(cases)} passed ({rate:.0%})")
    for f in failed:
        print("FAIL", f)
    sys.exit(0 if rate >= a.threshold else 1)


if __name__ == "__main__":
    main()
