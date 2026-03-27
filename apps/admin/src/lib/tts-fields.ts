export const TTS_FIELDS = {
  vocabulary: {
    default: 'reading',
    options: [
      { value: 'reading', labelKey: 'fields.reading' },
      { value: 'word', labelKey: 'fields.word' },
      { value: 'example_sentence', labelKey: 'fields.exampleSentence' },
    ],
  },
  grammar: {
    default: 'pattern',
    options: [{ value: 'pattern', labelKey: 'fields.pattern' }],
  },
  cloze: {
    default: 'sentence',
    options: [{ value: 'sentence', labelKey: 'fields.sentence' }],
  },
  sentence_arrange: {
    default: 'japanese_sentence',
    options: [
      { value: 'japanese_sentence', labelKey: 'fields.japaneseSentence' },
    ],
  },
  conversation: {
    default: 'situation',
    options: [{ value: 'situation', labelKey: 'fields.situation' }],
  },
} as const;

export type ContentType = keyof typeof TTS_FIELDS;
