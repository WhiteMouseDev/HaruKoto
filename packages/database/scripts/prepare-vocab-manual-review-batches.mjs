import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const REVIEW_DIR = join(PACKAGE_DIR, 'data/vocabulary-reviewed');
const LEVEL = (process.argv[2] || '').toLowerCase();
const BATCH_SIZE = Number(process.argv[3] || 100);
const VERSION = (process.argv[4] || 'v2').toLowerCase();

if (!['n1', 'n2', 'n3'].includes(LEVEL)) {
  console.error('Usage: node packages/database/scripts/prepare-vocab-manual-review-batches.mjs <n1|n2|n3> [batchSize] [v1|v2]');
  process.exit(1);
}

if (!Number.isInteger(BATCH_SIZE) || BATCH_SIZE <= 0) {
  console.error('batchSize must be a positive integer');
  process.exit(1);
}

if (!['v1', 'v2'].includes(VERSION)) {
  console.error('version must be v1 or v2');
  process.exit(1);
}

const queueFile = join(REVIEW_DIR, `${LEVEL}-words-review-queue-${VERSION}.json`);
const queue = JSON.parse(readFileSync(queueFile, 'utf-8'));
if (!Array.isArray(queue)) {
  console.error(`Invalid queue file: ${queueFile}`);
  process.exit(1);
}

const outDir = join(REVIEW_DIR, 'manual-review', LEVEL, VERSION);
if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

const batches = [];
for (let i = 0; i < queue.length; i += BATCH_SIZE) {
  batches.push(queue.slice(i, i + BATCH_SIZE));
}

for (let i = 0; i < batches.length; i++) {
  const index = String(i + 1).padStart(4, '0');
  const file = join(outDir, `batch-${index}.json`);

  const payload = batches[i].map((item) => ({
    reviewId: `${LEVEL}-R-${String(item.rawOrder).padStart(5, '0')}`,
    key: item.key,
    rawOrder: item.rawOrder,
    word: item.raw.word,
    reading: item.raw.reading,
    meaningKo: item.raw.meaningKoClean,
    jlptLevel: item.raw.jlptLevel,
    issueCodes: item.issues.map((x) => x.code),
    issueDetails: item.issues,
    decision: 'PENDING',
    reviewer: null,
    reviewedAt: null,
    corrected: item.current
      ? {
          word: item.current.word,
          reading: item.current.reading,
          meaningKo: item.current.meaningKo,
          partOfSpeech: item.current.partOfSpeech,
          jlptLevel: item.current.jlptLevel,
          exampleSentence: item.current.exampleSentence,
          exampleReading: item.current.exampleReading,
          exampleTranslation: item.current.exampleTranslation,
          tags: item.current.tags,
          order: item.current.order,
        }
      : {
          word: item.raw.word,
          reading: item.raw.reading,
          meaningKo: item.raw.meaningKoClean,
          partOfSpeech: '',
          jlptLevel: item.raw.jlptLevel,
          exampleSentence: '',
          exampleReading: '',
          exampleTranslation: '',
          tags: [],
          order: item.rawOrder,
        },
    reviewerNotes: '',
  }));

  writeFileSync(file, `${JSON.stringify(payload, null, 2)}\n`, 'utf-8');
}

const manifest = {
  generatedAt: new Date().toISOString(),
  version: VERSION,
  level: LEVEL.toUpperCase(),
  sourceQueueFile: queueFile,
  totalItems: queue.length,
  batchSize: BATCH_SIZE,
  batchCount: batches.length,
  outDir,
  workflow: {
    step1: '각 batch-xxxx.json에서 decision을 PENDING -> APPROVED/REJECTED로 변경',
    step2: 'corrected 필드를 최종 값으로 수정',
    step3: 'compile-vocab-reviewed-final.mjs 실행',
  },
};

writeFileSync(join(outDir, '_manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf-8');

console.log(`✅ Manual review batches generated: ${LEVEL.toUpperCase()}`);
console.log(`- total: ${queue.length}`);
console.log(`- batch size: ${BATCH_SIZE}`);
console.log(`- batch count: ${batches.length}`);
console.log(`- out: ${outDir}`);
