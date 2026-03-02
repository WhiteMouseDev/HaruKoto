export type Difficulty = 'beginner' | 'intermediate' | 'advanced';

export type ScenarioCategory = {
  id: string;
  name: string;
  icon: string;
  scenarioCount: number;
  scenarios: Scenario[];
};

export type Scenario = {
  id: string;
  title: string;
  titleJa: string;
  description: string;
  difficulty: Difficulty;
  estimatedMinutes: number;
  keyExpressions: string[];
};

export type ConversationMessage = {
  role: 'user' | 'assistant';
  contentJa: string;
  contentKo: string;
  feedback?: {
    type: 'grammar' | 'expression' | 'politeness';
    original: string;
    correction: string;
    explanationKo: string;
  }[];
  hint?: string;
  newVocabulary?: {
    word: string;
    reading: string;
    meaningKo: string;
  }[];
};

export type ConversationReport = {
  overallScore: number;
  fluency: number;
  accuracy: number;
  vocabularyDiversity: number;
  naturalness: number;
  goodExpressions: {
    expression: string;
    reasonKo: string;
  }[];
  improvements: {
    original: string;
    suggestion: string;
    explanationKo: string;
  }[];
  newVocabulary: {
    word: string;
    reading: string;
    meaningKo: string;
  }[];
};

export type Conversation = {
  id: string;
  scenarioTitle: string;
  scenarioCategory: string;
  createdAt: string;
  duration: number;
  overallScore: number;
  messages: ConversationMessage[];
  report?: ConversationReport;
};
