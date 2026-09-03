"""
Campuz In-House Academic AI Engine (ai_service.py)
--------------------------------------------------
Architecture:
- Hybrid Natural Language Processing (NLP) Engine designed specifically for
  campus academic assistance, deadline extraction, text summarization,
  study planning, and student course guidance.
- 100% Self-contained within the backend; no external cloud API dependencies.
- Uses rule-based intent recognition, NLP tokenization, frequency-based
  extractive summarization, and temporal date/time parsing (dateparser).
"""

import re
import math
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
# pyrefly: ignore [missing-import]
from django.utils import timezone

from .deadline_extractor import extract_deadline

logger = logging.getLogger(__name__)

# Stopwords for extractive NLP scoring
STOPWORDS = {
    "a", "about", "above", "after", "again", "against", "all", "am", "an", "and",
    "any", "are", "aren't", "as", "at", "be", "because", "been", "before", "being",
    "below", "between", "both", "but", "by", "can't", "cannot", "could", "couldn't",
    "did", "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during",
    "each", "few", "for", "from", "further", "had", "hadn't", "has", "hasn't",
    "have", "haven't", "having", "he", "he'd", "he'll", "he's", "her", "here",
    "here's", "hers", "herself", "him", "himself", "his", "how", "how's", "i",
    "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's",
    "its", "itself", "let's", "me", "more", "most", "mustn't", "my", "myself",
    "no", "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought",
    "our", "ours", "ourselves", "out", "over", "own", "same", "shan't", "she",
    "she'd", "she'll", "she's", "should", "shouldn't", "so", "some", "such",
    "than", "that", "that's", "the", "their", "theirs", "them", "themselves",
    "then", "there", "there's", "these", "they", "they'd", "they'll", "they're",
    "they've", "this", "those", "through", "to", "too", "under", "until", "up",
    "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were",
    "weren't", "what", "what's", "when", "when's", "where", "where's", "which",
    "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would",
    "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours",
    "yourself", "yourselves", "please", "also", "just"
}


class AcademicAIEngine:
    """
    Core In-House AI Engine for Campuz.
    Handles intent detection, extractive summarization, deadline parsing,
    study timetable generation, and academic Q&A.
    """

    @classmethod
    def generate_response(
        cls,
        user_message: str,
        user=None,
        conversation_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        Main entry point for generating an AI response.
        Returns a dictionary with 'reply', 'intent', and optional 'metadata'.
        """
        raw_text = (user_message or "").strip()
        if not raw_text:
            return {
                "reply": "Please type a message or question, and I'll be happy to help!",
                "intent": "EMPTY",
                "metadata": {}
            }

        student_name = cls._get_student_name(user)
        intent = cls._classify_intent(raw_text)

        if intent == "GREETING":
            reply = cls._handle_greeting(student_name)
            metadata = {}
        elif intent == "EXTRACT_DEADLINE":
            reply, metadata = cls._handle_deadline_extraction(raw_text)
        elif intent == "SUMMARIZE":
            reply, metadata = cls._handle_summarization(raw_text)
        elif intent == "STUDY_PLAN":
            reply, metadata = cls._handle_study_plan(raw_text, student_name)
        elif intent == "EXAM_PREP":
            reply, metadata = cls._handle_exam_prep(raw_text)
        elif intent == "ASSIGNMENT_HELP":
            reply, metadata = cls._handle_assignment_help(raw_text)
        elif intent == "HUB_HELP":
            reply, metadata = cls._handle_hub_help(raw_text)
        elif intent == "THANK_YOU":
            reply = cls._handle_thank_you(student_name)
            metadata = {}
        else:
            reply, metadata = cls._handle_general_academic_qa(
                raw_text, student_name)

        return {
            "reply": reply,
            "intent": intent,
            "metadata": metadata
        }

    # -------------------------------------------------------------------------
    # Intent Classification
    # -------------------------------------------------------------------------

    @classmethod
    def _classify_intent(cls, text: str) -> str:
        low = text.lower()

        # 1. Greetings
        if re.match(r"^(hi|hello|hey|good\s+(morning|afternoon|evening)|yo|greetings)\b", low):
            if len(low.split()) <= 4:
                return "GREETING"

        # 2. Thank you
        if re.search(r"\b(thank\s+you|thanks|appreciate\s+it|thx)\b", low) and len(low.split()) <= 5:
            return "THANK_YOU"

        # 3. Deadline Extraction
        if re.search(r"\b(deadline|due date|due on|submit by|submission date|when is .* due|extract deadline|find deadline)\b", low):
            return "EXTRACT_DEADLINE"

        # 4. Summarization
        if re.search(r"\b(summarize|summarise|summary|break down|tldr|key points|overview of)\b", low):
            return "SUMMARIZE"

        # 5. Study Plan & Schedule
        if re.search(r"\b(study plan|study schedule|revision schedule|timetable|revision timetable|pomodoro|how should i study|routine)\b", low):
            return "STUDY_PLAN"

        # 6. Exam Preparation
        if re.search(r"\b(exam|finals|midterm|test prep|quiz prep|flashcard|study tips|how to pass)\b", low):
            return "EXAM_PREP"

        # 7. Assignment Guidance
        if re.search(r"\b(assignment|project|essay|lab report|thesis|citations|apa|mla|referencing|outline)\b", low):
            return "ASSIGNMENT_HELP"

        # 8. Hub and Collaboration Help
        if re.search(r"\b(hub|broadcast|section|channel|group chat|class group|announcement)\b", low):
            return "HUB_HELP"

        # Check if text looks like an announcement with dates
        if extract_deadline(text) is not None:
            return "EXTRACT_DEADLINE"

        return "GENERAL_ACADEMIC_QA"

    # -------------------------------------------------------------------------
    # Handlers
    # -------------------------------------------------------------------------

    @classmethod
    def _get_student_name(cls, user) -> str:
        if not user or not hasattr(user, "profile"):
            return "Student"
        profile = getattr(user, "profile", None)
        if profile:
            if getattr(profile, "display_name", None):
                return profile.display_name.strip()
            if getattr(profile, "full_name", None):
                return profile.full_name.strip()
        return user.first_name.strip() or user.username or "Student"

    @classmethod
    def _handle_greeting(cls, student_name: str) -> str:
        return (
            f"Hello **{student_name}**! 👋 I am your **Campuz AI Academic Assistant**.\n\n"
            "Here are a few things I can help you with today:\n"
            "• **📅 Extract Deadlines**: Paste class announcements to extract due dates.\n"
            "• **📝 Summarize Notes**: Paste long readings or messages to get bullet points.\n"
            "• **⏰ Create Study Plans**: Ask for a revision schedule or study timetable.\n"
            "• **💡 Exam Prep & Advice**: Get study techniques, assignment outlines, and tips.\n\n"
            "What would you like to work on?"
        )

    @classmethod
    def _handle_thank_you(cls, student_name: str) -> str:
        return (
            f"You're very welcome, **{student_name}**! 🎓\n\n"
            "Feel free to paste another announcement, lecture text, or ask any study questions whenever you need."
        )

    @classmethod
    def _handle_deadline_extraction(cls, text: str) -> tuple[str, Dict[str, Any]]:
        # Remove trigger phrases to parse the core announcement if present
        clean_text = re.sub(
            r"^(extract deadline[s]? from:?|find deadline[s]? in:?|when is this due\??)", "", text, flags=re.IGNORECASE).strip()
        target_text = clean_text if clean_text else text

        extracted_dt = extract_deadline(target_text)

        # Look for course code (e.g. CS101, MATH 201, COE 352, SENG 404)
        course_match = re.search(
            r"\b([A-Z]{2,4}\s?[0-9]{3}[A-Z]?)\b", target_text, flags=re.IGNORECASE)
        course_name = course_match.group(
            1).upper() if course_match else "Course Work"

        # Look for assignment keyword
        task_match = re.search(
            r"\b(assignment\s?[0-9]*|project\s?[0-9]*|lab\s?[0-9]*|quiz\s?[0-9]*|midterm|report|presentation|essay)\b", target_text, flags=re.IGNORECASE)
        task_title = task_match.group(1).capitalize(
        ) if task_match else "Upcoming Submission"

        if extracted_dt:
            formatted_date = extracted_dt.strftime("%A, %B %d, %Y at %I:%M %p")
            time_left = extracted_dt - timezone.now()
            days_left = max(0, time_left.days)
            hours_left = max(0, int(time_left.seconds // 3600))

            countdown_str = f"{days_left} days, {hours_left} hours left" if days_left > 0 else f"{hours_left} hours left"

            reply = (
                f"### 📅 Extracted Deadline Details\n\n"
                f"• **Task**: {task_title} ({course_name})\n"
                f"• **Due Date**: **{formatted_date}**\n"
                f"• **Time Remaining**: ⏳ {countdown_str}\n\n"
                f"**Suggested Next Steps:**\n"
                f"1. Add this deadline to your **Tasks** tab.\n"
                f"2. Break down the submission into smaller milestones.\n"
                f"3. Set a reminder 24 hours in advance to review your final draft."
            )
            return reply, {
                "deadline_found": True,
                "deadline_iso": extracted_dt.isoformat(),
                "formatted_date": formatted_date,
                "task_title": task_title,
                "course_name": course_name
            }
        else:
            reply = (
                "### 📅 Deadline Extraction\n\n"
                "I analyzed your text, but could not detect a specific future due date.\n\n"
                "💡 **Tip**: Paste the full announcement with the date/time (e.g., *'Submit Lab 2 by Friday 5:00 PM'* or *'Due on 15th October'*), and I will extract the schedule for you!"
            )
            return reply, {"deadline_found": False}

    @classmethod
    def _handle_summarization(cls, text: str) -> tuple[str, Dict[str, Any]]:
        clean_text = re.sub(r"^(summarize|summarise|summary of|break down|give me a summary of):?\s*",
                            "", text, flags=re.IGNORECASE).strip()
        target_text = clean_text if clean_text else text

        if len(target_text.split()) < 15:
            reply = (
                "### 📝 Text Summarization\n\n"
                "The text you provided is very brief. Please paste a longer lecture note, syllabus section, or class announcement (at least 2-3 sentences), and I will extract the key takeaways, main points, and action items for you!"
            )
            return reply, {"summary_generated": False}

        summary_bullets = cls._extractive_summary(target_text, top_n=3)

        # Extract potential action items (sentences containing submit, read, attend, bring, prepare, review)
        sentences = cls._split_into_sentences(target_text)
        action_items = []
        for s in sentences:
            if re.search(r"\b(submit|read|attend|bring|prepare|review|complete|download|register)\b", s, flags=re.IGNORECASE):
                cleaned_action = s.strip()
                if len(cleaned_action) > 10 and cleaned_action not in action_items:
                    action_items.append(cleaned_action)

        reply_parts = [
            "### 📝 Summary & Key Takeaways\n",
            "\n".join([f"• {bullet}" for bullet in summary_bullets]),
        ]

        if action_items:
            reply_parts.append("\n**⚡ Action Items Identified:**")
            reply_parts.extend([f"1. {item}" for item in action_items[:3]])

        reply_parts.append(
            "\n*Generated using In-House Extractive NLP Engine.*")

        return "\n".join(reply_parts), {
            "summary_generated": True,
            "bullets": summary_bullets,
            "action_items": action_items[:3]
        }

    @classmethod
    def _handle_study_plan(cls, text: str, student_name: str) -> tuple[str, Dict[str, Any]]:
        # Look for subject / topic mentioned
        match = re.search(
            r"\b(?:for|on|in|studying)\s+([a-zA-Z0-9\s]+?)(?:\.|\?|$)", text, flags=re.IGNORECASE)
        subject = match.group(1).strip().title(
        ) if match else "Your Coursework"

        reply = (
            f"### ⏰ Personalized Study & Revision Schedule\n\n"
            f"Here is a proven 4-Step **Pomodoro & Spaced Repetition Plan** for **{subject}**:\n\n"
            f"**Phase 1: Concept Review (Session 1 — 45 mins)**\n"
            f"• Review lecture slides, notes, and core definitions.\n"
            f"• Highlight difficult formulas, concepts, or terms.\n"
            f"• *Break*: 10 minutes.\n\n"
            f"**Phase 2: Active Recall & Practice (Session 2 — 45 mins)**\n"
            f"• Attempt 3–5 past questions or tutorial exercises without checking answers.\n"
            f"• Test yourself on key formulas.\n"
            f"• *Break*: 10 minutes.\n\n"
            f"**Phase 3: Error Analysis & Gap Filling (Session 3 — 30 mins)**\n"
            f"• Review mistakes and re-read difficult sections.\n"
            f"• Create flashcards for frequently forgotten terms.\n\n"
            f"**Phase 4: Summary & Consolidation (15 mins)**\n"
            f"• Summarize the day's study session in 3 bullet points.\n\n"
            f"💡 **Pro-Tip for {student_name}**: Study during your peak alertness hours and stay hydrated!"
        )
        return reply, {"plan_type": "pomodoro_spaced_repetition", "subject": subject}

    @classmethod
    def _handle_exam_prep(cls, text: str) -> tuple[str, Dict[str, Any]]:
        reply = (
            "### 🎓 High-Impact Exam Preparation Strategies\n\n"
            "To maximize retention and performance before your exams, apply these 4 proven academic techniques:\n\n"
            "1. **Feynman Technique (Teach to Learn)**:\n"
            "   Explain key concepts out loud in simple terms as if teaching a classmate. If you get stuck, re-check your notes.\n\n"
            "2. **Past Exam Papers Under Timed Conditions**:\n"
            "   Simulate real exam pressure by solving past questions within the allotted time without notes.\n\n"
            "3. **Spaced Retrieval**:\n"
            "   Review challenging topics after 1 day, 3 days, and 7 days to transfer knowledge into long-term memory.\n\n"
            "4. **Formula & Keyword Cheat Sheets**:\n"
            "   Condense each chapter onto a single index card for quick memory jogs on exam morning."
        )
        return reply, {"category": "exam_prep"}

    @classmethod
    def _handle_assignment_help(cls, text: str) -> tuple[str, Dict[str, Any]]:
        reply = (
            "### 📚 Assignment & Project Roadmap\n\n"
            "Follow this structured framework to complete your academic submissions on time:\n\n"
            "• **Step 1: Understand the Rubric**: Identify specific grading criteria, word counts, and formatting requirements (APA/IEEE/Harvard).\n"
            "• **Step 2: Outline Key Headings**: Create an outline covering *Introduction*, *Methodology/Analysis*, *Findings/Discussion*, and *Conclusion*.\n"
            "• **Step 3: Draft First, Edit Later**: Write without stopping to polish grammar so ideas flow freely.\n"
            "• **Step 4: Citation & Plagiarism Check**: Ensure all sources and data are properly cited before submission.\n"
            "• **Step 5: Final Proofread**: Read your paper out loud 24 hours before the deadline to catch awkward phrasing."
        )
        return reply, {"category": "assignment_guidance"}

    @classmethod
    def _handle_hub_help(cls, text: str) -> tuple[str, Dict[str, Any]]:
        reply = (
            "### 👥 Campuz Hub Collaboration Features\n\n"
            "You can manage and collaborate within your Hubs with these features:\n\n"
            "• **Sections**: Organize course materials into dedicated discussion and topic channels.\n"
            "• **Broadcasts & SMS**: Hub admins can send critical announcements that reach members via In-App notifications and SMS.\n"
            "• **Shared Resources**: Upload lecture PDFs, past questions, and slides for everyone in the hub.\n"
            "• **Group Meetings**: Schedule virtual or physical study sessions with automated reminders."
        )
        return reply, {"category": "hub_collaboration"}

    @classmethod
    def _handle_general_academic_qa(cls, text: str, student_name: str) -> tuple[str, Dict[str, Any]]:
        reply = (
            f"Hello **{student_name}**! I am your Campuz AI Academic Assistant.\n\n"
            f"Regarding your query: *\"{text[:80]}{'...' if len(text) > 80 else ''}\"*\n\n"
            "Here is how I can best assist you:\n"
            "• **📅 Extract Deadlines**: Paste any class announcement, and I will extract due dates and countdowns.\n"
            "• **📝 Summarize Material**: Paste lecture notes or long text to generate a quick summary and action items.\n"
            "• **⏰ Study Timetables**: Ask me to build a study plan for any subject or exam.\n"
            "• **📋 Tasks & Courses**: Organize your coursework and hub collaborations efficiently.\n\n"
            "Try pasting a message or ask: *\"Create a study plan for Computer Networks\"* or *\"Summarize this announcement...\"*!"
        )
        return reply, {"category": "general_qa"}

    # -------------------------------------------------------------------------
    # Extractive NLP Summarization Logic
    # -------------------------------------------------------------------------

    @classmethod
    def _split_into_sentences(cls, text: str) -> List[str]:
        # Split on ., !, ? followed by space or newline
        raw = re.split(r"(?<=[.!?])\s+", text.strip())
        sentences = [s.strip() for s in raw if len(s.strip()) > 8]
        return sentences if sentences else [text.strip()]

    @classmethod
    def _tokenize_words(cls, text: str) -> List[str]:
        words = re.findall(r"\b[a-zA-Z]{2,}\b", text.lower())
        return [w for w in words if w not in STOPWORDS]

    @classmethod
    def _extractive_summary(cls, text: str, top_n: int = 3) -> List[str]:
        sentences = cls._split_into_sentences(text)
        if len(sentences) <= top_n:
            return sentences

        # Compute word frequencies
        word_freq: Dict[str, int] = {}
        for s in sentences:
            tokens = cls._tokenize_words(s)
            for t in tokens:
                word_freq[t] = word_freq.get(t, 0) + 1

        if not word_freq:
            return sentences[:top_n]

        max_freq = max(word_freq.values())
        normalized_freq = {w: count / max_freq for w,
                           count in word_freq.items()}

        # Score sentences based on normalized word frequencies and position
        scored_sentences: List[tuple[float, int, str]] = []
        total_s = len(sentences)

        for idx, sentence in enumerate(sentences):
            tokens = cls._tokenize_words(sentence)
            if not tokens:
                continue
            # Base word score
            score = sum(normalized_freq.get(t, 0.0)
                        for t in tokens) / math.sqrt(len(tokens))

            # Positional bias: First and last sentences often carry core announcements/deadlines
            if idx == 0:
                score *= 1.3
            elif idx == total_s - 1:
                score *= 1.15

            # Keyword bonus for academic triggers
            if re.search(r"\b(important|note|due|submit|required|exam|assignment|deadline|lecture)\b", sentence, re.IGNORECASE):
                score *= 1.25

            scored_sentences.append((score, idx, sentence))

        if not scored_sentences:
            return sentences[:top_n]

        # Pick top N sentences by score
        scored_sentences.sort(key=lambda x: x[0], reverse=True)
        top_selected = scored_sentences[:top_n]

        # Re-sort chronologically by original sentence index
        top_selected.sort(key=lambda x: x[1])

        return [item[2] for item in top_selected]
