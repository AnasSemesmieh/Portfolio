---
name: agnes-image-generation
description: Generate images for free with the Agnes AI API (OpenAI-compatible /v1/images/generations). Scene-based prompts, download-immediately workflow, retry on 503.
version: 1.0.0
license: MIT
triggers:
  - generate an image
  - agnes image
  - make a picture
  - image generation
  - draw an image
metadata:
  hermes:
    tags: [agnes, image, generation, media, free]
---

# Agnes AI Image Generation

Generate images for **free** using the Agnes AI API. One API key (the same one
that runs Agnes text models) covers image generation. This skill is framework-
agnostic but written for Hermes Agent.

## When to use
Load whenever the user asks to generate, create, or draw an image and an Agnes
API key is available in the environment as `AGNES_AI_API_KEY`.

## API basics
- **Endpoint:** `POST https://apihub.agnes-ai.com/v1/images/generations`
- **Auth:** `Authorization: Bearer $AGNES_AI_API_KEY`
- **Model:** `agnes-image-2.5-flash` (preferred — newest, best quality) ·
  `agnes-image-2.1-flash` (fallback)
- **Sizes:** `1024x1024` (square), `1024x768` (landscape), `768x1024`
  (portrait), `1536x1024` (wide cinematic)
- **Output:** a temporary URL at `data[0].url` — **download it immediately**,
  these URLs expire.
- **Cost:** $0 during the Agnes free period.

## Curl template
```bash
curl -s --max-time 120 -X POST https://apihub.agnes-ai.com/v1/images/generations \
  -H "Authorization: Bearer $AGNES_AI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "agnes-image-2.5-flash",
    "prompt": "an isometric data center at night, glowing server racks, clean futuristic style",
    "size": "1536x1024",
    "n": 1
  }'
```
Parse `data[0].url` from the response, then:
```bash
curl -sL "<url-from-response>" -o ~/Downloads/agnes-image.png
```

## Python template (with retry — recommended)
Agnes free capacity is bursty; retry on `503`. Generation takes ~20–30s, so
allow a generous timeout and prefer running this as a background job.

```python
import os, requests, time, subprocess

key = os.environ["AGNES_AI_API_KEY"]
prompt = "a glowing neural network in a dark void, cinematic, high detail"
out = os.path.expanduser("~/Downloads/agnes-image.png")

for attempt in range(5):
    try:
        resp = requests.post(
            "https://apihub.agnes-ai.com/v1/images/generations",
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            json={"model": "agnes-image-2.5-flash", "prompt": prompt,
                  "size": "1536x1024", "n": 1},
            timeout=300,
        )
        data = resp.json()
        if "data" in data:
            url = data["data"][0]["url"]
            subprocess.run(["curl", "-sL", url, "-o", out])
            print("SAVED", out)
            break
        elif resp.status_code == 503:
            print(f"503 busy, retry {attempt+1}/5"); time.sleep(30)
        else:
            print(f"error {resp.status_code}: {data}"); time.sleep(20)
    except Exception as e:
        print(f"exception {type(e).__name__}, retry {attempt+1}"); time.sleep(20)
```

## Prompt rules
- **Describe scenes and environments**, not text. The model garbles rendered
  text, labels, and documents — ask for objects, lighting, and composition
  instead.
- Be concrete: subject, environment, action, lighting, and style in one line.
- Keep a consistent style suffix if you want a cohesive set (e.g. a fixed
  aesthetic + lighting descriptor appended to every prompt).

## Pitfalls
- **Only `/v1/images/generations` works.** Variant paths (`/images/generate`,
  `/images/edit`, etc.) 404 or hang.
- **Download immediately** — output URLs are temporary.
- **Daily limit** — roughly 15–20 images/day on the free tier before persistent
  rate-limits. If every retry 503s and then times out at the TCP layer, you've
  hit the daily cap; resume the next day.
- **Run as a background job** — generation regularly exceeds a 120s foreground
  timeout.
