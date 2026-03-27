export const TTS_FIELDS = {
  vocabulary: {
    default: 'reading',
    options: [
      { value: 'reading', labelKey: 'tts.fields.reading' },
      { value: 'word', labelKey: 'tts.fields.word' },
      { value: 'example_sentence', labelKey: 'tts.fields.exampleSentence' },
    ],
  },
  grammar: {
    default: 'pattern',
    options: [{ value: 'pattern', labelKey: 'tts.fields.pattern' }],
  },
  cloze: {
    default: 'sentence',
    options: [{ value: 'sentence', labelKey: 'tts.fields.sentence' }],
  },
  sentence_arrange: {
    default: 'japanese_sentence',
    options: [
      { value: 'japanese_sentence', labelKey: 'tts.fields.japaneseSentence' },
    ],
  },
  conversation: {
    default: 'situation',
    options: [{ value: 'situation', labelKey: 'tts.fields.situation' }],
  },
} as const;

export type ContentType = keyof typeof TTS_FIELDS;
