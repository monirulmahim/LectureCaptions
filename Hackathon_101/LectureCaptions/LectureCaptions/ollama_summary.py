#!/usr/bin/env python3
import argparse, json, subprocess, sys

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="gemma3:4b")
    ap.add_argument("--text", required=True)
    args = ap.parse_args()

    prompt = f"""
You are a university lecture assistant.

Return ONLY valid JSON with this schema:
{{
  "bullets": [string, ...],
  "keywords": [string, ...],
  "questions": [string, ...]
}}

Rules:
- bullets: 5-8 concise points
- keywords: 8-12 important terms/phrases
- questions: 3-6 study/exam questions
- No markdown, no extra commentary, ONLY JSON.

Lecture transcript:
{args.text}
""".strip()

    try:
        p = subprocess.run(
            ["ollama", "run", args.model],
            input=prompt.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError:
        print(json.dumps({"error": "ollama_not_found"}))
        sys.exit(2)

    out = p.stdout.decode("utf-8", errors="ignore").strip()
    err = p.stderr.decode("utf-8", errors="ignore").strip()

    if p.returncode != 0 and not out:
        print(json.dumps({"error": "ollama_failed", "stderr": err[:500]}))
        sys.exit(3)

    # extract JSON block if model wrapped it
    first = out.find("{")
    last = out.rfind("}")
    if first != -1 and last != -1 and last > first:
        out = out[first:last+1]

    try:
        obj = json.loads(out)
    except Exception:
        print(json.dumps({"error": "invalid_json", "raw": out[:800]}))
        sys.exit(4)

    bullets = obj.get("bullets") or []
    keywords = obj.get("keywords") or []
    questions = obj.get("questions") or []

    print(json.dumps({
        "bullets": bullets,
        "keywords": keywords,
        "questions": questions
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
