import re
import datetime
from django.utils import timezone
import dateparser
import logging

logger = logging.getLogger(__name__)

# To use huggingface transformers without downloading giant models every time,
# we initialize a lightweight pipeline. In a real production deployment, this 
# would be loaded once during app startup or via a Celery worker.
_nlp_pipeline = None

def get_nlp_pipeline():
    global _nlp_pipeline
    if _nlp_pipeline is None:
        try:
            from transformers import pipeline
            # Using a zero-shot classification model to determine if the message contains a deadline
            _nlp_pipeline = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")
        except Exception as e:
            logger.error(f"Failed to load Hugging Face pipeline: {e}")
            _nlp_pipeline = False # Mark as failed to avoid retrying on every call
    return _nlp_pipeline

def extract_deadline(text: str) -> datetime.datetime | None:
    """
    Intelligently extracts a deadline/date from the given text using 
    both an AI NLP model (Hugging Face) and a rule-based parser.
    """
    if not text:
        return None

    # Step 1: Use Hugging Face AI Model to check if the message is even about a deadline
    nlp = get_nlp_pipeline()
    has_deadline = False
    
    if nlp:
        try:
            candidate_labels = ["contains a deadline", "does not contain a deadline"]
            result = nlp(text, candidate_labels)
            if result['labels'][0] == "contains a deadline" and result['scores'][0] > 0.6:
                has_deadline = True
        except Exception as e:
            logger.error(f"NLP extraction error: {e}")
            
    # Step 2: Use Dateparser as a primary fast extraction method for common phrases
    # like "Submit by tomorrow at 5pm", "Due next Friday", etc.
    # We look for trigger words like 'due', 'submit', 'deadline', 'by'
    text_lower = text.lower()
    
    # Simple regex to capture text near "due" or "deadline"
    match = re.search(r'(?:due|deadline|submit by|complete by)\s+(.+?)(?:\.|!|\n|$)', text_lower)
    if match:
        date_string = match.group(1)
        parsed_date = dateparser.parse(date_string, settings={'PREFER_DATES_FROM': 'future'})
        if parsed_date:
            if timezone.is_naive(parsed_date):
                parsed_date = timezone.make_aware(parsed_date)
            # Ensure the deadline is in the future
            if parsed_date > timezone.now():
                return parsed_date

    # If the AI model strongly predicted a deadline but regex failed, try a generic parse
    if has_deadline:
        parsed_date = dateparser.parse(text, settings={'PREFER_DATES_FROM': 'future'})
        if parsed_date and timezone.is_naive(parsed_date):
            parsed_date = timezone.make_aware(parsed_date)
        
        if parsed_date and parsed_date > timezone.now():
            return parsed_date

    return None
