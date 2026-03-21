from flask import Flask, request, jsonify
from flask_cors import CORS
import openai
import os
from dotenv import load_dotenv
import json
import logging
import hashlib
import time
from urllib.parse import quote_plus, urlparse

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Simple in-memory cache (in production, use Redis)
idea_cache = {}
CACHE_DURATION = 300  # 5 minutes

# Configure OpenAI
openai_api_key = os.getenv('OPENAI_API_KEY')
if not openai_api_key:
    logger.error("OPENAI_API_KEY environment variable is not set!")
    client_configured = False
else:
    logger.info("OPENAI_API_KEY is configured")
    try:
        openai.api_key = openai_api_key
        client_configured = True
        logger.info("OpenAI client configured successfully")
    except Exception as e:
        logger.error(f"Failed to configure OpenAI client: {e}")
        client_configured = False

# URL validation function
def is_valid_url(url_string):
    """
    Validate URLs and only allow clearly trusted / well-known domains.
    Anything uncertain or local/small should be treated as invalid so we show no link.
    """
    if not url_string or str(url_string).lower() == "null":
        return True  # null is allowed (means "no website")

    s = str(url_string).strip()
    lower = s.lower()

    # Must be http/https
    if not (lower.startswith("http://") or lower.startswith("https://")):
        return False

    # Reject obviously fake or placeholder domains
    suspicious_domains = [
        "example.com", "test.com", "demo.com", "sample.com", "placeholder.com",
        "fake.com", "mock.com", "dummy.com", "temp.com", "localhost",
        "127.0.0.1", "0.0.0.0"
    ]
    if any(d in lower for d in suspicious_domains):
        return False

    try:
        parsed = urlparse(s)
        hostname = (parsed.hostname or "").lower()
        if not hostname:
            return False

        # Allow-list of clearly trusted / established domains
        trusted_domains = [
            # Government / education / major orgs
            ".gov", ".edu", ".org",
            "nps.gov", "smithsonian.org",
            # Big travel / booking platforms
            "tripadvisor.com", "booking.com", "airbnb.com", "eventbrite.com",
            "yelp.com",
            # Large, globally recognised brands (very low risk)
            "disney.com", "google.com", "apple.com", "microsoft.com",
            # Safe fallbacks when venue URL unknown (search / maps intent)
            "maps.google.com",
        ]

        # Accept if hostname matches any trusted pattern
        for pattern in trusted_domains:
            if hostname.endswith(pattern) or hostname == pattern:
                return True

        # Google Search / Maps paths on google.com
        if hostname.endswith("google.com") or hostname == "google.com":
            path = (parsed.path or "").lower()
            if path.startswith("/search") or path.startswith("/maps"):
                return True

        # Everything else is treated as untrusted (we won't show it)
        return False
    except Exception:
        return False


def is_valid_phone(phone_string: str) -> bool:
    """
    Basic phone validation: allow only numbers that look like real contact numbers.
    If in doubt, treat as invalid so we hide it.
    """
    if not phone_string:
        return True  # null is allowed

    import re

    s = str(phone_string).strip()
    # Strip everything except digits
    digits = re.sub(r"\D", "", s)
    if len(digits) < 10:
        return False

    # Only allow these characters in the original string
    if re.search(r"[^0-9+\-\s().]", s):
        return False

    return True


def google_search_url(query: str) -> str:
    """HTTPS Google web search link (safe fallback when venue URL is unknown)."""
    return "https://www.google.com/search?q=" + quote_plus(query.strip())


def enrich_idea_with_safe_links(idea: dict, location: str) -> None:
    """
    When website/booking were removed or never set, use Google Search URLs instead of leaving users
    with no action — avoids invented local URLs/phones in unfamiliar regions.
    """
    place = (idea.get("place") or idea.get("title") or "").strip()
    loc = (location or "").strip()
    if not place:
        return
    label = f"{place} {loc}".strip()

    w = idea.get("website")
    if w is None or str(w).strip().lower() in ("", "null", "none"):
        idea["website"] = google_search_url(f"{label} official website")

    b = idea.get("bookingURL")
    if b is None or str(b).strip().lower() in ("", "null", "none"):
        idea["bookingURL"] = google_search_url(f"{label} reservations tickets")


# Location validation function
def is_valid_location(location):
    """Check if location is a real, accessible place"""
    # Common invalid locations
    invalid_locations = [
        "mars", "moon", "jupiter", "saturn", "venus", "mercury", "neptune", "uranus", "pluto",
        "hogwarts", "middle earth", "narnia", "westeros", "neverland", "atlantis", "el dorado",
        "shangri-la", "utopia", "fantasy land", "dream world", "imaginary place", "fake city",
        "test location", "example city", "sample town", "demo place", "mock location"
    ]
    
    location_lower = location.lower().strip()
    
    # Check against invalid locations
    for invalid in invalid_locations:
        if invalid in location_lower:
            return False
    
    # Check if location is too short or generic
    if len(location.strip()) < 3:
        return False
    
    # Check for obvious non-locations
    if any(word in location_lower for word in ["test", "example", "sample", "demo", "fake", "mock"]):
        return False
    
    return True

def enrich_time_hint_for_special_events(category, time_hint):
    """Add category-specific constraints to keep ideas aligned with UX."""
    base_hint = (time_hint or "").strip()
    c = str(category).lower()

    category_constraint = ""
    if c == "special":
        category_constraint = (
            "Only include upcoming events from today through the next 14 days and do not include past events. "
            "Include the exact event date (day and month) in each idea title or blurb, "
            "and prefer Eventbrite or official venue booking links when available."
        )
    elif c == "local":
        category_constraint = (
            "Prioritize truly local-feeling spots and activities like neighborhood coffee shops, "
            "VR or game places, gardens, parks, and community hangouts. "
            "Avoid tourist attractions and generic travel landmarks."
        )

    if not category_constraint:
        return base_hint
    return f"{base_hint}. {category_constraint}" if base_hint else category_constraint

# Category-specific system prompts
CATEGORY_PROMPTS = {
    "date": """You are a specialized Date Ideas Expert. You generate romantic, memorable, and engaging date activities for couples.

Your expertise includes:
- Romantic dining experiences and unique restaurants
- Cultural activities (museums, theaters, galleries)
- Outdoor adventures and scenic locations
- Entertainment venues and shows
- Wellness and relaxation activities
- Creative and interactive experiences

Focus on activities that:
- Foster connection and conversation
- Create memorable moments
- Are suitable for couples
- Offer variety in price ranges
- Include both indoor and outdoor options

VERY IMPORTANT CATEGORY RULES:
- ONLY suggest ideas that a couple would intentionally choose as a *date*.
- Do NOT suggest items that are primarily: family outings, generic tourist attractions, kids activities, or large team-building events.
- If an idea could fit multiple categories, shape it specifically as a couple-focused experience (e.g. “romantic dinner”, “date night”, “sunset walk for two”).

PRICING GUIDELINES:
- Provide BASIC ADMISSION/ENTRY costs only, not performance or special event prices
- For free venues (museums, centers, parks): Use "Free" or "$0"
- For paid venues: Use admission price like "$15 per person" or "$10-20 per person"
- For restaurants: Use typical meal costs
- For activities: Use basic activity cost, not premium packages
- Do NOT include performance tickets, special events, or premium experiences
- Focus on what it costs to visit/enter the place, not what you can do there

HOURS GUIDELINES:
- Provide accurate, current operating hours
- Include days of the week when relevant
- Note seasonal variations if applicable
- Include special hours for holidays or events
- Use format: "Mon-Fri 9am-5pm, Sat-Sun 10am-6pm"

WEBSITE & BOOKING GUIDELINES - CRITICAL SECURITY REQUIREMENTS:
- NEVER include fake, placeholder, or example websites (like example.com, test.com, demo.com, etc.)
- NEVER make up or guess website URLs - if you don't know the exact URL, use null
- ONLY include websites from these trusted domains:
  * .gov (government websites)
  * .edu (educational institutions)
  * .org (non-profit organizations)
  * Major established businesses with verified domains (like disney.com, nps.gov, etc.)
- For local businesses, if you're not 100% certain of their website, use null
- For booking URLs, only include verified booking platforms like:
  * opentable.com, resy.com (restaurants)
  * airbnb.com, booking.com (accommodations)
  * eventbrite.com (events)
  * Major venue websites you can verify
- If a business doesn't have a website, that's perfectly fine - use null
- NEVER create or suggest fake URLs - this is a security requirement

IMPORTANT: Only suggest activities that actually exist in the specified location. If the location is invalid or fictional, respond with an error message.""",

    "travel": """You are a specialized Travel Activities Expert. You generate exciting travel experiences and adventures for tourists and travelers.

Your expertise includes:
- Tourist attractions and landmarks
- Adventure activities and outdoor experiences
- Cultural immersion and local experiences
- Food and culinary tours
- Historical sites and educational activities
- Entertainment and nightlife
- Shopping and markets
- Transportation and sightseeing

Focus on activities that:
- Showcase the destination's unique character
- Appeal to travelers and tourists
- Offer authentic local experiences
- Include both popular and hidden gems
- Cater to different interests and budgets

VERY IMPORTANT CATEGORY RULES:
- Suggestions must make sense for people who are *visiting* the area, not locals on an everyday outing.
- Avoid ideas that are clearly “date night only” or “local hobby groups” unless they are iconic enough that travelers commonly do them.

PRICING GUIDELINES:
- Research and provide accurate price estimates when possible
- Use specific ranges like "$25-45 per person" instead of just "$"
- For attractions, include admission fees
- For tours, include per-person costs
- For free attractions, use "$0" or "Free"
- For premium experiences, use specific ranges like "$80-150 per person"

HOURS GUIDELINES:
- Provide accurate, current operating hours
- Include days of the week when relevant
- Note seasonal variations if applicable
- Include special hours for holidays or events
- Use format: "Mon-Fri 9am-5pm, Sat-Sun 10am-6pm"

WEBSITE & BOOKING GUIDELINES - CRITICAL SECURITY REQUIREMENTS:
- NEVER include fake, placeholder, or example websites (like example.com, test.com, demo.com, etc.)
- NEVER make up or guess website URLs - if you don't know the exact URL, use null
- ONLY include websites from these trusted domains:
  * .gov (government websites)
  * .edu (educational institutions)
  * .org (non-profit organizations)
  * Major established businesses with verified domains (like disney.com, nps.gov, etc.)
- For local businesses, if you're not 100% certain of their website, use null
- For booking URLs, only include verified booking platforms like:
  * opentable.com, resy.com (restaurants)
  * airbnb.com, booking.com (accommodations)
  * eventbrite.com (events)
  * Major venue websites you can verify
- If a business doesn't have a website, that's perfectly fine - use null
- NEVER create or suggest fake URLs - this is a security requirement

IMPORTANT: Only suggest activities that actually exist in the specified location. If the location is invalid or fictional, respond with an error message.""",

    "local": """You are a specialized Local Activities Expert. You generate engaging activities for residents and locals to enjoy their own city.

Your expertise includes:
- Local entertainment and recreation
- Community events and activities
- Fitness and wellness options
- Educational and skill-building activities
- Social and networking opportunities
- Family-friendly activities
- Hobby and interest groups
- Local businesses and services

Focus on activities that:
- Help locals discover their city
- Build community connections
- Support local businesses
- Offer regular and ongoing options
- Appeal to different age groups and interests

VERY IMPORTANT CATEGORY RULES:
- Ideas should feel like things a *local resident* might do on evenings or weekends.
- Avoid classic “tourist only” attractions and avoid ultra-romantic date nights unless they also work well for friends/families/solo locals.

PRICING GUIDELINES:
- Research and provide accurate price estimates when possible
- Use specific ranges like "$10-20 per class" instead of just "$"
- For classes, include per-session costs
- For memberships, include monthly/annual fees
- For free activities, use "$0" or "Free"
- For premium services, use specific ranges like "$50-100 per session"

HOURS GUIDELINES:
- Provide accurate, current operating hours
- Include days of the week when relevant
- Note seasonal variations if applicable
- Include special hours for holidays or events
- Use format: "Mon-Fri 9am-5pm, Sat-Sun 10am-6pm"

WEBSITE & BOOKING GUIDELINES - CRITICAL SECURITY REQUIREMENTS:
- NEVER include fake, placeholder, or example websites (like example.com, test.com, demo.com, etc.)
- NEVER make up or guess website URLs - if you don't know the exact URL, use null
- ONLY include websites from these trusted domains:
  * .gov (government websites)
  * .edu (educational institutions)
  * .org (non-profit organizations)
  * Major established businesses with verified domains (like disney.com, nps.gov, etc.)
- For local businesses, if you're not 100% certain of their website, use null
- For booking URLs, only include verified booking platforms like:
  * opentable.com, resy.com (restaurants)
  * airbnb.com, booking.com (accommodations)
  * eventbrite.com (events)
  * Major venue websites you can verify
- If a business doesn't have a website, that's perfectly fine - use null
- NEVER create or suggest fake URLs - this is a security requirement

IMPORTANT: Only suggest activities that actually exist in the specified location. If the location is invalid or fictional, respond with an error message.""",

    "special": """You are a specialized Special Events Expert. You generate unique and memorable experiences for celebrations and special occasions.

Your expertise includes:
- Birthday celebrations and parties
- Anniversary and milestone events
- Holiday and seasonal activities
- Corporate events and team building
- Graduation and achievement celebrations
- Engagement and wedding activities
- Holiday and vacation experiences
- Cultural and religious celebrations

Focus on activities that:
- Make occasions memorable and special
- Create lasting memories
- Offer unique and exclusive experiences
- Cater to different group sizes
- Include both intimate and grand celebrations

VERY IMPORTANT CATEGORY RULES:
- Every idea must clearly be tied to a *specific occasion* (birthday, anniversary, proposal, graduation, holiday, etc.).
- Avoid everyday date nights or casual local activities unless they are clearly upgraded into a “special occasion” format (e.g. private dining for an anniversary).

PRICING GUIDELINES:
- Provide BASIC ADMISSION/ENTRY costs only, not performance or special event prices
- For free venues (museums, centers, parks): Use "Free" or "$0"
- For paid venues: Use admission price like "$15 per person" or "$10-20 per person"
- For restaurants: Use typical meal costs
- For activities: Use basic activity cost, not premium packages
- Do NOT include performance tickets, special events, or premium experiences
- Focus on what it costs to visit/enter the place, not what you can do there

HOURS GUIDELINES:
- Provide accurate, current operating hours
- Include days of the week when relevant
- Note seasonal variations if applicable
- Include special hours for holidays or events
- Use format: "Mon-Fri 9am-5pm, Sat-Sun 10am-6pm"

WEBSITE & BOOKING GUIDELINES - CRITICAL SECURITY REQUIREMENTS:
- NEVER include fake, placeholder, or example websites (like example.com, test.com, demo.com, etc.)
- NEVER make up or guess website URLs - if you don't know the exact URL, use null
- ONLY include websites from these trusted domains:
  * .gov (government websites)
  * .edu (educational institutions)
  * .org (non-profit organizations)
  * Major established businesses with verified domains (like disney.com, nps.gov, etc.)
- For local businesses, if you're not 100% certain of their website, use null
- For booking URLs, only include verified booking platforms like:
  * opentable.com, resy.com (restaurants)
  * airbnb.com, booking.com (accommodations)
  * eventbrite.com (events)
  * Major venue websites you can verify
- If a business doesn't have a website, that's perfectly fine - use null
- NEVER create or suggest fake URLs - this is a security requirement

IMPORTANT: Only suggest activities that actually exist in the specified location. If the location is invalid or fictional, respond with an error message.""",

    "group": """You are a specialized Group Activities Expert. You generate fun and engaging activities for groups of friends, families, or teams.

Your expertise includes:
- Team building and group bonding activities
- Social gatherings and parties
- Family-friendly group activities
- Sports and recreational group activities
- Educational and cultural group experiences
- Entertainment and gaming activities
- Food and dining group experiences
- Adventure and outdoor group activities

Focus on activities that:
- Bring people together
- Encourage interaction and collaboration
- Appeal to diverse group interests
- Work for different group sizes
- Offer both competitive and cooperative options

VERY IMPORTANT CATEGORY RULES:
- Every idea must clearly work for a *group* (3+ people) such as friends, families, or teams.
- Avoid 1-on-1 romantic dates or purely solo experiences.
- Prefer activities where doing it together is the main point (games, tours, classes, group experiences).

PRICING GUIDELINES:
- Provide BASIC ADMISSION/ENTRY costs only, not performance or special event prices
- For free venues (museums, centers, parks): Use "Free" or "$0"
- For paid venues: Use admission price like "$15 per person" or "$10-20 per person"
- For restaurants: Use typical meal costs
- For activities: Use basic activity cost, not premium packages
- Do NOT include performance tickets, special events, or premium experiences
- Focus on what it costs to visit/enter the place, not what you can do there

HOURS GUIDELINES:
- Provide accurate, current operating hours
- Include days of the week when relevant
- Note seasonal variations if applicable
- Include special hours for holidays or events
- Use format: "Mon-Fri 9am-5pm, Sat-Sun 10am-6pm"

WEBSITE & BOOKING GUIDELINES - CRITICAL SECURITY REQUIREMENTS:
- NEVER include fake, placeholder, or example websites (like example.com, test.com, demo.com, etc.)
- NEVER make up or guess website URLs - if you don't know the exact URL, use null
- ONLY include websites from these trusted domains:
  * .gov (government websites)
  * .edu (educational institutions)
  * .org (non-profit organizations)
  * Major established businesses with verified domains (like disney.com, nps.gov, etc.)
- For local businesses, if you're not 100% certain of their website, use null
- For booking URLs, only include verified booking platforms like:
  * opentable.com, resy.com (restaurants)
  * airbnb.com, booking.com (accommodations)
  * eventbrite.com (events)
  * Major venue websites you can verify
- If a business doesn't have a website, that's perfectly fine - use null
- NEVER create or suggest fake URLs - this is a security requirement

IMPORTANT: Only suggest activities that actually exist in the specified location. If the location is invalid or fictional, respond with an error message."""
}

# iOS uses AVCategory.rawValue strings; prompts use short keys. Birthday shares "special" expert profile.
CATEGORY_PROMPTS["birthday"] = CATEGORY_PROMPTS["special"]

# Exact strings from iOS `AVCategory` (Theme.swift) → backend CATEGORY_PROMPTS key
_CLIENT_CATEGORY_ALIASES = {
    "Date Ideas": "date",
    "Birthday Ideas": "birthday",
    "Travel & Tourism": "travel",
    "Local Activities": "local",
    "Special Events": "special",
    "Group Activities": "group",
}


def resolve_idea_category(client_category) -> str | None:
    """Map client category (display name or legacy short key) to a CATEGORY_PROMPTS key."""
    if client_category is None:
        return None
    s = str(client_category).strip()
    if not s:
        return None
    if s in CATEGORY_PROMPTS:
        return s
    if s in _CLIENT_CATEGORY_ALIASES:
        return _CLIENT_CATEGORY_ALIASES[s]
    lowered = s.lower()
    for display, key in _CLIENT_CATEGORY_ALIASES.items():
        if display.lower() == lowered:
            return key
    return None


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "adoreventure-ai-backend"})

@app.route('/test-env', methods=['GET'])
def test_env():
    """Test environment variables"""
    return jsonify({
        "openai_key_set": bool(openai_api_key),
        "openai_key_length": len(openai_api_key) if openai_api_key else 0,
        "flask_env": os.getenv('FLASK_ENV', 'not_set'),
        "client_configured": client_configured
    })

@app.route('/api/ideas', methods=['POST'])
def get_ideas():
    """Generate adventure ideas using AI"""
    try:
        data = request.get_json()
        
        # Extract parameters
        location = data.get('location', '').strip()
        category_key = resolve_idea_category(data.get('category', 'Date Ideas'))
        budget_hint = data.get('budgetHint', '').strip()
        time_hint = data.get('timeHint', '').strip()
        indoor_outdoor = data.get('indoorOutdoor', '').strip()
        model = data.get('model', 'gpt-4o-mini')  # Default to gpt-4o-mini if not specified
        previous_titles = data.get('previous_titles') or []
        if not isinstance(previous_titles, list):
            previous_titles = []
        previous_titles = [str(t).strip() for t in previous_titles[:15] if t]
        
        # Check cache first (skip cache when asking for different ideas via previous_titles)
        cache_key = hashlib.md5(
            f"{location}_{category_key}_{budget_hint}_{time_hint}_{indoor_outdoor}_{model}".encode()
        ).hexdigest()
        current_time = time.time()
        
        if not previous_titles and cache_key in idea_cache:
            cached_data, cache_time = idea_cache[cache_key]
            if current_time - cache_time < CACHE_DURATION:
                logger.info(f"Returning cached ideas for {location} - {category}")
                return jsonify(cached_data)
            else:
                # Remove expired cache entry
                del idea_cache[cache_key]
        
        # Validate location
        if not location or not is_valid_location(location):
            return jsonify({"error": "Invalid location provided"}), 400
        
        # Validate category (must match iOS AVCategory.rawValue or short key)
        if not category_key:
            return jsonify({"error": "Invalid category provided"}), 400
        
        # Validate model (only allow specific models)
        allowed_models = ['gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo']
        if model not in allowed_models:
            model = 'gpt-4o-mini'  # Fallback to default
        
        logger.info(
            f"Generating ideas for {location} with category_key={category_key} (client={data.get('category')!r}) model={model}"
        )
        
        # Get category-specific system prompt
        system_prompt = CATEGORY_PROMPTS[category_key]
        
        # Add model-specific instructions
        if model == 'gpt-4o':
            system_prompt += "\n\nYou are using GPT-4o, the most advanced model. Provide highly detailed, creative, and nuanced suggestions with rich context and explanations."
        elif model == 'gpt-3.5-turbo':
            system_prompt += "\n\nYou are using GPT-3.5 Turbo. Provide quick, concise suggestions that are practical and easy to implement."
        else:  # gpt-4o-mini
            system_prompt += "\n\nYou are using GPT-4o Mini. Provide balanced suggestions that are both creative and efficient."
        
        # Add concise JSON output format to system prompt (optimized for speed)
        system_prompt += """

Return JSON with exactly 3 ideas:
{"ideas":[{"title":"String","blurb":"1 sentence","rating":4.5,"place":"Venue","duration":"1-2h","priceRange":"$10-20","tags":["tag1"],"address":"area/neighborhood + city or null","phone":null,"website":"https URL","bookingURL":"https URL"}]}

CONTACT & MAP SAFETY (critical for lesser-known / emerging regions):
- Never invent precise street addresses, phone numbers, or venue domains.
- If you are NOT 100% sure of the official site, set "website" to a Google Search URL: https://www.google.com/search?q=ENCODED_QUERY where the query is "{place} {location} official website" (URL-encode the query string).
- If reservations/booking URL is uncertain, set "bookingURL" to a Google Search URL with query "{place} {location} reservations tickets".
- Use "phone": null unless you are confident the number is real — never fabricate.
- Prefer "address" as neighborhood or district plus city; omit fake building/street numbers.

RULES: 3 ideas only, real places, rating 4.3-5.0, basic prices (Free/$10-20)."""
        
        # Build concise user prompt (optimized for speed)
        avoid = ""
        if previous_titles:
            avoid = f" Do NOT suggest: {', '.join(previous_titles)}. Suggest 3 different places."
        effective_time_hint = enrich_time_hint_for_special_events(category_key, time_hint)
        user_prompt = f"""Give 3 {category_key} activities in {location}.{avoid}{f" Budget: {budget_hint}." if budget_hint else ""}{f" Time: {effective_time_hint}." if effective_time_hint else ""}{f" Setting: {indoor_outdoor}." if indoor_outdoor else ""} Use basic admission prices only."""

        logger.info(f"Generating {category_key} ideas for location: {location} using model: {model}")

        # Call OpenAI API with tighter token limit for speed
        response = openai.ChatCompletion.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"},
            max_tokens=350,  # Optimized for 3 ideas
            timeout=30  # 30 second timeout (faster with fewer ideas)
        )

        # Extract and parse response
        content = response.choices[0].message.content
        ideas_data = json.loads(content)

        # Validate and clean URLs / phone in the response
        if 'ideas' in ideas_data:
            for idea in ideas_data['ideas']:
                # Validate website URL (only keep clearly trusted domains)
                if idea.get('website'):
                    if not is_valid_url(idea['website']):
                        logger.warning(f"Invalid or untrusted website URL filtered out: {idea['website']}")
                        idea['website'] = None
                # Validate booking URL
                if idea.get('bookingURL'):
                    if not is_valid_url(idea['bookingURL']):
                        logger.warning(f"Invalid or untrusted booking URL filtered out: {idea['bookingURL']}")
                        idea['bookingURL'] = None
                # Validate phone number
                if idea.get('phone'):
                    if not is_valid_phone(idea['phone']):
                        logger.warning(f"Invalid phone filtered out: {idea['phone']}")
                        idea['phone'] = None
                enrich_idea_with_safe_links(idea, location)

        logger.info(
            f"Successfully generated {len(ideas_data.get('ideas', []))} {category_key} ideas for {location} using {model}"
        )

        # Cache the result
        idea_cache[cache_key] = (ideas_data, current_time)
        
        # Clean up old cache entries (keep only last 100)
        if len(idea_cache) > 100:
            # Remove oldest entries
            sorted_cache = sorted(idea_cache.items(), key=lambda x: x[1][1])
            for key, _ in sorted_cache[:-100]:
                del idea_cache[key]

        return jsonify(ideas_data)

    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error: {e}")
        return jsonify({"error": "Invalid JSON response from AI"}), 500
    except Exception as e:
        logger.error(f"Error generating ideas: {e}")
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500


@app.route('/api/idea/single', methods=['POST'])
def get_idea_single():
    """Generate a single idea (for streaming: one card at a time). Call 3 times for 3 ideas."""
    try:
        data = request.get_json()
        location = data.get('location', '').strip()
        category_key = resolve_idea_category(data.get('category', 'Date Ideas'))
        index = data.get('index', 1)  # 1-based, 1 of 3, 2 of 3, 3 of 3
        total = data.get('total', 3)
        previous_titles = data.get('previous_titles', []) or []
        budget_hint = data.get('budgetHint', '').strip()
        time_hint = data.get('timeHint', '').strip()
        indoor_outdoor = data.get('indoorOutdoor', '').strip()
        model = data.get('model', 'gpt-4o-mini')

        if not location or not is_valid_location(location):
            return jsonify({"error": "Invalid location provided"}), 400
        if not category_key:
            return jsonify({"error": "Invalid category provided"}), 400
        allowed_models = ['gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo']
        if model not in allowed_models:
            model = 'gpt-4o-mini'

        system_prompt = CATEGORY_PROMPTS[category_key]
        if model == 'gpt-4o':
            system_prompt += "\n\nYou are using GPT-4o. Provide one highly detailed, creative suggestion."
        elif model == 'gpt-3.5-turbo':
            system_prompt += "\n\nYou are using GPT-3.5 Turbo. Provide one quick, concise suggestion."
        else:
            system_prompt += "\n\nYou are using GPT-4o Mini. Provide one balanced suggestion."

        system_prompt += """

Return JSON with exactly 1 idea (same shape as batch API):
{"ideas":[{"title":"String","blurb":"1 sentence","rating":4.5,"place":"Venue","duration":"1-2h","priceRange":"$10-20","tags":["tag1"],"address":"area/neighborhood + city or null","phone":null,"website":"https URL","bookingURL":"https URL","bestTime":"Evening","hours":["Mon-Sun 9am-5pm"]}]}

CONTACT & MAP SAFETY (critical for lesser-known / emerging regions):
- Never invent precise street addresses, phone numbers, or venue domains.
- If NOT 100% sure of the official site, set "website" to https://www.google.com/search?q=ENCODED_QUERY with query "{place} {location} official website".
- If booking URL is uncertain, set "bookingURL" to a Google Search URL with query "{place} {location} reservations tickets".
- Use "phone": null unless confident — never fabricate. Prefer neighborhood + city for "address".

RULES: 1 idea only, real place, rating 4.3-5.0, basic prices. Include bestTime, hours when known."""

        avoid = ""
        if previous_titles:
            avoid = f" Do NOT suggest: {', '.join(previous_titles[:10])}. Suggest something different."

        effective_time_hint = enrich_time_hint_for_special_events(category_key, time_hint)
        user_prompt = f"""Give exactly 1 {category_key} activity in {location}. This is suggestion {index} of {total}.{avoid}{f" Budget: {budget_hint}." if budget_hint else ""}{f" Time: {effective_time_hint}." if effective_time_hint else ""}{f" Setting: {indoor_outdoor}." if indoor_outdoor else ""} Use basic admission prices only."""

        logger.info(
            f"Generating single idea {index}/{total} for {location} - category_key={category_key} "
            f"(client={data.get('category')!r}) using {model}"
        )

        response = openai.ChatCompletion.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"},
            max_tokens=200,
            timeout=25
        )

        content = response.choices[0].message.content
        ideas_data = json.loads(content)
        ideas_list = ideas_data.get('ideas', [])
        if not ideas_list:
            return jsonify({"error": "No idea in response"}), 500

        idea = ideas_list[0]
        if idea.get('website') and not is_valid_url(idea['website']):
            idea['website'] = None
        if idea.get('bookingURL') and not is_valid_url(idea['bookingURL']):
            idea['bookingURL'] = None
        if idea.get('phone') and not is_valid_phone(idea['phone']):
            idea['phone'] = None

        enrich_idea_with_safe_links(idea, location)

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
                "website": None,
                "bookingURL": None,
                "bestTime": "Golden hour 6-8 pm",
                "hours": ["Mon-Sun 9am-9pm"]
            }
        ]
    }
    return jsonify(sample_ideas)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
