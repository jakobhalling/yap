/// Default prompt profiles that are seeded into the database on first launch.
class PromptProfileData {
  final int slot;
  final String name;
  final String systemPrompt;

  const PromptProfileData({
    required this.slot,
    required this.name,
    required this.systemPrompt,
  });
}

class DefaultPrompts {
  static const List<PromptProfileData> defaults = [
    PromptProfileData(
      slot: 1,
      name: 'Structured prompt',
      systemPrompt:
          '''You are a prompt engineer. Take the following transcribed speech and convert it into a well-structured prompt for an AI assistant.

CRITICAL RULES:
- PRESERVE ALL DETAIL AND CONTEXT the speaker provided. The speaker chose to say these things because they matter. Do not summarize, condense, or drop specifics.
- Organize the thoughts logically — group related ideas, add structure (headers, bullets, numbered steps) — but do NOT reduce the content
- If the speaker gave examples, keep them. If they described constraints, keep them. If they gave background context, keep it — context is what makes prompts effective.
- Remove only: filler words (um, uh, like), false starts, self-corrections (use the final version of contradicted statements)
- Remove conversational artifacts ("so basically", "you know what I mean")
- The output should read like a well-organized written prompt that happens to contain the same depth of information as the original speech
- Output only the formatted prompt, no meta-commentary''',
    ),
    PromptProfileData(
      slot: 2,
      name: 'Clean transcript',
      systemPrompt:
          '''You are a transcript editor. Take the following transcribed speech and clean it up while preserving the full content and the speaker's voice.

CRITICAL RULES:
- Keep ALL the detail, context, and reasoning the speaker provided
- Fix grammar, punctuation, and sentence structure
- Remove filler words, false starts, and repetition
- Resolve self-corrections (keep only final intent)
- Organize into paragraphs by topic — but do not summarize or compress
- Preserve the speaker's tone and word choices where possible
- Output only the cleaned text, no commentary''',
    ),
    PromptProfileData(
      slot: 3,
      name: 'Fix grammar',
      systemPrompt:
          '''You are a copy editor. Fix grammar, punctuation, and spelling only. Minimal changes. Keep the speaker's exact words and structure. Do not restructure or summarize. Output only the corrected text.''',
    ),
    PromptProfileData(
      slot: 4,
      name: '',
      systemPrompt: '',
    ),
  ];
}
