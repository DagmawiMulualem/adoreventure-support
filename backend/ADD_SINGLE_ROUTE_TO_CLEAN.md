# Add `/api/idea/single` to adoreventure-backend-clean

Copy the following into your **adoreventure-backend-clean** repo's `app.py`.

## 1. Add `is_valid_url` (after `is_valid_location`, before `CATEGORY_PROMPTS`)

```python
def is_valid_url(url_string):
    if not url_string or (isinstance(url_string, str) and url_string.lower() == "null"):
        return True
    s = (url_string or "").lower()
    if not (s.startswith("http://") or s.startswith("https://")):
        return False
    bad = ["example.com", "test.com", "localhost", "127.0.0.1"]
    return not any(d in s for d in bad)
```

## 2. Add the `/api/idea/single` route (after `get_ideas`, before `@app.route('/api/ideas/test')`)

```python
@app.route('/api/idea/single', methods=['POST'])
def get_idea_single():
    """Generate a single idea (for streaming: one card at a time). Call 3 times for 3 ideas."""
    try:
        data = request.get_json() or {}
        location = (data.get('location') or '').strip()
        category = data.get('category', 'general')
        index = data.get('index', 1)
        total = data.get('total', 3)
        previous_titles = data.get('previous_titles') or []
        budget_hint = (data.get('budgetHint') or '').strip()
        time_hint = (data.get('timeHint') or '').strip()
        indoor_outdoor = (data.get('indoorOutdoor') or '').strip()

        if not location or not is_valid_location(location):
            return jsonify({"error": "Invalid location provided"}), 400

        system_prompt = """
You generate activity ideas as STRICT JSON only.
Output MUST be a JSON object with this exact shape (ONE idea only):

{"ideas":[{"title":"String","blurb":"1 sentence","rating":4.5,"place":"Venue","duration":"1-2h","priceRange":"$10-20","tags":["tag1"],"address":"Address or null","phone":null,"website":"URL or null","bookingURL":null,"bestTime":"Evening","hours":["Mon-Sun 9am-5pm"]}]}

RULES: 1 idea only. Real place. Rating 4.3-5.0. Verified URLs or null. Include phone, bookingURL, bestTime, hours when known.
"""
        avoid = f" Do NOT suggest: {', '.join(previous_titles[:10])}. Suggest something different." if previous_titles else ""
        user_prompt = f"""Give exactly 1 {category} activity in {location}. This is suggestion {index} of {total}.{avoid}{f" Budget: {budget_hint}." if budget_hint else ""}{f" Time: {time_hint}." if time_hint else ""}{f" Setting: {indoor_outdoor}." if indoor_outdoor else ""} Use basic admission prices only."""

        logger.info(f"Generating single idea {index}/{total} for {location} - {category}")

        response = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"},
            max_tokens=500
        )

        content = response.choices[0].message.content
        ideas_data = json.loads(content)
        ideas_list = ideas_data.get('ideas', [])
        if not ideas_list:
            return jsonify({"error": "No idea in response"}), 500

        idea = ideas_list[0]
        if idea.get('website') and not is_valid_url(idea['website']):
            idea['website'] = None
        if idea.get('bookingURL') and not is_valid_url(idea.get('bookingURL')):
            idea['bookingURL'] = None

        logger.info(f"Generated idea {index}/{total}: {idea.get('title', '')}")
        return jsonify({"ideas": [idea]})

    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error in single idea: {e}")
        return jsonify({"error": "Invalid JSON from AI"}), 500
    except Exception as e:
        logger.error(f"Error generating single idea: {e}")
        return jsonify({"error": str(e)}), 500
```

## 3. Deploy

- Commit and push to `main` on `DagmawiMulualem/adoreventure-backend-clean`.
- Trigger a redeploy on Render for **adoreventure-backend-clean**.

## 4. Verify

```bash
curl -X POST https://adoreventure-backend-clean.onrender.com/api/idea/single \
  -H "Content-Type: application/json" \
  -d '{"location":"Paris","category":"date","index":1,"total":3}'
```

You should get `{"ideas":[{ ... }]}` and not 404.
