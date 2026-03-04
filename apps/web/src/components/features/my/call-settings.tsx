export type CallSettingsData = {
  silenceDurationMs: number;
  aiResponseSpeed: number;
  subtitleEnabled: boolean;
  autoAnalysis: boolean;
};

const DEFAULT_SILENCE_BY_LEVEL: Record<string, number> = {
  N5: 3000,
  N4: 2500,
  N3: 2000,
  N2: 1500,
  N1: 1200,
};

export function getDefaultCallSettings(jlptLevel: string): CallSettingsData {
  return {
    silenceDurationMs: DEFAULT_SILENCE_BY_LEVEL[jlptLevel] ?? 2000,
    aiResponseSpeed: 1.0,
    subtitleEnabled: true,
    autoAnalysis: true,
  };
}
