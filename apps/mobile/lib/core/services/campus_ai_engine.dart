import 'dart:math';

/// In-App Intelligent Academic AI Engine for Campuz.
/// Provides offline-first deadline extraction, text summarization,
/// study schedule generation, exam preparation techniques, and academic Q&A.
class CampusAiEngine {
  static const Set<String> _stopwords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
    'and', 'any', 'are', 'aren\'t', 'as', 'at', 'be', 'because', 'been',
    'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can\'t',
    'cannot', 'could', 'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t',
    'doing', 'don\'t', 'down', 'during', 'each', 'few', 'for', 'from',
    'further', 'had', 'hadn\'t', 'has', 'hasn\'t', 'have', 'haven\'t',
    'having', 'he', 'he\'d', 'he\'ll', 'he\'s', 'her', 'here', 'here\'s',
    'hers', 'herself', 'him', 'himself', 'his', 'how', 'how\'s', 'i', 'i\'d',
    'i\'ll', 'i\'m', 'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it', 'it\'s',
    'its', 'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t', 'my', 'myself',
    'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other',
    'ought', 'our', 'ours', 'ourselves', 'out', 'over', 'own', 'same',
    'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should', 'shouldn\'t',
    'so', 'some', 'such', 'than', 'that', 'that\'s', 'the', 'their', 'theirs',
    'them', 'themselves', 'then', 'there', 'there\'s', 'these', 'they',
    'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we',
    'we\'d', 'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what',
    'what\'s', 'when', 'when\'s', 'where', 'where\'s', 'which', 'while',
    'who', 'who\'s', 'whom', 'why', 'why\'s', 'with', 'won\'t', 'would',
    'wouldn\'t', 'you', 'you\'d', 'you\'ll', 'you\'re', 'you\'ve', 'your',
    'yours', 'yourself', 'yourselves', 'please', 'also', 'just', 'will',
  };

  static Map<String, dynamic> generateResponse({
    required String userMessage,
    String studentName = 'Student',
  }) {
    final raw = userMessage.trim();
    if (raw.isEmpty) {
      return {
        'reply': "Please ask a question or paste an academic announcement, and I'll assist you!",
        'intent': 'EMPTY',
        'metadata': <String, dynamic>{},
      };
    }

    final lower = raw.toLowerCase();

    // 1. Greetings
    if (RegExp(r'^(hi|hello|hey|good\s+(morning|afternoon|evening)|yo|greetings)\b', caseSensitive: false).hasMatch(lower) &&
        lower.split(RegExp(r'\s+')).length <= 4) {
      return {
        'reply': _handleGreeting(studentName),
        'intent': 'GREETING',
        'metadata': <String, dynamic>{},
      };
    }

    // 2. Thank you
    if (RegExp(r'\b(thank\s+you|thanks|appreciate\s+it|thx)\b', caseSensitive: false).hasMatch(lower) &&
        lower.split(RegExp(r'\s+')).length <= 5) {
      return {
        'reply': "You're very welcome, **$studentName**! 🎓\n\nFeel free to paste another lecture excerpt, announcement, or ask any coursework questions whenever you need.",
        'intent': 'THANK_YOU',
        'metadata': <String, dynamic>{},
      };
    }

    // 3. Deadline Extraction
    if (RegExp(r'\b(deadline|due date|due on|submit by|submission date|when is .* due|extract deadline|find deadline)\b', caseSensitive: false).hasMatch(lower) ||
        _detectDateInText(raw) != null) {
      return _handleDeadlineExtraction(raw);
    }

    // 4. Summarization
    if (RegExp(r'\b(summarize|summarise|summary|break down|tldr|key points|overview of)\b', caseSensitive: false).hasMatch(lower)) {
      return _handleSummarization(raw);
    }

    // 5. Study Plan
    if (RegExp(r'\b(study plan|study schedule|revision schedule|timetable|revision timetable|pomodoro|how should i study|routine)\b', caseSensitive: false).hasMatch(lower)) {
      return _handleStudyPlan(raw, studentName);
    }

    // 6. Exam Prep
    if (RegExp(r'\b(exam|finals|midterm|test prep|quiz prep|flashcard|study tips|how to pass)\b', caseSensitive: false).hasMatch(lower)) {
      return _handleExamPrep(raw);
    }

    // 7. Assignment Guidance
    if (RegExp(r'\b(assignment|project|essay|lab report|thesis|citations|apa|mla|referencing|outline)\b', caseSensitive: false).hasMatch(lower)) {
      return _handleAssignmentHelp(raw);
    }

    // 8. Hub Collaboration
    if (RegExp(r'\b(hub|broadcast|section|channel|group chat|class group|sms topup)\b', caseSensitive: false).hasMatch(lower)) {
      return _handleHubHelp(raw);
    }

    // 9. General Academic Q&A
    return _handleGeneralAcademicQa(raw, studentName);
  }

  static String _handleGreeting(String studentName) {
    return "Hello **$studentName**! 👋 I am your **Campuz AI Academic Assistant**.\n\n"
        "Here are high-impact things I can help you with today:\n"
        "• **📅 Extract Deadlines**: Paste class announcements to extract due dates, countdowns, and reminders.\n"
        "• **📝 Summarize Notes**: Paste long readings, PDFs, or messages to get bullet points and action items.\n"
        "• **⏰ Create Study Plans**: Ask for a personalized revision timetable based on the Pomodoro technique.\n"
        "• **💡 Exam Strategies & Prep**: Get active recall techniques, past question strategies, and tips.\n\n"
        "What would you like to work on?";
  }

  static Map<String, dynamic> _handleDeadlineExtraction(String text) {
    final cleanText = text
        .replaceAll(RegExp(r'^(extract deadline[s]? from:?|find deadline[s]? in:?|when is this due\??)', caseSensitive: false), '')
        .trim();
    final target = cleanText.isNotEmpty ? cleanText : text;

    final parsedDate = _detectDateInText(target);

    // Look for course code (e.g. CS101, MATH 201, COE 352, SENG 404)
    final courseMatch = RegExp(r'\b([A-Z]{2,4}\s?[0-9]{3}[A-Z]?)\b', caseSensitive: false).firstMatch(target);
    final courseName = courseMatch != null ? courseMatch.group(1)!.toUpperCase() : 'Coursework';

    // Look for assignment keyword
    final taskMatch = RegExp(
      r'\b(assignment\s?[0-9]*|project\s?[0-9]*|lab\s?[0-9]*|quiz\s?[0-9]*|midterm|report|presentation|essay)\b',
      caseSensitive: false,
    ).firstMatch(target);
    final taskTitle = taskMatch != null
        ? taskMatch.group(1)![0].toUpperCase() + taskMatch.group(1)!.substring(1)
        : 'Upcoming Submission';

    if (parsedDate != null) {
      final now = DateTime.now();
      final difference = parsedDate.difference(now);
      final daysLeft = max(0, difference.inDays);
      final hoursLeft = max(0, difference.inHours % 24);
      final countdownStr = daysLeft > 0
          ? '$daysLeft days, $hoursLeft hours left'
          : '$hoursLeft hours left';

      final dateFormatted = _formatDateTime(parsedDate);

      final reply = "### 📅 Extracted Deadline Details\n\n"
          "• **Task**: $taskTitle ($courseName)\n"
          "• **Due Date**: **$dateFormatted**\n"
          "• **Time Remaining**: ⏳ $countdownStr\n\n"
          "**⚡ Suggested Next Steps:**\n"
          "1. Tap **Add to Calendar** below to set an automatic reminder.\n"
          "2. Break down the task into milestones.\n"
          "3. Complete the first draft 24 hours ahead of the deadline.";

      return {
        'reply': reply,
        'intent': 'EXTRACT_DEADLINE',
        'metadata': <String, dynamic>{
          'deadline_found': true,
          'deadline_iso': parsedDate.toIso8601String(),
          'formatted_date': dateFormatted,
          'task_title': taskTitle,
          'course_name': courseName,
        },
      };
    }

    return {
      'reply': "### 📅 Deadline Extraction\n\n"
          "I analyzed your text, but could not pinpoint an explicit date/time.\n\n"
          "💡 **Tip**: Paste an announcement containing date cues (e.g., *'Submit Assignment 2 by next Friday at 5:00 PM'* or *'Due on 15th October'*), and I will extract the schedule for you!",
      'intent': 'EXTRACT_DEADLINE',
      'metadata': <String, dynamic>{'deadline_found': false},
    };
  }

  static Map<String, dynamic> _handleSummarization(String text) {
    final cleanText = text
        .replaceAll(RegExp(r'^(summarize|summarise|summary of|break down|give me a summary of):?\s*', caseSensitive: false), '')
        .trim();
    final target = cleanText.isNotEmpty ? cleanText : text;

    final words = target.split(RegExp(r'\s+'));
    if (words.length < 12) {
      return {
        'reply': "### 📝 Text Summarization\n\n"
            "The text you provided is very brief. Please paste a longer lecture excerpt, reading material, or announcement (at least 2-3 sentences), and I will extract the key takeaways and action items for you!",
        'intent': 'SUMMARIZE',
        'metadata': <String, dynamic>{'summary_generated': false},
      };
    }

    final bullets = _extractiveSummary(target, topN: 3);
    final sentences = _splitSentences(target);
    final actionItems = <String>[];

    for (final s in sentences) {
      if (RegExp(r'\b(submit|read|attend|bring|prepare|review|complete|download|register)\b', caseSensitive: false).hasMatch(s)) {
        final cleaned = s.trim();
        if (cleaned.length > 8 && !actionItems.contains(cleaned)) {
          actionItems.add(cleaned);
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln("### 📝 Summary & Key Takeaways\n");
    for (final b in bullets) {
      buffer.writeln("• $b");
    }

    if (actionItems.isNotEmpty) {
      buffer.writeln("\n**⚡ Action Items Identified:**");
      for (var i = 0; i < min(3, actionItems.length); i++) {
        buffer.writeln("${i + 1}. ${actionItems[i]}");
      }
    }

    buffer.writeln("\n*Processed by Campuz In-House Academic Engine.*");

    return {
      'reply': buffer.toString(),
      'intent': 'SUMMARIZE',
      'metadata': <String, dynamic>{
        'summary_generated': true,
        'bullets': bullets,
        'action_items': actionItems.take(3).toList(),
      },
    };
  }

  static Map<String, dynamic> _handleStudyPlan(String text, String studentName) {
    final match = RegExp(r'\b(?:for|on|in|studying)\s+([a-zA-Z0-9\s]+?)(?:\.|\?|$)', caseSensitive: false).firstMatch(text);
    final subject = match != null ? match.group(1)!.trim() : 'Your Coursework';

    final reply = "### ⏰ Personalized Study & Revision Schedule\n\n"
        "Here is a proven 4-Step **Pomodoro & Spaced Repetition Plan** for **$subject**:\n\n"
        "**Phase 1: Concept Review (Session 1 — 45 mins)**\n"
        "• Review lecture slides, definitions, and core formulas.\n"
        "• Highlight difficult concepts or confusing sections.\n"
        "• *Break*: 10 minutes (walk, hydrate, no screens).\n\n"
        "**Phase 2: Active Recall & Practice (Session 2 — 45 mins)**\n"
        "• Solve 3–5 tutorial problems or past exam questions closed-book.\n"
        "• Test yourself on key terminology.\n"
        "• *Break*: 10 minutes.\n\n"
        "**Phase 3: Error Analysis & Gap Filling (Session 3 — 30 mins)**\n"
        "• Review answers and note why errors occurred.\n"
        "• Create index cards/flashcards for difficult items.\n\n"
        "**Phase 4: Consolidation (15 mins)**\n"
        "• Write down a 3-bullet summary of the session from memory.\n\n"
        "💡 **Pro-Tip for $studentName**: Study during your peak alertness hours and stay consistent!";

    return {
      'reply': reply,
      'intent': 'STUDY_PLAN',
      'metadata': <String, dynamic>{
        'subject': subject,
        'plan_type': 'pomodoro_spaced_repetition',
      },
    };
  }

  static Map<String, dynamic> _handleExamPrep(String text) {
    const reply = "### 🎓 High-Impact Exam Preparation Strategies\n\n"
        "To maximize retention and performance before your exams, apply these 4 proven academic techniques:\n\n"
        "1. **Feynman Technique (Teach to Learn)**:\n"
        "   Explain key concepts out loud in simple terms as if teaching a peer. If you stumble, re-read that section.\n\n"
        "2. **Past Exam Papers Under Timed Conditions**:\n"
        "   Simulate real exam pressure by solving past papers within the allotted time without notes.\n\n"
        "3. **Spaced Retrieval**:\n"
        "   Review challenging topics after 1 day, 3 days, and 7 days to transfer knowledge into long-term memory.\n\n"
        "4. **Formula & Keyword Cheat Sheets**:\n"
        "   Condense each chapter onto a single index card for quick review on exam morning.";

    return {
      'reply': reply,
      'intent': 'EXAM_PREP',
      'metadata': <String, dynamic>{'category': 'exam_prep'},
    };
  }

  static Map<String, dynamic> _handleAssignmentHelp(String text) {
    const reply = "### 📚 Assignment & Project Roadmap\n\n"
        "Follow this structured framework to complete your academic submissions on time:\n\n"
        "• **Step 1: Understand the Rubric**: Identify specific grading criteria, word counts, and formatting requirements (APA/IEEE/Harvard).\n"
        "• **Step 2: Outline Key Headings**: Create an outline covering *Introduction*, *Methodology/Analysis*, *Findings/Discussion*, and *Conclusion*.\n"
        "• **Step 3: Draft First, Edit Later**: Write without stopping to polish grammar so ideas flow freely.\n"
        "• **Step 4: Citation & Plagiarism Check**: Ensure all sources and data are properly cited before submission.\n"
        "• **Step 5: Final Proofread**: Read your paper out loud 24 hours before the deadline to catch awkward phrasing.";

    return {
      'reply': reply,
      'intent': 'ASSIGNMENT_HELP',
      'metadata': <String, dynamic>{'category': 'assignment_guidance'},
    };
  }

  static Map<String, dynamic> _handleHubHelp(String text) {
    const reply = "### 👥 Campuz Hub Collaboration Features\n\n"
        "You can manage and collaborate within your Hubs with these features:\n\n"
        "• **Sections**: Organize course materials into dedicated discussion and topic channels.\n"
        "• **Broadcasts & SMS**: Hub admins can send critical announcements that reach members via In-App notifications and SMS.\n"
        "• **Shared Resources**: Upload lecture PDFs, past questions, and slides for everyone in the hub.\n"
        "• **Group Meetings**: Schedule virtual or physical study sessions with automated reminders.";

    return {
      'reply': reply,
      'intent': 'HUB_HELP',
      'metadata': <String, dynamic>{'category': 'hub_collaboration'},
    };
  }

  static Map<String, dynamic> _handleGeneralAcademicQa(String text, String studentName) {
    final queryPreview = text.length > 70 ? '${text.substring(0, 70)}...' : text;

    final reply = "Hello **$studentName**! I am your Campuz AI Academic Assistant.\n\n"
        "Regarding your query: *\"$queryPreview\"*\n\n"
        "Here are specific ways I can help you with this:\n"
        "• **📅 Extract Deadlines**: Paste the assignment or announcement text and I'll extract due dates and countdowns.\n"
        "• **📝 Summarize Notes**: Paste lecture excerpts to get core takeaways and action items.\n"
        "• **⏰ Study Timetables**: Ask me: *\"Create a study plan for [Subject]\"* to generate a revision plan.\n"
        "• **💡 Exam & Project Guidance**: Ask about exam strategies, citation guides, or essay outlines.\n\n"
        "Try pasting a message or ask: *\"Create a study plan for Software Engineering\"* or *\"Give me exam prep tips\"*!";

    return {
      'reply': reply,
      'intent': 'GENERAL_ACADEMIC_QA',
      'metadata': <String, dynamic>{'category': 'general_qa'},
    };
  }

  // ---------------------------------------------------------------------------
  // NLP Helpers
  // ---------------------------------------------------------------------------

  static List<String> _splitSentences(String text) {
    final raw = text.split(RegExp(r'(?<=[.!?])\s+'));
    final list = raw.map((s) => s.trim()).where((s) => s.length > 8).toList();
    return list.isNotEmpty ? list : [text.trim()];
  }

  static List<String> _tokenize(String text) {
    return RegExp(r'\b[a-zA-Z]{2,}\b')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => !_stopwords.contains(w))
        .toList();
  }

  static List<String> _extractiveSummary(String text, {int topN = 3}) {
    final sentences = _splitSentences(text);
    if (sentences.length <= topN) return sentences;

    final freq = <String, int>{};
    for (final s in sentences) {
      for (final t in _tokenize(s)) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }

    if (freq.isEmpty) return sentences.take(topN).toList();

    final maxFreq = freq.values.reduce(max);
    final scored = <MapEntry<int, double>>[];

    for (var i = 0; i < sentences.length; i++) {
      final tokens = _tokenize(sentences[i]);
      if (tokens.isEmpty) continue;

      var score = tokens.fold<double>(0.0, (acc, t) => acc + ((freq[t] ?? 0) / maxFreq)) / sqrt(tokens.length);

      // Positional bias
      if (i == 0) score *= 1.3;
      if (i == sentences.length - 1) score *= 1.15;

      // Keyword boost
      if (RegExp(r'\b(important|note|due|submit|required|exam|assignment|deadline|lecture)\b', caseSensitive: false).hasMatch(sentences[i])) {
        score *= 1.25;
      }

      scored.add(MapEntry(i, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final topIndices = scored.take(topN).map((e) => e.key).toList()..sort();

    return topIndices.map((idx) => sentences[idx]).toList();
  }

  // ---------------------------------------------------------------------------
  // Date Detection
  // ---------------------------------------------------------------------------

  static DateTime? _detectDateInText(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();

    // 1. Relative "today", "tomorrow"
    if (lower.contains('today')) {
      return DateTime(now.year, now.month, now.day, 23, 59);
    }
    if (lower.contains('tomorrow')) {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day, 17, 0);
    }

    // 2. Day of week (e.g. "next Friday", "this Friday", "by Friday")
    final days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (final entry in days.entries) {
      if (lower.contains(entry.key)) {
        var daysToAdd = entry.value - now.weekday;
        if (daysToAdd <= 0 || lower.contains('next ${entry.key}')) {
          daysToAdd += 7;
        }
        final targetDay = now.add(Duration(days: daysToAdd));
        final time = _extractTimeFromText(lower) ?? const TimeOfDay(hour: 17, minute: 0);
        return DateTime(targetDay.year, targetDay.month, targetDay.day, time.hour, time.minute);
      }
    }

    // 3. Regex for DD/MM/YYYY or YYYY-MM-DD
    final isoMatch = RegExp(r'\b(202\d)-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      final time = _extractTimeFromText(lower) ?? const TimeOfDay(hour: 23, minute: 59);
      return DateTime(y, m, d, time.hour, time.minute);
    }

    final slashMatch = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](202\d|\d{2})\b').firstMatch(text);
    if (slashMatch != null) {
      final d = int.parse(slashMatch.group(1)!);
      final m = int.parse(slashMatch.group(2)!);
      var y = int.parse(slashMatch.group(3)!);
      if (y < 100) y += 2000;
      final time = _extractTimeFromText(lower) ?? const TimeOfDay(hour: 23, minute: 59);
      return DateTime(y, m, d, time.hour, time.minute);
    }

    // 4. Month name matching (e.g. "October 15", "15th Oct", "Nov 2")
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    for (final mEntry in months.entries) {
      final mMatch = RegExp('\\b(${mEntry.key}[a-z]*)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b', caseSensitive: false).firstMatch(lower);
      if (mMatch != null) {
        final d = int.tryParse(mMatch.group(2)!);
        if (d != null && d >= 1 && d <= 31) {
          final time = _extractTimeFromText(lower) ?? const TimeOfDay(hour: 17, minute: 0);
          return DateTime(now.year, mEntry.value, d, time.hour, time.minute);
        }
      }
      final revMatch = RegExp('(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(${mEntry.key}[a-z]*)\\b', caseSensitive: false).firstMatch(lower);
      if (revMatch != null) {
        final d = int.tryParse(revMatch.group(1)!);
        if (d != null && d >= 1 && d <= 31) {
          final time = _extractTimeFromText(lower) ?? const TimeOfDay(hour: 17, minute: 0);
          return DateTime(now.year, mEntry.value, d, time.hour, time.minute);
        }
      }
    }

    return null;
  }

  static TimeOfDay? _extractTimeFromText(String text) {
    final match = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', caseSensitive: false).firstMatch(text);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final period = match.group(3)!.toLowerCase();
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  static String _formatDateTime(DateTime dt) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');

    return '$dayName, $monthName ${dt.day}, ${dt.year} at $hour12:$minuteStr $period';
  }
}

class TimeOfDay {
  final int hour;
  final int minute;
  const TimeOfDay({required this.hour, required this.minute});
}
