import { existsSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const REVIEW_DIR = join(PACKAGE_DIR, 'data/vocabulary-reviewed');
const LEVEL = (process.argv[2] || '').toLowerCase();
const VERSION = (process.argv[3] || 'v2').toLowerCase();

if (!['n1', 'n2', 'n3'].includes(LEVEL)) {
  console.error('Usage: node packages/database/scripts/compile-vocab-reviewed-final.mjs <n1|n2|n3> [v1|v2]');
  process.exit(1);
}

if (!['v1', 'v2'].includes(VERSION)) {
  console.error('version must be v1 or v2');
  process.exit(1);
}

const VALID_POS = new Set([
  'NOUN',
  'VERB',
  'I_ADJECTIVE',
  'NA_ADJECTIVE',
  'ADVERB',
  'PARTICLE',
  'CONJUNCTION',
  'COUNTER',
  'EXPRESSION',
  'PREFIX',
  'SUFFIX',
]);

function normalize(v) {
  return String(v ?? '').replace(/\s+/g, ' ').trim();
}

function validateCorrected(v) {
  const errors = [];

  if (!normalize(v.word)) errors.push('word empty');
  if (!normalize(v.reading)) errors.push('reading empty');
  if (!normalize(v.meaningKo)) errors.push('meaningKo empty');
  if (!VALID_POS.has(normalize(v.partOfSpeech))) errors.push(`invalid partOfSpeech: ${v.partOfSpeech}`);
  if (!['N1', 'N2', 'N3'].includes(normalize(v.jlptLevel).toUpperCase())) errors.push(`invalid jlptLevel: ${v.jlptLevel}`);
  if (!normalize(v.exampleSentence)) errors.push('exampleSentence empty');
  if (!normalize(v.exampleReading)) errors.push('exampleReading empty');
  if (!normalize(v.exampleTranslation)) errors.push('exampleTranslation empty');
  if (!Array.isArray(v.tags)) errors.push('tags not array');

  return errors;
}

const approvedAutoFile = join(REVIEW_DIR, `${LEVEL}-words-reviewed-${VERSION}.json`);
const approvedAuto = JSON.parse(readFileSync(approvedAutoFile, 'utf-8'));
if (!Array.isArray(approvedAuto)) {
  console.error(`Invalid approved file: ${approvedAutoFile}`);
  process.exit(1);
}

const manualDir = join(REVIEW_DIR, 'manual-review', LEVEL, VERSION);
const manualFiles = existsSync(manualDir)
  ? readdirSync(manualDir).filter((f) => /^batch-\d+\.json$/.test(f)).sort()
  : [];

const merged = [];
const keySet = new Set();
const manualStats = {
  batchFiles: manualFiles.length,
  rows: 0,
  approved: 0,
  rejected: 0,
  pending: 0,
  invalidApprovedRows: 0,
};

for (const row of approvedAuto) {
  const key = `${normalize(row.word)}__${normalize(row.reading)}__${normalize(row.jlptLevel).toUpperCase()}`;
  if (!keySet.has(key)) {
    keySet.add(key);
    merged.push({ ...row, order: merged.length + 1 });
  }
}

for (const file of manualFiles) {
  const full = join(manualDir, file);
  const rows = JSON.parse(readFileSync(full, 'utf-8'));
  if (!Array.isArray(rows)) continue;

  for (const r of rows) {
    manualStats.rows += 1;
    const decision = normalize(r.decision).toUpperCase();

    if (decision === 'PENDING' || !decision) {
      manualStats.pending += 1;
      continue;
    }

    if (decision === 'REJECTED') {
      manualStats.rejected += 1;
      continue;
    }

    if (decision !== 'APPROVED') {
      manualStats.pending += 1;
      continue;
    }

    const corrected = r.corrected || {};
    const errors = validateCorrected(corrected);
    if (errors.length > 0) {
      manualStats.invalidApprovedRows += 1;
      continue;
    }

    const key = `${normalize(corrected.word)}__${normalize(corrected.reading)}__${normalize(corrected.jlptLevel).toUpperCase()}`;
    if (keySet.has(key)) continue;

    keySet.add(key);
    merged.push({
      word: corrected.word,
      reading: corrected.reading,
      meaningKo: corrected.meaningKo,
      partOfSpeech: corrected.partOfSpeech,
      jlptLevel: corrected.jlptLevel,
      exampleSentence: corrected.exampleSentence,
      exampleReading: corrected.exampleReading,
      exampleTranslation: corrected.exampleTranslation,
      tags: corrected.tags,
      order: merged.length + 1,
    });
    manualStats.approved += 1;
  }
}

const outFile = join(REVIEW_DIR, `${LEVEL}-words-reviewed-final-${VERSION}.json`);
const reportFile = join(REVIEW_DIR, `${LEVEL}-words-reviewed-final-report-${VERSION}.json`);

const report = {
  generatedAt: new Date().toISOString(),
  version: VERSION,
  level: LEVEL.toUpperCase(),
  source: {
    approvedAutoFile,
    approvedAutoCount: approvedAuto.length,
    manualDir,
    manualFiles,
  },
  manualStats,
  output: {
    mergedCount: merged.length,
    outFile,
  },
};

writeFileSync(outFile, `${JSON.stringify(merged, null, 2)}\n`, 'utf-8');
writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`, 'utf-8');

console.log(`✅ Final reviewed file compiled: ${LEVEL.toUpperCase()}`);
console.log(`- merged count: ${merged.length}`);
console.log(`- out: ${outFile}`);
console.log(`- report: ${reportFile}`);
