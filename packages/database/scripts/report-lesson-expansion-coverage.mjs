import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const REPO_ROOT = join(PACKAGE_DIR, '..', '..');
const CURRICULUM_DIR = join(PACKAGE_DIR, 'data', 'curriculum');
const LESSONS_DIR = join(PACKAGE_DIR, 'data', 'lessons');
const VOCABULARY_DIR = join(PACKAGE_DIR, 'data', 'vocabulary');
const GRAMMAR_DIR = join(PACKAGE_DIR, 'data', 'grammar');

const TARGET_LEVELS = ['N5', 'N4'];
const REPORT_DATE = '2026-05-26';

const LEVEL_TARGETS = {
  N5: { targetLessons: 80, targetChapters: '12-15' },
  N4: { targetLessons: 90, targetChapters: '14-18' },
};

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'));
}

function listJsonFiles(dirPath) {
  if (!existsSync(dirPath)) return [];
  return readdirSync(dirPath)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => join(dirPath, name));
}

function expandPath(value) {
  if (!value) return value;
  if (value === '~') return homedir();
  if (value.startsWith('~/')) return join(homedir(), value.slice(2));
  return value;
}

function parseArgs(argv) {
  const args = {
    pdfDir: join(homedir(), 'Downloads', 'japanese'),
    markdownOutput: null,
    jsonOutput: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--') {
      continue;
    } else if (value === '--pdf-dir') {
      args.pdfDir = expandPath(argv[index + 1]);
      index += 1;
    } else if (value === '--markdown-output') {
      args.markdownOutput = argv[index + 1];
      index += 1;
    } else if (value === '--json-output') {
      args.jsonOutput = argv[index + 1];
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${value}`);
    }
  }

  return args;
}

function loadRowsByLevel(dirPath) {
  const byLevel = new Map();
  for (const filePath of listJsonFiles(dirPath)) {
    const rows = readJson(filePath);
    for (const row of rows) {
      if (!row?.jlptLevel) continue;
      if (!byLevel.has(row.jlptLevel)) byLevel.set(row.jlptLevel, []);
      byLevel.get(row.jlptLevel).push(row);
    }
  }
  return byLevel;
}

function listPdfFiles(pdfDir) {
  if (!existsSync(pdfDir)) {
    return { pdfDir, files: [], missingDirectory: true };
  }

  const files = readdirSync(pdfDir)
    .filter((name) => name.toLowerCase().endsWith('.pdf'))
    .sort()
    .map((fileName) => {
      const filePath = join(pdfDir, fileName);
      const stats = statSync(filePath);
      const fileBuffer = readFileSync(filePath);
      const pageMatches = fileBuffer.toString('latin1').match(/\/Type\s*\/Page\b/g);
      return {
        ref: basename(fileName, '.pdf'),
        fileName,
        pageCount: pageMatches?.length ?? null,
        sizeBytes: stats.size,
        modifiedAt: stats.mtime.toISOString(),
        sourceFingerprint: createHash('sha256').update(fileBuffer).digest('hex').slice(0, 16),
      };
    });

  return { pdfDir, files, missingDirectory: false };
}

function levelCountsFromInventory(items) {
  const counts = new Map();
  for (const item of items) {
    for (const level of item.inferredLevels ?? []) {
      counts.set(level, (counts.get(level) ?? 0) + 1);
    }
  }
  return Object.fromEntries([...counts.entries()].sort(([left], [right]) => left.localeCompare(right)));
}

function collectLessonStats(level, vocabRows, grammarRows) {
  const levelDir = join(LESSONS_DIR, level.toLowerCase());
  const lessonFiles = listJsonFiles(levelDir);
  const primaryGrammarOrders = new Set();
  const allGrammarOrders = new Set();
  const vocabOrders = new Set();
  const lessonIds = new Set();
  const chapterRows = [];
  let vocabLinkCount = 0;
  let questionCount = 0;
  let scriptLineCount = 0;
  let lessonCount = 0;

  for (const filePath of lessonFiles) {
    const data = readJson(filePath);
    const lessons = data.lessons ?? [];
    lessonCount += lessons.length;
    chapterRows.push({
      chapterNo: data.meta?.chapter_no,
      chapterTitle: data.meta?.chapter_title,
      lessonCount: lessons.length,
      status: data.meta?.status,
    });

    for (const lesson of lessons) {
      lessonIds.add(lesson.lesson_id);

      const grammarOrder = lesson.grammar?.grammar_order;
      if (Number.isInteger(grammarOrder)) {
        primaryGrammarOrders.add(grammarOrder);
        allGrammarOrders.add(grammarOrder);
      }
      for (const order of lesson.grammar?.supporting_grammar_orders ?? []) {
        if (Number.isInteger(order)) allGrammarOrders.add(order);
      }
      for (const order of lesson.vocab_orders ?? []) {
        if (Number.isInteger(order)) {
          vocabOrders.add(order);
          vocabLinkCount += 1;
        }
      }

      questionCount += lesson.content_jsonb?.questions?.length ?? 0;
      scriptLineCount += lesson.content_jsonb?.reading?.script?.length ?? 0;
    }
  }

  const target = LEVEL_TARGETS[level];

  return {
    level,
    chapters: lessonFiles.length,
    lessons: lessonCount,
    targetChapters: target.targetChapters,
    targetLessons: target.targetLessons,
    additionalLessonsRecommended: Math.max(target.targetLessons - lessonCount, 0),
    primaryGrammarUnique: primaryGrammarOrders.size,
    allGrammarRefs: allGrammarOrders.size,
    grammarTotal: grammarRows.length,
    vocabUnique: vocabOrders.size,
    vocabTotal: vocabRows.length,
    questions: questionCount,
    scriptLines: scriptLineCount,
    averageQuestionsPerLesson: lessonCount > 0 ? Number((questionCount / lessonCount).toFixed(2)) : 0,
    averageVocabLinksPerLesson: lessonCount > 0 ? Number((vocabLinkCount / lessonCount).toFixed(2)) : 0,
    primaryGrammarCoveragePct:
      grammarRows.length > 0 ? Number(((primaryGrammarOrders.size / grammarRows.length) * 100).toFixed(1)) : 0,
    vocabCoveragePct: vocabRows.length > 0 ? Number(((vocabOrders.size / vocabRows.length) * 100).toFixed(1)) : 0,
    primaryGrammarOrders: [...primaryGrammarOrders].sort((left, right) => left - right),
    allGrammarOrders: [...allGrammarOrders].sort((left, right) => left - right),
    lessonIds: [...lessonIds].sort(),
    chaptersByNo: chapterRows.sort((left, right) => left.chapterNo - right.chapterNo),
  };
}

function groupCounts(rows, keyGetter) {
  const counts = new Map();
  for (const row of rows) {
    const key = keyGetter(row);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return Object.fromEntries([...counts.entries()].sort(([left], [right]) => left.localeCompare(right)));
}

function topicLevel(topic, inventoryByRef) {
  if (TARGET_LEVELS.includes(topic.inferredJlptLevel)) return topic.inferredJlptLevel;
  for (const source of topic.sourceRefs ?? []) {
    const item = inventoryByRef.get(source.ref);
    const level = item?.inferredLevels?.find((candidate) => TARGET_LEVELS.includes(candidate));
    if (level) return level;
  }
  return topic.inferredJlptLevel ?? 'UNKNOWN';
}

function buildCoverageRows({ inventoryItems, topics, priorities, blueprints, candidates, lessonStatsByLevel }) {
  const inventoryByRef = new Map(inventoryItems.map((item) => [item.pdfRef, item]));
  const topicsBySourceRef = new Map();
  for (const topic of topics) {
    for (const source of topic.sourceRefs ?? []) {
      if (source.type !== 'pdf') continue;
      if (!topicsBySourceRef.has(source.ref)) topicsBySourceRef.set(source.ref, []);
      topicsBySourceRef.get(source.ref).push(topic);
    }
  }

  const priorityByTopicId = new Map(priorities.map((row) => [row.topicId, row]));
  const blueprintTopicIds = new Set();
  for (const blueprint of blueprints) {
    if (blueprint.primaryTopicId) blueprintTopicIds.add(blueprint.primaryTopicId);
    for (const topicId of blueprint.topicIds ?? []) blueprintTopicIds.add(topicId);
  }

  const candidateTopicIds = new Set();
  for (const candidate of candidates) {
    if (candidate.primaryTopicId) candidateTopicIds.add(candidate.primaryTopicId);
    for (const topicId of candidate.sourceTopicIds ?? []) candidateTopicIds.add(topicId);
    for (const topicId of candidate.topicIds ?? []) candidateTopicIds.add(topicId);
  }

  const rows = [];
  for (const item of inventoryItems) {
    const itemLevels = (item.inferredLevels ?? []).filter((level) => TARGET_LEVELS.includes(level));
    if (itemLevels.length === 0) continue;

    const sourceTopics = topicsBySourceRef.get(item.pdfRef) ?? [];
    for (const level of itemLevels) {
      const levelStats = lessonStatsByLevel[level];
      const topicRows =
        sourceTopics.length > 0
          ? sourceTopics
          : [
              {
                topicId: `missing-topic-${item.pdfRef}`,
                titleKo: item.titleKo,
                coverageStatus: 'missing',
                mappedLessonIds: [],
                mappedGrammarOrders: [],
                sourceRefs: [{ type: 'pdf', ref: item.pdfRef }],
              },
            ];

      const topicOutcomes = topicRows.map((topic) => {
        const mappedLessonIds = topic.mappedLessonIds ?? [];
        const mappedGrammarOrders = topic.mappedGrammarOrders ?? [];
        const officialLessonMatch = mappedLessonIds.some((lessonId) => levelStats.lessonIds.includes(lessonId));
        const grammarMatch = mappedGrammarOrders.some(
          (mapping) => mapping.level === level && levelStats.allGrammarOrders.includes(mapping.order),
        );
        const hasOfficialCoverage = officialLessonMatch || grammarMatch;
        const hasSeedCandidate = candidateTopicIds.has(topic.topicId);
        const hasBlueprint = blueprintTopicIds.has(topic.topicId);
        const priority = priorityByTopicId.get(topic.topicId);

        return {
          topicId: topic.topicId,
          titleKo: topic.titleKo,
          inferredLevel: topicLevel(topic, inventoryByRef),
          coverageStatus: topic.coverageStatus ?? 'unknown',
          officialCoverage: hasOfficialCoverage,
          seedCandidateCoverage: hasSeedCandidate,
          blueprintCoverage: hasBlueprint,
          priority: priority?.priority ?? null,
          recommendedWave: priority?.recommendedWave ?? null,
          blockers: priority?.blockers ?? [],
        };
      });

      const officialCount = topicOutcomes.filter((row) => row.officialCoverage).length;
      const candidateCount = topicOutcomes.filter((row) => !row.officialCoverage && row.seedCandidateCoverage).length;
      const blueprintCount = topicOutcomes.filter(
        (row) => !row.officialCoverage && !row.seedCandidateCoverage && row.blueprintCoverage,
      ).length;

      let lessonCoverageState = 'backlog_only';
      if (topicOutcomes.length > 0 && officialCount === topicOutcomes.length) {
        lessonCoverageState = 'official_seed';
      } else if (officialCount > 0) {
        lessonCoverageState = 'partial_official_seed';
      } else if (candidateCount > 0) {
        lessonCoverageState = 'seed_candidate_only';
      } else if (blueprintCount > 0) {
        lessonCoverageState = 'blueprint_only';
      }

      rows.push({
        pdfRef: item.pdfRef,
        titleKo: item.titleKo,
        level,
        levelConfidence: item.levelConfidence,
        inventoryCoverageAction: item.coverageAction,
        lessonCoverageState,
        topics: topicOutcomes,
      });
    }
  }

  return rows.sort((left, right) => {
    if (left.level !== right.level) return left.level.localeCompare(right.level);
    return left.pdfRef.localeCompare(right.pdfRef);
  });
}

function summarizeCoverageRows(rows) {
  const byLevel = {};
  for (const level of TARGET_LEVELS) {
    const levelRows = rows.filter((row) => row.level === level);
    byLevel[level] = {
      pdfRefs: levelRows.length,
      byLessonCoverageState: groupCounts(levelRows, (row) => row.lessonCoverageState),
      byInventoryAction: groupCounts(levelRows, (row) => row.inventoryCoverageAction),
      highPriorityGaps: levelRows
        .filter((row) => row.lessonCoverageState !== 'official_seed')
        .filter((row) => row.topics.some((topic) => topic.priority === 'P0' || topic.priority === 'P1'))
        .map((row) => ({
          pdfRef: row.pdfRef,
          titleKo: row.titleKo,
          state: row.lessonCoverageState,
          priorities: [...new Set(row.topics.map((topic) => topic.priority).filter(Boolean))],
          waves: [...new Set(row.topics.map((topic) => topic.recommendedWave).filter(Boolean))],
        })),
    };
  }
  return byLevel;
}

function buildReport(pdfDir) {
  const inventory = readJson(join(CURRICULUM_DIR, 'pdf-topic-inventory.json'));
  const topicsContract = readJson(join(CURRICULUM_DIR, 'curriculum-topics.json'));
  const prioritiesContract = readJson(join(CURRICULUM_DIR, 'coverage-priorities.json'));
  const blueprintsContract = readJson(join(CURRICULUM_DIR, 'lesson-draft-blueprints.json'));
  const candidatesContract = readJson(join(CURRICULUM_DIR, 'lesson-seed-candidates.json'));
  const vocabByLevel = loadRowsByLevel(VOCABULARY_DIR);
  const grammarByLevel = loadRowsByLevel(GRAMMAR_DIR);

  const pdfFiles = listPdfFiles(pdfDir);
  const pageCountSummary = groupCounts(pdfFiles.files, (file) => String(file.pageCount ?? 'unknown'));
  const foundPdfRefs = new Set(pdfFiles.files.map((file) => file.ref));
  const expectedPdfRefs = new Set(inventory.items.map((item) => item.pdfRef));
  const missingPdfRefs = [...expectedPdfRefs].filter((ref) => !foundPdfRefs.has(ref)).sort();
  const extraPdfRefs = [...foundPdfRefs].filter((ref) => !expectedPdfRefs.has(ref)).sort();

  const lessonStatsByLevel = Object.fromEntries(
    TARGET_LEVELS.map((level) => [
      level,
      collectLessonStats(level, vocabByLevel.get(level) ?? [], grammarByLevel.get(level) ?? []),
    ]),
  );

  const coverageRows = buildCoverageRows({
    inventoryItems: inventory.items,
    topics: topicsContract.topics,
    priorities: prioritiesContract.priorities,
    blueprints: blueprintsContract.lessons,
    candidates: candidatesContract.candidates,
    lessonStatsByLevel,
  });

  const prioritySummary = groupCounts(prioritiesContract.priorities, (row) =>
    [row.priority, row.recommendedWave, row.coverageStatus].join(' / '),
  );

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    sourcePolicy: {
      referenceUseOnly: true,
      copiedSourceExamplesAllowed: false,
      note: 'PDF files are used as coverage anchors only. Lesson examples, prompts, and explanations must be newly authored.',
    },
    pdfSource: {
      directory: pdfFiles.pdfDir,
      missingDirectory: pdfFiles.missingDirectory,
      inventoryRefs: inventory.items.length,
      filesFound: pdfFiles.files.length,
      missingPdfRefs,
      extraPdfRefs,
      totalPages: pdfFiles.files.reduce((sum, file) => sum + (file.pageCount ?? 0), 0),
      pageCountSummary,
      levelCounts: levelCountsFromInventory(inventory.items),
      fileAudit: pdfFiles.files,
    },
    currentLessons: lessonStatsByLevel,
    derivedContracts: {
      topics: topicsContract.topics.length,
      coveragePriorities: prioritiesContract.priorities.length,
      lessonDraftBlueprints: blueprintsContract.lessons.length,
      lessonSeedCandidates: candidatesContract.candidates.length,
      prioritySummary,
    },
    pdfLessonCoverage: {
      summaryByLevel: summarizeCoverageRows(coverageRows),
      rows: coverageRows,
    },
  };
}

function table(headers, rows) {
  return [
    `| ${headers.join(' | ')} |`,
    `| ${headers.map(() => '---').join(' | ')} |`,
    ...rows.map((row) => `| ${row.join(' | ')} |`),
  ].join('\n');
}

function countState(summary, state) {
  return summary.byLessonCoverageState[state] ?? 0;
}

function renderMarkdown(report) {
  const currentRows = TARGET_LEVELS.map((level) => {
    const row = report.currentLessons[level];
    return [
      level,
      row.chapters,
      row.lessons,
      row.targetChapters,
      row.targetLessons,
      row.additionalLessonsRecommended,
      `${row.primaryGrammarUnique}/${row.grammarTotal} (${row.primaryGrammarCoveragePct}%)`,
      `${row.vocabUnique}/${row.vocabTotal} (${row.vocabCoveragePct}%)`,
    ];
  });

  const coverageRows = TARGET_LEVELS.map((level) => {
    const summary = report.pdfLessonCoverage.summaryByLevel[level];
    return [
      level,
      summary.pdfRefs,
      countState(summary, 'official_seed'),
      countState(summary, 'partial_official_seed'),
      countState(summary, 'seed_candidate_only'),
      countState(summary, 'blueprint_only'),
      countState(summary, 'backlog_only'),
      summary.highPriorityGaps.length,
    ];
  });

  const priorityRows = Object.entries(report.derivedContracts.prioritySummary).map(([key, count]) => [key, count]);

  const highPriorityRows = TARGET_LEVELS.flatMap((level) =>
    report.pdfLessonCoverage.summaryByLevel[level].highPriorityGaps.slice(0, 12).map((row) => [
      level,
      row.pdfRef,
      row.titleKo,
      row.state,
      row.priorities.join(', ') || '-',
      row.waves.join(', ') || '-',
    ]),
  );

  return [
    `# N5/N4 PDF Curriculum Expansion Coverage Report - ${REPORT_DATE}`,
    '',
    '## Scope',
    '',
    'This report connects the paid local PDF reference set to HaruKoto-owned',
    'curriculum contracts and official lesson seeds. It stores only coverage',
    'metadata. Source explanations, examples, and question text from the PDFs must',
    'not be copied into HaruKoto lesson content.',
    '',
    'ASSUMPTION: The PDF files are coverage anchors only. New lessons must use',
    'newly authored dialogues, examples, prompts, and explanations.',
    '',
    'ASSUMPTION: The target expansion size is a planning baseline, not a launch',
    'commitment: N5 around 80 lessons and N4 around 90 lessons before claiming',
    'broad N5/N4 course coverage.',
    '',
    '## Source Check',
    '',
    table(
      ['Metric', 'Value'],
      [
        ['PDF directory', `\`${report.pdfSource.directory}\``],
        ['Inventory refs', report.pdfSource.inventoryRefs],
        ['PDF files found', report.pdfSource.filesFound],
        ['Total pages', report.pdfSource.totalPages],
        ['Missing inventory PDFs', report.pdfSource.missingPdfRefs.length],
        ['Extra PDF files', report.pdfSource.extraPdfRefs.length],
      ],
    ),
    '',
    'Page count distribution from the local PDF files:',
    '',
    table(
      ['Pages', 'PDF files'],
      Object.entries(report.pdfSource.pageCountSummary).map(([pages, count]) => [pages, count]),
    ),
    '',
    'Inventory level tags:',
    '',
    table(
      ['Level tag', 'PDF refs'],
      Object.entries(report.pdfSource.levelCounts).map(([level, count]) => [level, count]),
    ),
    '',
    'A PDF can carry multiple level tags, so N5 and N4 counts are coverage tags',
    'rather than mutually exclusive file counts.',
    '',
    '## Current Official Lesson Footprint',
    '',
    table(
      [
        'Level',
        'Current chapters',
        'Current lessons',
        'Target chapters',
        'Target lessons',
        'Additional lessons',
        'Primary grammar coverage',
        'Vocabulary coverage',
      ],
      currentRows,
    ),
    '',
    '## PDF-to-Lesson Coverage',
    '',
    'Official seed coverage means a topic already maps to a current lesson or to',
    'a grammar order used by current official lesson seeds. It does not replace',
    'human curriculum review, audio QA, or target-app playback gates.',
    '',
    table(
      [
        'Level',
        'PDF refs',
        'Official seed',
        'Partial official',
        'Seed candidate only',
        'Blueprint only',
        'Backlog only',
        'High-priority gaps',
      ],
      coverageRows,
    ),
    '',
    '## Existing Expansion Contracts',
    '',
    table(
      ['Contract', 'Rows'],
      [
        ['curriculum-topics.json', report.derivedContracts.topics],
        ['coverage-priorities.json', report.derivedContracts.coveragePriorities],
        ['lesson-draft-blueprints.json', report.derivedContracts.lessonDraftBlueprints],
        ['lesson-seed-candidates.json', report.derivedContracts.lessonSeedCandidates],
      ],
    ),
    '',
    'Priority queue summary:',
    '',
    table(['Priority / wave / status', 'Count'], priorityRows),
    '',
    '## First High-Priority Gap Slice',
    '',
    table(['Level', 'PDF ref', 'Topic', 'State', 'Priority', 'Wave'], highPriorityRows),
    '',
    '## Recommended Parallel Workstreams',
    '',
    '1. Source inventory refresh: verify every `pdfRef` still maps to one local PDF',
    '   and update only topic metadata, never copied examples.',
    '2. Coverage matrix closeout: split high-priority N5 gaps into official lesson',
    '   slots and decide which existing seed candidates can be promoted.',
    '3. N4 expansion architecture: grow N4 from pilot coverage into a full foundation',
    '   sequence before marketing it as covered.',
    '4. Candidate authoring: generate chapter-sized seed candidates in disjoint',
    '   files, then run candidate review and TTS readiness gates.',
    '5. Human review closeout: keep `lesson-human-review` and audio QA verdicts as',
    '   rollout gates, not as optional polish.',
    '',
    '## Reproduction',
    '',
    '```bash',
    'pnpm --filter @harukoto/database curriculum:lesson-expansion:report -- \\',
    '  --pdf-dir ~/Downloads/japanese \\',
    '  --markdown-output docs/operations/plans/n5-n4-pdf-curriculum-expansion-2026-05-26.md',
    '```',
    '',
  ].join('\n');
}

function writeOutput(filePath, contents) {
  const outputPath = resolve(REPO_ROOT, filePath);
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, contents);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const report = buildReport(args.pdfDir);

  if (args.jsonOutput) {
    writeOutput(args.jsonOutput, `${JSON.stringify(report, null, 2)}\n`);
  }

  if (args.markdownOutput) {
    writeOutput(args.markdownOutput, renderMarkdown(report));
  } else {
    console.log(JSON.stringify(report, null, 2));
  }
}

main();
