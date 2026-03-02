export type JlptLevel = 'N5' | 'N4' | 'N3' | 'N2' | 'N1';

export type PartOfSpeech =
  | 'noun'
  | 'verb_group1'
  | 'verb_group2'
  | 'verb_group3'
  | 'i_adjective'
  | 'na_adjective'
  | 'adverb'
  | 'particle'
  | 'conjunction'
  | 'other';

export type Vocabulary = {
  id: string;
  word: string;
  reading: string;
  meaningKo: string;
  partOfSpeech: PartOfSpeech;
  jlptLevel: JlptLevel;
  exampleSentence: string;
  exampleTranslation: string;
  tags: string[];
  audioUrl: string | null;
};

export type Grammar = {
  id: string;
  pattern: string;
  meaningKo: string;
  explanation: string;
  jlptLevel: JlptLevel;
  exampleSentences: {
    japanese: string;
    reading: string;
    korean: string;
  }[];
  relatedGrammarIds: string[];
};
