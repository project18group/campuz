import re
import datetime
from django.utils import timezone
try:
    import dateparser
except ImportError:
    dateparser = None
import logging

logger = logging.getLogger(__name__)

def extract_deadline(text: str) -> datetime.datetime | None:
    """
    Intelligently extracts a deadline/date from the given text using 
    a fast rule-based parser.
    """
    if not text or not dateparser:
        return None
        
    text_lower = text.lower()
    
    # Step 1: Look for explicit trigger words like 'due', 'submit', 'deadline', 'by'
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

    # Step 2: Fallback generic parse if it contains date-like words
    # Only run full parse if there are likely date words to save CPU
    if any(word in text_lower for word in ['tomorrow', 'next', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'at', 'pm', 'am', '/', '-']):
        parsed_date = dateparser.parse(text, settings={'PREFER_DATES_FROM': 'future'})
        if parsed_date and timezone.is_naive(parsed_date):
            parsed_date = timezone.make_aware(parsed_date)
        
        if parsed_date and parsed_date > timezone.now():
            return parsed_date

    return None
