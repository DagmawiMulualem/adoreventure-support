from flask import Flask, request, jsonify
from flask_cors import CORS
import openai
import os
from dotenv import load_dotenv
import json
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configure OpenAI
openai.api_key = os.getenv('OPENAI_API_KEY')

def is_valid_url(url_string):
    if not url_string or (isinstance(url_string, str) and url_string.lower() == "null"):
        return True
    s = (url_string or "").lower()
    if not (s.startswith("http://") or s.startswith("https://")):
        return False
    bad = ["example.com", "test.com", "localhost", "127.0.0.1"]
    return not any(d in s for d in bad)

def is_valid_location(location):
    if not location or len((location or "").strip()) < 3:
        return False
    bad = ["mars", "moon", "hogwarts", "test location", "example city"]
    return not any(b in (location or "").lower() for b in bad)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "adoreventure-ai-backend"})

@app.route('/api/ideas', methods=['POST'])
def get_ideas():
    """Generate adventure ideas using OpenAI"""
    try:
        # Get request data
        data = request.get_json()

        if not data:
            return jsonify({"error": "No data provided"}), 400

        # Extract parameters
        location = data.get('location', '')
        category = data.get('category', '')
        budget_hint = data.get('budgetHint', '')
        time_hint = data.get('timeHint', '')
        indoor_outdoor = data.get('indoorOutdoor', '')

        if not location or not category:
            return jsonify({"error": "Location and category are required"}), 400

        logger.info(f"Generating ideas for location: {location}, category: {category}")

        # Build system prompt
        system_prompt = """
        You generate activity ideas as STRICT JSON only.
        Output MUST be a JSON object with this exact shape:

        {
          "ideas": [
            {
              "title": "String",
              "blurb": "Short enticing description (1–2 sentences).",
              "rating": 4.3,
              "place": "Neighborhood or venue name",
              "duration": "e.g. 1–3 hours",
              "priceRange": "$$",
              "tags": ["short","tag","words"],

              // Detail fields (optional but preferred; use null if unknown)
              "address": "Full address or area, city/state",
              "phone": "(202) 555-0199",
              "website": null,
              "bookingURL": null,
              "bestTime": "e.g. Golden hour 6–8 pm",
              "hours": ["Mon–Thu 10am–9pm","Fri–Sat 10am–11pm","Sun 10am–8pm"]
            }
          ]
        }

        Do not include any text outside JSON.
        Ratings must be between 4.3 and 5.0. Return 6–10 ideas.
        """

        # Build user prompt
        user_prompt = f"""
        Location: {location}
        Category: {category}
        Preferences:
        {f"Budget: {budget_hint}" if budget_hint else "-"}
        {f"Time: {time_hint}" if time_hint else "-"}
        {f"Setting: {indoor_outdoor}" if indoor_outdoor else "-"}
        Return only activities relevant to the location/category.
        """

        # Call OpenAI API
        response = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"}
        )

        # Extract and parse response
        content = response.choices[0].message.content
        ideas_data = json.loads(content)

        logger.info(f"Successfully generated {len(ideas_data.get('ideas', []))} ideas")

        return jsonify(ideas_data)

    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error: {e}")
        return jsonify({"error": "Invalid JSON response from AI"}), 500
    except Exception as e:
        logger.error(f"Error generating ideas: {e}")
        return jsonify({"error": "Internal server error"}), 500


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


@app.route('/api/ideas/test', methods=['GET'])
def test_ideas():
    """Test endpoint with sample data"""
    sample_ideas = {
        "ideas": [
            {
                "title": "Sunset Kayaking Adventure",
                "blurb": "Paddle through calm waters while watching the sun set over the horizon.",
                "rating": 4.8,
                "place": "Harbor Point Marina",
                "duration": "2-3 hours",
                "priceRange": "$$",
                "tags": ["outdoor", "water", "sunset", "romantic"],
                "address": "123 Harbor Drive, Washington DC",
                "phone": "(202) 555-0123",
                "website": null,
                "bookingURL": null,
                "bestTime": "Golden hour 6-8 pm",
                "hours": ["Mon-Sun 9am-9pm"]
            }
        ]
    }
    return jsonify(sample_ideas)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
