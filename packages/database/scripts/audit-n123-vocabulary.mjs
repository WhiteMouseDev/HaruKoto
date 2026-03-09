import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data');
const RAW_DIR = join(DATA_DIR, 'raw');
const VOCAB_DIR = join(DATA_DIR, 'vocabulary');
const REVIEW_DIR = join(DATA_DIR, 'vocabulary-reviewed');

const LEVELS = ['n1', 'n2', 'n3'];
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

const READING_ALLOWED_RE = /^[\p{sc=Hiragana}\p{sc=Katakana}ー・\s、。？！「」『』（）()〜~…・\-]+$/u;
const KANJI_RE = /[\p{sc=Han}]/u;
const JAPANESE_RE = /[\p{sc=Hiragana}\p{sc=Katakana}\p{sc=Han}]/u;
const KOREAN_RE = /[가-힣]/;

const TEMPLATE_EXAMPLE_PATTERNS = [
  /^この問題では.+が重要なポイントになる。$/u,
  /^現場では早く.+ことが求められる。$/u,
  /^.+計画を見直す必要がある。$/u,
  /^提案は魅力的だ。.+、予算の確認が先だ。$/u,
  /^.+状況でも冷静に判断することが大切だ。$/u,
  /^ニュースで.+という言葉を聞いた。$/u,
  /^会議で.+の重要性が話題になった。$/u,
  /^実務では.+の知識が必要だ。$/u,
  /^.+の違いを比べてみよう。$/u,
  /^.+に関する資料を集めている。$/u,
  /^この本は.+をわかりやすく説明している。$/u,
  /^現場では正確に.+ことが求められる。$/u,
  /^まずは落ち着いて.+ことが大切だ。$/u,
  /^毎日少しずつ.+ようにしている。$/u,
  /^必要な情報を確認してから.+。$/u,
  /^この場面では慎重に.+べきだ。$/u,
  /^この問題は.+。$/u,
  /^その説明は.+と感じた。$/u,
  /^最近は天気が.+日が多い。$/u,
  /^.+説明では誤解が生まれる。$/u,
  /^.+対応が求められている。$/u,
  /^.+判断を避けるべきだ。$/u,
  /^.+、計画を見直すことにした。$/u,
  /^.+予定が変更された。$/u,
  /^.+事態は落ち着いた。$/u,
  /^.+結果を待つしかない。$/u,
  /^.+、別の案も検討しよう。$/u,
  /^.+、今は結論を急がない。$/u,
  /^彼に会うと、.+とあいさつする。$/u,
  /^.+は語の前について意味を加える。$/u,
  /^.+は語の後ろについて意味を加える。$/u,
  /^.+の使い方を復習した。$/u,
  /^.+の数え方を練習した。$/u,
];

const GENERIC_TRANSLATION_PATTERNS = [
  /^이 상황에서는 신중하게 판단해야 한다\.?$/u,
  /^매일 조금씩 연습하고 있다\.?$/u,
  /^필요한 정보를 확인한 뒤에 진행한다\.?$/u,
  /^그런 판단은 피해야 한다\.?$/u,
  /^그런 대응이 요구되고 있다\.?$/u,
  /^그런 설명은 오해를 낳는다\.?$/u,
  /^그 느낌이 .+고 느꼈다\.?$/u,
  /^그 상태는 .+\.?$/u,
];

function parseCsvLine(line) {
  const out = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];

    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (ch === ',' && !inQuotes) {
      out.push(current);
      current = '';
      continue;
    }

    current += ch;
  }

  out.push(current);
  return out.map((v) => v.trim());
}

function cleanMeaning(raw) {
  return raw
    .replace(/\[[^\]]+\]/g, '')
    .replace(/\s*[⇔＝⇒].*$/g, '')
    .replace(/\s+/g, ' ')
    .replace(/^[\s.·•]+|[\s.·•]+$/g, '')
    .trim();
}

function normalizeWhitespace(v) {
  return String(v ?? '').replace(/\s+/g, ' ').trim();
}

function loadRawLevel(level) {
  const dir = join(RAW_DIR, level);
  const csvFile = readdirSync(dir).find((f) => f.toLowerCase().endsWith('.csv'));
  if (!csvFile) throw new Error(`CSV file not found: ${dir}`);

  const full = join(dir, csvFile);
  const text = readFileSync(full, 'utf-8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = text.split('\n').filter((line) => line.trim().length > 0);

  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    if (cols.length < 4) continue;

    const reading = normalizeWhitespace(cols[0]);
    const word = normalizeWhitespace(cols[1]);
    const jlptLevel = normalizeWhitespace(cols[2]).toUpperCase();
    const meaningKoRaw = normalizeWhitespace(cols.slice(3).join(','));
    const meaningKo = cleanMeaning(meaningKoRaw);

    if (!word || !reading) continue;

    rows.push({
      rawIndex: i,
      word,
      reading,
      jlptLevel,
      meaningKoRaw,
      meaningKo,
      key: `${word}__${reading}__${jlptLevel}`,
    });
  }

  const dedupMap = new Map();
  for (const row of rows) {
    if (!dedupMap.has(row.key)) dedupMap.set(row.key, row);
  }

  const dedupRows = Array.from(dedupMap.values());
  return {
    sourceFile: full,
    rawCount: rows.length,
    dedupCount: dedupRows.length,
    duplicateCount: rows.length - dedupRows.length,
    rows: dedupRows,
  };
}

function loadExistingVocabLevel(level) {
  const canonical = `${level}-words.json`;
  const allFiles = readdirSync(VOCAB_DIR)
    .filter((name) => name.endsWith('.json'))
    .filter((name) => {
      if (level === 'n3') return /^n3-words.*\.json$/i.test(name);
      return new RegExp(`^${level}-words.*\\.json$`, 'i').test(name);
    })
    .sort();

  const files = allFiles.includes(canonical) ? [canonical] : allFiles;

  const list = [];
  const byKey = new Map();
  for (const file of files) {
    const full = join(VOCAB_DIR, file);
    const parsed = JSON.parse(readFileSync(full, 'utf-8'));
    if (!Array.isArray(parsed)) continue;

    for (const item of parsed) {
      const key = `${normalizeWhitespace(item.word)}__${normalizeWhitespace(item.reading)}__${normalizeWhitespace(item.jlptLevel).toUpperCase()}`;
      list.push({ ...item, _sourceFile: file, _key: key });
      if (!byKey.has(key)) byKey.set(key, { ...item, _sourceFile: file, _key: key });
    }
  }

  return {
    files,
    count: list.length,
    byKey,
  };
}

function inferLikelyPosFromRaw(raw) {
  const w = raw.word;
  const r = raw.reading;
  const m = raw.meaningKo;

  if (w.startsWith('-') || m.startsWith('-')) return 'SUFFIX';
  if (w.endsWith('-')) return 'PREFIX';
  if (w.endsWith('する') || r.endsWith('する') || /하다$/.test(m)) return 'VERB';
  if (w.endsWith('な') || r.endsWith('な')) return 'NA_ADJECTIVE';
  if (w.endsWith('い') && /[가-힣]+(한|스럽다|롭다|답다|같다)/.test(m)) return 'I_ADJECTIVE';
  if (/(공교롭게도|마침|매우|아주|곧|점점|이미|더욱|드디어)/.test(m)) return 'ADVERB';
  if (/(그러나|그리고|또는|한편|단|즉)/.test(m)) return 'CONJUNCTION';
  return null;
}

function hasTemplateSentence(sentence) {
  return TEMPLATE_EXAMPLE_PATTERNS.some((re) => re.test(sentence));
}

function isAllowedReading(text) {
  return READING_ALLOWED_RE.test(text);
}

function issue(code, severity, message) {
  return { code, severity, message };
}

function evaluateRecord(raw, existing) {
  const issues = [];

  if (!existing) {
    issues.push(issue('MISSING_ENRICHMENT', 'error', '가공 데이터가 존재하지 않아 수동 보강이 필요합니다.'));
    return { issues, approved: false };
  }

  const word = normalizeWhitespace(existing.word);
  const reading = normalizeWhitespace(existing.reading);
  const meaningKo = normalizeWhitespace(existing.meaningKo);
  const jlptLevel = normalizeWhitespace(existing.jlptLevel).toUpperCase();
  const partOfSpeech = normalizeWhitespace(existing.partOfSpeech);
  const exampleSentence = normalizeWhitespace(existing.exampleSentence);
  const exampleReading = normalizeWhitespace(existing.exampleReading);
  const exampleTranslation = normalizeWhitespace(existing.exampleTranslation);
  const tags = Array.isArray(existing.tags) ? existing.tags.map((t) => normalizeWhitespace(t)).filter(Boolean) : [];

  if (word !== raw.word) issues.push(issue('WORD_MISMATCH', 'error', `word 불일치: raw=${raw.word}, current=${word}`));
  if (reading !== raw.reading) issues.push(issue('READING_MISMATCH', 'error', `reading 불일치: raw=${raw.reading}, current=${reading}`));
  if (jlptLevel !== raw.jlptLevel) issues.push(issue('LEVEL_MISMATCH', 'error', `레벨 불일치: raw=${raw.jlptLevel}, current=${jlptLevel}`));

  if (!meaningKo) issues.push(issue('EMPTY_MEANING', 'error', 'meaningKo가 비어 있습니다.'));
  if (/[⇔＝⇒]/.test(meaningKo)) issues.push(issue('MEANING_REFERENCE_MARK', 'warn', 'meaningKo에 참조 기호가 남아 있습니다.'));

  if (!VALID_POS.has(partOfSpeech)) {
    issues.push(issue('INVALID_PART_OF_SPEECH', 'error', `partOfSpeech가 유효하지 않습니다: ${partOfSpeech}`));
  }

  const likelyPos = inferLikelyPosFromRaw(raw);
  if (likelyPos && likelyPos !== partOfSpeech) {
    issues.push(
      issue(
        'PART_OF_SPEECH_SUSPECT',
        'warn',
        `품사 의심: 추정=${likelyPos}, 현재=${partOfSpeech}`
      )
    );
  }

  if (!exampleSentence) issues.push(issue('EMPTY_EXAMPLE_SENTENCE', 'error', 'exampleSentence가 비어 있습니다.'));
  if (!exampleReading) issues.push(issue('EMPTY_EXAMPLE_READING', 'error', 'exampleReading이 비어 있습니다.'));
  if (!exampleTranslation) issues.push(issue('EMPTY_EXAMPLE_TRANSLATION', 'error', 'exampleTranslation이 비어 있습니다.'));

  if (exampleSentence && !exampleSentence.includes(raw.word)) {
    if (!['PREFIX', 'SUFFIX'].includes(partOfSpeech)) {
      issues.push(issue('EXAMPLE_MISSING_WORD', 'warn', '예문에 target word가 포함되지 않습니다.'));
    }
  }

  if (exampleReading && KANJI_RE.test(exampleReading)) {
    issues.push(issue('READING_HAS_KANJI', 'error', 'exampleReading에 한자가 포함되어 있습니다.'));
  }

  if (exampleReading && !isAllowedReading(exampleReading)) {
    issues.push(issue('READING_INVALID_CHARS', 'warn', 'exampleReading에 허용되지 않은 문자가 포함되어 있습니다.'));
  }

  if (exampleTranslation && JAPANESE_RE.test(exampleTranslation)) {
    issues.push(issue('TRANSLATION_HAS_JAPANESE', 'error', 'exampleTranslation에 일본어 문자가 포함되어 있습니다.'));
  }

  if (exampleTranslation && !KOREAN_RE.test(exampleTranslation)) {
    issues.push(issue('TRANSLATION_NO_KOREAN', 'error', 'exampleTranslation에서 한국어 문자를 찾을 수 없습니다.'));
  }

  if (exampleTranslation && GENERIC_TRANSLATION_PATTERNS.some((re) => re.test(exampleTranslation))) {
    issues.push(issue('GENERIC_TRANSLATION', 'warn', 'exampleTranslation이 과도하게 일반적인 템플릿입니다.'));
  }

  if (exampleSentence && hasTemplateSentence(exampleSentence)) {
    issues.push(issue('TEMPLATE_EXAMPLE', 'error', '예문이 템플릿 형태로 반복되어 콘텐츠 품질이 낮습니다.'));
  }

  if (!Array.isArray(existing.tags)) {
    issues.push(issue('TAGS_NOT_ARRAY', 'error', 'tags가 배열이 아닙니다.'));
  } else {
    if (tags.length === 0) issues.push(issue('TAGS_EMPTY', 'warn', 'tags가 비어 있습니다.'));
    if (tags.length > 3) issues.push(issue('TAGS_TOO_MANY', 'warn', 'tags 개수가 3개를 초과합니다.'));
  }

  if (tags.length > 0 && tags.every((t) => t === '생활' || t === '기본')) {
    issues.push(issue('TAGS_TOO_GENERIC', 'warn', 'tags가 지나치게 일반적입니다.'));
  }

  const hasError = issues.some((x) => x.severity === 'error');
  const hasWarn = issues.some((x) => x.severity === 'warn');
  const approved = !hasError && !hasWarn;

  return { issues, approved };
}

function summarizeIssues(records) {
  const summary = {};
  for (const rec of records) {
    for (const i of rec.issues) {
      summary[i.code] = (summary[i.code] || 0) + 1;
    }
  }
  return Object.fromEntries(Object.entries(summary).sort((a, b) => b[1] - a[1]));
}

function sortBySeverity(a, b) {
  const rank = { error: 0, warn: 1, info: 2 };
  const aRank = Math.min(...a.issues.map((x) => rank[x.severity] ?? 2));
  const bRank = Math.min(...b.issues.map((x) => rank[x.severity] ?? 2));
  if (aRank !== bRank) return aRank - bRank;
  return a.rawOrder - b.rawOrder;
}

function ensureDir(dir) {
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function createOutputFiles(level, report, approvedRows, reviewQueue) {
  ensureDir(REVIEW_DIR);

  const reportFile = join(REVIEW_DIR, `${level}-audit-report-v2.json`);
  const approvedFile = join(REVIEW_DIR, `${level}-words-reviewed-v2.json`);
  const queueFile = join(REVIEW_DIR, `${level}-words-review-queue-v2.json`);

  writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`, 'utf-8');
  writeFileSync(approvedFile, `${JSON.stringify(approvedRows, null, 2)}\n`, 'utf-8');
  writeFileSync(queueFile, `${JSON.stringify(reviewQueue, null, 2)}\n`, 'utf-8');

  return { reportFile, approvedFile, queueFile };
}

function runLevel(level) {
  const raw = loadRawLevel(level);
  const existing = loadExistingVocabLevel(level);

  const records = [];

  for (let i = 0; i < raw.rows.length; i++) {
    const r = raw.rows[i];
    const current = existing.byKey.get(r.key);
    const evaluated = evaluateRecord(r, current);

    const reviewItem = {
      rawOrder: i + 1,
      key: r.key,
      raw: {
        word: r.word,
        reading: r.reading,
        jlptLevel: r.jlptLevel,
        meaningKoRaw: r.meaningKoRaw,
        meaningKoClean: r.meaningKo,
      },
      current: current
        ? {
            word: current.word,
            reading: current.reading,
            meaningKo: current.meaningKo,
            partOfSpeech: current.partOfSpeech,
            jlptLevel: current.jlptLevel,
            exampleSentence: current.exampleSentence,
            exampleReading: current.exampleReading,
            exampleTranslation: current.exampleTranslation,
            tags: current.tags,
            order: current.order,
            sourceFile: current._sourceFile,
          }
        : null,
      qaStatus: evaluated.approved ? 'APPROVED_AUTO' : 'REVIEW_REQUIRED',
      issues: evaluated.issues,
    };

    records.push(reviewItem);
  }

  const sentenceCount = new Map();
  const translationCount = new Map();
  for (const rec of records) {
    if (!rec.current) continue;
    const sentence = normalizeWhitespace(rec.current.exampleSentence);
    const translation = normalizeWhitespace(rec.current.exampleTranslation);
    if (sentence) sentenceCount.set(sentence, (sentenceCount.get(sentence) || 0) + 1);
    if (translation) translationCount.set(translation, (translationCount.get(translation) || 0) + 1);
  }

  for (const rec of records) {
    if (!rec.current) continue;
    const sentence = normalizeWhitespace(rec.current.exampleSentence);
    const translation = normalizeWhitespace(rec.current.exampleTranslation);

    if (sentence && (sentenceCount.get(sentence) || 0) >= 5) {
      rec.issues.push(issue('DUPLICATE_EXAMPLE_SENTENCE', 'warn', '동일 exampleSentence가 과도하게 반복됩니다.'));
    }
    if (translation && (translationCount.get(translation) || 0) >= 5) {
      rec.issues.push(
        issue('DUPLICATE_EXAMPLE_TRANSLATION', 'warn', '동일 exampleTranslation이 과도하게 반복됩니다.')
      );
    }

    const hasError = rec.issues.some((x) => x.severity === 'error');
    const hasWarn = rec.issues.some((x) => x.severity === 'warn');
    rec.qaStatus = !hasError && !hasWarn ? 'APPROVED_AUTO' : 'REVIEW_REQUIRED';
  }

  const approvedRows = records
    .filter((r) => r.qaStatus === 'APPROVED_AUTO' && r.current)
    .map((r, idx) => ({
      word: r.current.word,
      reading: r.current.reading,
      meaningKo: r.current.meaningKo,
      partOfSpeech: r.current.partOfSpeech,
      jlptLevel: r.current.jlptLevel,
      exampleSentence: r.current.exampleSentence,
      exampleReading: r.current.exampleReading,
      exampleTranslation: r.current.exampleTranslation,
      tags: Array.isArray(r.current.tags) ? r.current.tags : [],
      order: idx + 1,
    }));

  const reviewQueue = records.filter((r) => r.qaStatus !== 'APPROVED_AUTO').sort(sortBySeverity);
  const topRepeatedSentences = Array.from(sentenceCount.entries())
    .filter(([, count]) => count >= 5)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([text, count]) => ({ text, count }));
  const topRepeatedTranslations = Array.from(translationCount.entries())
    .filter(([, count]) => count >= 5)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([text, count]) => ({ text, count }));

  const report = {
    generatedAt: new Date().toISOString(),
    level: level.toUpperCase(),
    source: {
      rawCsv: raw.sourceFile,
      rawCount: raw.rawCount,
      rawDedupCount: raw.dedupCount,
      rawDuplicateCount: raw.duplicateCount,
      existingFiles: existing.files,
      existingCount: existing.count,
    },
    result: {
      approvedAutoCount: approvedRows.length,
      reviewRequiredCount: reviewQueue.length,
      coverageAgainstRawPercent: Number(((approvedRows.length / raw.dedupCount) * 100).toFixed(2)),
    },
    issueSummary: summarizeIssues(records),
    repetition: {
      repeatedSentenceKinds: topRepeatedSentences.length,
      repeatedTranslationKinds: topRepeatedTranslations.length,
      topRepeatedSentences,
      topRepeatedTranslations,
    },
    gate: {
      strictMode: 'error or warn 존재 시 APPROVED 제외',
      originalDataUnchanged: true,
      outputFilesAreSeparatedFromSeedingPath: true,
    },
  };

  const files = createOutputFiles(level, report, approvedRows, reviewQueue);

  return {
    level: level.toUpperCase(),
    report,
    files,
  };
}

function main() {
  const results = LEVELS.map((level) => runLevel(level));
  console.log('✅ N1/N2/N3 vocabulary quality audit complete');
  for (const r of results) {
    const s = r.report;
    console.log(
      `- ${r.level}: approved=${s.result.approvedAutoCount}, review=${s.result.reviewRequiredCount}, coverage=${s.result.coverageAgainstRawPercent}%`
    );
    console.log(`  report: ${r.files.reportFile}`);
    console.log(`  approved: ${r.files.approvedFile}`);
    console.log(`  review-queue: ${r.files.queueFile}`);
  }
}

main();
