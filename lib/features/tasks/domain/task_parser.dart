import '../../../../core/time/time_service.dart';

/// The result of natural-language task quick capture parsing per SPEC.md §2.4.
class ParsedTask {
  const ParsedTask({
    required this.title,
    this.dueAtUtcMs,
    this.dueIsAllDay = false,
    this.priority = 4,
    this.tags = const [],
    this.estimatePomodoros,
    this.datePhrase,
  });

  /// The cleaned task title with parsed tokens removed.
  final String title;

  /// Due instant in UTC epoch milliseconds, if parsed.
  final int? dueAtUtcMs;

  /// Whether the due date is all-day (true if no time-of-day was specified).
  final bool dueIsAllDay;

  /// Priority 1–4 (1 = highest, 4 = default).
  final int priority;

  /// List of tags extracted from #tag tokens.
  final List<String> tags;

  /// Estimated pomodoro count (e.g. from ~2p).
  final int? estimatePomodoros;

  /// The matched raw date/time phrase, if any.
  final String? datePhrase;
}

/// Natural language parser for task quick capture per SPEC.md §2.4.
///
/// Example: `"submit report fri 5pm !p1 #work ~2p"`
/// - Priority: `!p1` .. `!p4`
/// - Tags: `#work`
/// - Estimate: `~2p` or `2p`
/// - Date/time: trailing phrase like `fri 5pm`, `tomorrow`, `today`, `sep 18 10am`
/// - Everything left over is the title.
/// - If parsing is ambiguous, keeps the text in the title rather than guessing.
class TaskParser {
  const TaskParser({required this.timeService});

  final TimeService timeService;

  static final _priorityRegex = RegExp(r'(?:^|\s)!p([1-4])\b', caseSensitive: false);
  static final _tagRegex = RegExp(r'(?:^|\s)#([a-zA-Z0-9_\-]+)\b');
  static final _estimateRegex = RegExp(r'(?:^|\s)~?([1-9][0-9]*)p\b', caseSensitive: false);

  static const _monthNames = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  static const _weekdays = {
    'mon': DateTime.monday,
    'monday': DateTime.monday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'tuesday': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'wednesday': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'thursday': DateTime.thursday,
    'fri': DateTime.friday,
    'friday': DateTime.friday,
    'sat': DateTime.saturday,
    'saturday': DateTime.saturday,
    'sun': DateTime.sunday,
    'sunday': DateTime.sunday,
  };

  ParsedTask parse(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return const ParsedTask(title: '');
    }

    // 1. Parse priority (!p1..!p4)
    var priority = 4;
    final priorityMatches = _priorityRegex.allMatches(text).toList();
    if (priorityMatches.isNotEmpty) {
      final last = priorityMatches.last;
      priority = int.parse(last.group(1)!);
      // Remove all priority tokens
      text = text.replaceAll(_priorityRegex, ' ').trim();
    }

    // 2. Parse tags (#tag)
    final tags = <String>[];
    final tagMatches = _tagRegex.allMatches(text).toList();
    for (final m in tagMatches) {
      final tag = m.group(1)!.toLowerCase();
      if (!tags.contains(tag)) {
        tags.add(tag);
      }
    }
    if (tags.isNotEmpty) {
      text = text.replaceAll(_tagRegex, ' ').trim();
    }

    // 3. Parse estimate (~2p or 2p)
    int? estimate;
    final estimateMatch = _estimateRegex.firstMatch(text);
    if (estimateMatch != null) {
      estimate = int.tryParse(estimateMatch.group(1)!);
      text = text.replaceAll(_estimateRegex, ' ').trim();
    }

    // Clean up multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 4. Parse trailing date/time phrase
    final dateParseResult = _parseTrailingDateTime(text);

    return ParsedTask(
      title: dateParseResult.title.isEmpty ? input.trim() : dateParseResult.title,
      dueAtUtcMs: dateParseResult.dueAtUtcMs,
      dueIsAllDay: dateParseResult.dueIsAllDay,
      priority: priority,
      tags: tags,
      estimatePomodoros: estimate,
      datePhrase: dateParseResult.datePhrase,
    );
  }

  _DateParseResult _parseTrailingDateTime(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return _DateParseResult(title: text);
    }

    // Check windows of 1, 2, or 3 trailing words (e.g. "fri", "fri 5pm", "sep 18 5pm")
    for (var windowSize = 3; windowSize >= 1; windowSize--) {
      if (words.length < windowSize) continue;

      final candidateWords = words.sublist(words.length - windowSize);
      final candidatePhrase = candidateWords.join(' ').toLowerCase();

      final parsed = _tryParseDateTimePhrase(candidatePhrase);
      if (parsed != null) {
        final remainingWords = words.sublist(0, words.length - windowSize);
        final title = remainingWords.join(' ').trim();
        // If remaining title is empty, keep original text as title per ambiguity rule
        if (title.isEmpty) {
          return _DateParseResult(
            title: text,
            dueAtUtcMs: parsed.dueAtUtcMs,
            dueIsAllDay: parsed.dueIsAllDay,
            datePhrase: candidatePhrase,
          );
        }
        return _DateParseResult(
          title: title,
          dueAtUtcMs: parsed.dueAtUtcMs,
          dueIsAllDay: parsed.dueIsAllDay,
          datePhrase: candidatePhrase,
        );
      }
    }

    return _DateParseResult(title: text);
  }

  _ParsedDateTime? _tryParseDateTimePhrase(String phrase) {
    final tokens = phrase.split(' ');
    if (tokens.isEmpty || tokens.length > 3) return null;

    String? resolvedLocalDate;
    _ParsedTime? resolvedTime;

    if (tokens.length == 1) {
      final token = tokens[0];
      resolvedLocalDate = _resolveDayToken(token);
      if (resolvedLocalDate == null) {
        resolvedTime = _resolveTimeToken(token);
        if (resolvedTime != null) {
          resolvedLocalDate = timeService.todayLocalDate();
        }
      }
    } else if (tokens.length == 2) {
      // Possible combinations:
      // [day, time] -> "fri 5pm", "tomorrow 9am", "today 17:00"
      // [month, day] -> "sep 18", "september 18"
      // [day, month] -> "18 sep"
      final t0 = tokens[0];
      final t1 = tokens[1];

      final dayFromT0 = _resolveDayToken(t0);
      if (dayFromT0 != null) {
        final timeFromT1 = _resolveTimeToken(t1);
        if (timeFromT1 != null) {
          resolvedLocalDate = dayFromT0;
          resolvedTime = timeFromT1;
        }
      } else {
        // Check month + day or day + month
        resolvedLocalDate = _resolveMonthDay(t0, t1);
      }
    } else if (tokens.length == 3) {
      // Possible: [month, day, time] -> "sep 18 5pm" or "18 sep 5pm"
      final datePart = _resolveMonthDay(tokens[0], tokens[1]);
      if (datePart != null) {
        final timePart = _resolveTimeToken(tokens[2]);
        if (timePart != null) {
          resolvedLocalDate = datePart;
          resolvedTime = timePart;
        }
      }
    }

    if (resolvedLocalDate == null) return null;

    final parts = resolvedLocalDate.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    if (resolvedTime != null) {
      final utcNominal = DateTime.utc(
        year,
        month,
        day,
        resolvedTime.hour,
        resolvedTime.minute,
      ).millisecondsSinceEpoch;
      final offsetMs = timeService.currentTzOffsetMin(utcNominal) * 60 * 1000;
      final trueUtcMs = utcNominal - offsetMs;
      return _ParsedDateTime(
        dueAtUtcMs: trueUtcMs,
        dueIsAllDay: false,
      );
    } else {
      // All-day event: use 12:00 UTC on that calendar date
      final utcDt = DateTime.utc(year, month, day, 12);
      return _ParsedDateTime(
        dueAtUtcMs: utcDt.millisecondsSinceEpoch,
        dueIsAllDay: true,
      );
    }
  }

  String? _resolveDayToken(String token) {
    final today = timeService.todayLocalDate();
    if (token == 'today') return today;
    if (token == 'tomorrow' || token == 'tmrw') {
      return TimeService.addDays(today, 1);
    }

    final targetWeekday = _weekdays[token];
    if (targetWeekday != null) {
      final todayParts = today.split('-');
      final todayDt = DateTime.utc(
        int.parse(todayParts[0]),
        int.parse(todayParts[1]),
        int.parse(todayParts[2]),
      );
      final currentWeekday = todayDt.weekday;
      var diff = targetWeekday - currentWeekday;
      if (diff <= 0) {
        diff += 7; // Next occurrence of that day
      }
      return TimeService.addDays(today, diff);
    }

    // Check ISO format YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(token)) {
      return token;
    }

    return null;
  }

  String? _resolveMonthDay(String t0, String t1) {
    int? month;
    int? day;

    if (_monthNames.containsKey(t0)) {
      month = _monthNames[t0];
      day = int.tryParse(t1.replaceAll(RegExp(r'(st|nd|rd|th)$'), ''));
    } else if (_monthNames.containsKey(t1)) {
      month = _monthNames[t1];
      day = int.tryParse(t0.replaceAll(RegExp(r'(st|nd|rd|th)$'), ''));
    }

    if (month != null && day != null && day >= 1 && day <= 31) {
      final today = timeService.todayLocalDate();
      final currentYear = int.parse(today.split('-')[0]);
      final thisYear = TimeService.formatIsoDate(currentYear, month, day);
      // Roll forward when the date has already gone by, the same way the
      // weekday branch above rolls to next week rather than naming a day in
      // the past. Typing "jan 5" in December means next January.
      //
      // Compared as plain strings: ISO dates sort chronologically, and both
      // sides are already normalised by `formatIsoDate`/`todayLocalDate`.
      if (thisYear.compareTo(today) >= 0) return thisYear;
      return TimeService.formatIsoDate(currentYear + 1, month, day);
    }

    return null;
  }

  _ParsedTime? _resolveTimeToken(String token) {
    if (token == 'noon') return const _ParsedTime(12, 0);
    if (token == 'midnight') return const _ParsedTime(0, 0);

    // 12-hour: 5pm, 5:30pm, 9am, 9:15am
    final m12 = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)$', caseSensitive: false)
        .firstMatch(token);
    if (m12 != null) {
      var hour = int.parse(m12.group(1)!);
      final minute = m12.group(2) != null ? int.parse(m12.group(2)!) : 0;
      final isPm = m12.group(3)!.toLowerCase() == 'pm';

      if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      return _ParsedTime(hour, minute);
    }

    // 24-hour: 17:00, 09:30
    final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(token);
    if (m24 != null) {
      final hour = int.parse(m24.group(1)!);
      final minute = int.parse(m24.group(2)!);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return _ParsedTime(hour, minute);
      }
    }

    return null;
  }
}

class _DateParseResult {
  const _DateParseResult({
    required this.title,
    this.dueAtUtcMs,
    this.dueIsAllDay = false,
    this.datePhrase,
  });

  final String title;
  final int? dueAtUtcMs;
  final bool dueIsAllDay;
  final String? datePhrase;
}

class _ParsedDateTime {
  const _ParsedDateTime({
    required this.dueAtUtcMs,
    required this.dueIsAllDay,
  });

  final int dueAtUtcMs;
  final bool dueIsAllDay;
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);
  final int hour;
  final int minute;
}
