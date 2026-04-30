import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('next-intl', () => ({
  useTranslations: () => (key: string) => key,
}));

vi.mock('@tanstack/react-query', () => ({
  useQuery: vi.fn(),
}));

import { useQuery } from '@tanstack/react-query';
import TtsReviewPage from '@/app/(admin)/tts-review/page';
import type {
  TtsReviewBatchListResponse,
  TtsReviewBatchTargetsResponse,
  TtsReviewExecutePreviewResponse,
  TtsReviewGenerationPlanResponse,
} from '@/lib/api/admin-content';

const mockUseQuery = vi.mocked(useQuery);
const mockRefetch = vi.fn();

const response: TtsReviewBatchListResponse = {
  schemaVersion: 1,
  status: 'draft',
  summary: {
    totalBatches: 2,
    totalTargets: 3,
    adminReadyTargets: 2,
    extensionRequiredTargets: 1,
    requiredBeforePublishTargets: 2,
    generationStatusSummary: {
      missing: 3,
      generated: 0,
      approved: 0,
      rejected: 0,
      stale: 0,
    },
  },
  batches: [
    {
      batchId: 'tts-review-admin-vocabulary-fields',
      status: 'draft',
      reviewSurface: 'admin_existing_tts',
      sourceKind: 'topic_vocabulary_fields',
      targetIds: ['tts-vocabulary-word', 'tts-vocabulary-reading'],
      targetCount: 2,
      requiredBeforePublishCount: 2,
      generationStatusSummary: {
        missing: 2,
        generated: 0,
        approved: 0,
        rejected: 0,
        stale: 0,
      },
      adminExport: {
        mode: 'existing_admin_tts_fields',
        contentType: 'vocabulary',
        fieldMappings: [
          { audioField: 'word', adminField: 'word' },
          { audioField: 'reading', adminField: 'reading' },
        ],
        blockers: [],
      },
      reviewerChecklist: ['check'],
      notesKo: 'review',
    },
    {
      batchId: 'tts-review-gap-seed-script-lines',
      status: 'draft',
      reviewSurface: 'admin_extension_required',
      sourceKind: 'seed_candidate_script_lines',
      targetIds: ['tts-seed-script-1'],
      targetCount: 1,
      requiredBeforePublishCount: 0,
      generationStatusSummary: {
        missing: 1,
        generated: 0,
        approved: 0,
        rejected: 0,
        stale: 0,
      },
      adminExport: {
        mode: 'requires_admin_extension',
        contentType: 'lesson_seed_candidate',
        fieldMappings: [{ audioField: 'script_line', adminField: 'script_line' }],
        blockers: ['lesson_seed_admin_surface_gap'],
      },
      reviewerChecklist: ['check'],
      notesKo: 'review',
    },
  ],
};

const targetResponse: TtsReviewBatchTargetsResponse = {
  schemaVersion: 1,
  status: 'draft',
  batch: response.batches[0],
  targets: [
    {
      targetId: 'tts-vocabulary-word',
      topicId: 'topic-personal-pronouns',
      audioTargetType: 'vocabulary',
      audioField: 'word',
      textSource: 'curriculum-topics:topic-personal-pronouns:word',
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      preferredVoiceId: null,
      generationStatus: 'missing',
      cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
      notesKo: 'review',
    },
    {
      targetId: 'tts-vocabulary-reading',
      topicId: 'topic-personal-pronouns',
      audioTargetType: 'vocabulary',
      audioField: 'reading',
      textSource: 'curriculum-topics:topic-personal-pronouns:reading',
      defaultSpeed: 0.9,
      requiredBeforePublish: true,
      preferredVoiceId: 'japanese_female_1',
      generationStatus: 'missing',
      cacheKeyStrategy: 'provider-model-speed-field-text-hash-v1',
      notesKo: 'review',
    },
  ],
};

const generationPlanResponse: TtsReviewGenerationPlanResponse = {
  schemaVersion: 1,
  status: 'draft',
  batch: response.batches[0],
  summary: {
    totalTargets: 2,
    supportedTargets: 2,
    readyAfterDbLookupTargets: 0,
    manualMappingRequiredTargets: 2,
    blockedTargets: 0,
  },
  items: targetResponse.targets.map((target) => ({
    target,
    adminContentType: 'vocabulary',
    adminField: target.audioField,
    operationStatus: 'manual_mapping_required',
    existingAdminTtsSupported: true,
    candidates: [
      {
        contentType: 'vocabulary',
        lookupType: 'topic_id',
        topicId: target.topicId,
        adminField: target.audioField,
        jlptLevel: null,
        grammarOrder: null,
        vocabularyOrder: null,
        matchType: null,
        noteKo: 'review',
      },
    ],
    blockerCodes: ['topic_vocabulary_mapping_required'],
    notesKo: 'review',
  })),
};

const executePreviewResponse: TtsReviewExecutePreviewResponse = {
  schemaVersion: 1,
  status: 'draft',
  batch: response.batches[0],
  summary: {
    totalTargets: 2,
    resolvedTargets: 0,
    missingTargets: 0,
    ambiguousTargets: 0,
    notLookupReadyTargets: 2,
    blockedTargets: 0,
    generatableTargets: 0,
  },
  items: targetResponse.targets.map((target) => ({
    target,
    adminContentType: 'vocabulary',
    adminField: target.audioField,
    lookupStatus: 'not_lookup_ready',
    canGenerateWithCurrentService: false,
    candidate: {
      contentType: 'vocabulary',
      lookupType: 'topic_id',
      topicId: target.topicId,
      adminField: target.audioField,
      jlptLevel: null,
      grammarOrder: null,
      vocabularyOrder: null,
      matchType: null,
      noteKo: 'review',
    },
    contentItemId: null,
    contentLabel: null,
    notesKo: 'review',
  })),
};

beforeEach(() => {
  vi.clearAllMocks();
  mockUseQuery.mockImplementation((options) => {
    const queryKey = (options as { queryKey?: unknown[] }).queryKey;
    if (queryKey?.[0] === 'admin-tts-review-batch-targets') {
      return {
        data: (options as { enabled?: boolean }).enabled
          ? targetResponse
          : undefined,
        isLoading: false,
        isError: false,
        isFetching: false,
        refetch: mockRefetch,
      } as unknown as ReturnType<typeof useQuery>;
    }
    if (queryKey?.[0] === 'admin-tts-review-generation-plan') {
      return {
        data: (options as { enabled?: boolean }).enabled
          ? generationPlanResponse
          : undefined,
        isLoading: false,
        isError: false,
        isFetching: false,
        refetch: mockRefetch,
      } as unknown as ReturnType<typeof useQuery>;
    }
    if (queryKey?.[0] === 'admin-tts-review-execute-preview') {
      return {
        data: (options as { enabled?: boolean }).enabled
          ? executePreviewResponse
          : undefined,
        isLoading: false,
        isError: false,
        isFetching: false,
        refetch: mockRefetch,
      } as unknown as ReturnType<typeof useQuery>;
    }

    return {
      data: response,
      isLoading: false,
      isError: false,
      isFetching: false,
      refetch: mockRefetch,
    } as unknown as ReturnType<typeof useQuery>;
  });
});

describe('TtsReviewPage', () => {
  it('renders summary counts and batch rows', () => {
    render(<TtsReviewPage />);

    expect(screen.getByText('title')).toBeTruthy();
    expect(screen.getByText('tts-review-admin-vocabulary-fields')).toBeTruthy();
    expect(screen.getByText('tts-review-gap-seed-script-lines')).toBeTruthy();
    expect(screen.getAllByText('2').length).toBeGreaterThan(0);
    expect(screen.getAllByText('3').length).toBeGreaterThan(0);
  });

  it('refetches when refresh is clicked', () => {
    render(<TtsReviewPage />);

    fireEvent.click(screen.getByRole('button', { name: /refresh/ }));

    expect(mockRefetch).toHaveBeenCalledTimes(1);
  });

  it('renders target details when a batch is selected', () => {
    render(<TtsReviewPage />);

    fireEvent.click(screen.getAllByRole('button', { name: /table.viewTargets/ })[0]);

    expect(screen.getByText('tts-vocabulary-word')).toBeTruthy();
    expect(screen.getByText('tts-vocabulary-reading')).toBeTruthy();
    expect(screen.getByText('curriculum-topics:topic-personal-pronouns:word')).toBeTruthy();
    expect(screen.getByText('japanese_female_1')).toBeTruthy();
    expect(screen.getAllByText('generationPlan.manual_mapping_required').length).toBeGreaterThan(0);
    expect(screen.getAllByText('executePreview.not_lookup_ready').length).toBeGreaterThan(0);
  });
});
