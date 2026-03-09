import { existsSync, readFileSync, readdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = join(SCRIPT_DIR, '..');
const DATA_DIR = join(PACKAGE_DIR, 'data');
const RAW_DIR = join(DATA_DIR, 'raw');
const REVIEWED_DIR = join(DATA_DIR, 'vocabulary-reviewed');

const argLevel = (process.argv[2] || 'all').toLowerCase();
const LEVELS = argLevel === 'all' ? ['n1', 'n2', 'n3'] : [argLevel];

if (!LEVELS.every((x) => ['n1', 'n2', 'n3'].includes(x))) {
  console.error('Usage: node packages/database/scripts/recorrect-priority-vocab-v3.mjs <all|n1|n2|n3>');
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

const JAPANESE_RE = /[\p{sc=Hiragana}\p{sc=Katakana}\p{sc=Han}]/u;
const KANJI_RE = /[\p{sc=Han}]/u;
const KOREAN_RE = /[가-힣]/;

const CONJUNCTION_WORDS = new Set([
  'しかし',
  'ところが',
  'または',
  'ただし',
  'しかも',
  'それに',
  'なお',
  'だが',
  'けれども',
  'けれど',
  'あるいは',
  'また',
  'そして',
  '一方',
  'すなわち',
  'つまり',
  '若しくは',
  'ないし',
  'でも',
]);

const ADVERB_WORDS = new Set([
  'あいにく',
  'あくまで',
  'いずれ',
  'しばしば',
  'やがて',
  'かなり',
  'どうやら',
  '相変わらず',
  'ひょっとして',
  'たまたま',
  'ついに',
  'おおよそ',
  '恐らく',
  '早速',
  '直ちに',
  'しっかり',
  'はっきり',
  'ゆっくり',
  'じっと',
]);

const KO_ADVERB_HINTS = new Set([
  '공교롭게도',
  '마침',
  '어쩐지',
  '어딘지',
  '아무래도',
  '아마',
  '변함없이',
  '여전히',
  '우연히',
  '드디어',
  '마침내',
  '점점',
  '자주',
  '곧',
  '즉시',
  '바로',
  '대강',
  '대략',
  '대체로',
  '언젠가',
  '결코',
  '역시',
  '또한',
]);

const KO_CONJ_HINTS = new Set([
  '그러나',
  '하지만',
  '또는',
  '혹은',
  '즉',
  '게다가',
  '한편',
  '다만',
  '그래도',
  '그리고',
  '내지',
]);

const LOW_INFO_TRANSLATION_RES = [
  /에 대해 선생님께 질문했다/u,
  /동작을 하기로 했다/u,
  /준비를 진행했다/u,
  /할 수 있는 역량이 필요하다/u,
  /태도가 높이 평가된다/u,
  /정확히 다루는 능력이 요구된다/u,
];

const TAG_RULES = [
  { tag: '사람', keys: ['사람', '인물', '인간', '친구', '고객', '교사', '학생'] },
  { tag: '가족', keys: ['가족', '부모', '형', '누나', '언니', '동생', '아들', '딸'] },
  { tag: '감정', keys: ['감정', '기분', '애정', '분노', '기쁨', '슬픔', '불안', '초조'] },
  { tag: '건강', keys: ['건강', '병', '치료', '약', '통증', '창백'] },
  { tag: '음식', keys: ['음식', '식사', '요리', '맛', '먹', '마시', '튀기'] },
  { tag: '시간', keys: ['시간', '시기', '새벽', '아침', '밤', '월', '연도', '생년월일'] },
  { tag: '장소', keys: ['장소', '지역', '도시', '마을', '근처', '자리', '건물', '학교'] },
  { tag: '교통', keys: ['교통', '열차', '기차', '버스', '운전', '도로', '역'] },
  { tag: '학교', keys: ['학교', '학생', '교사', '시험', '수업', '학기', '교실'] },
  { tag: '직장', keys: ['직장', '회사', '업무', '근무', '사원', '월급', '경비'] },
  { tag: '비즈니스', keys: ['비즈니스', '계약', '협상', '거래', '회의', '보고서', '안건'] },
  { tag: '경제', keys: ['경제', '적자', '흑자', '금리', '투자', '시장', '물가', '경비'] },
  { tag: '정치', keys: ['정치', '정부', '선거', '정책', '외교', '의회'] },
  { tag: '문화', keys: ['문화', '예술', '전통', '종교', '축제', '문학'] },
  { tag: '기술', keys: ['기술', '시스템', '기계', '데이터', '정보'] },
  { tag: '생활', keys: ['일상', '생활', '습관', '규칙', '가정', '집안'] },
  { tag: '문법', keys: ['접두', '접미', '조사', '문법', '표현', '어휘', '동사', '형용사'] },
];

function normalize(v) {
  return String(v ?? '').replace(/\s+/g, ' ').trim();
}

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
  return out.map((x) => x.trim());
}

function cleanMeaning(raw) {
  return normalize(raw)
    .replace(/[\uFEFF]/g, '')
    .replace(/\[[^\]]+\]/g, '')
    .replace(/\s*[⇔＝⇒].*$/g, '')
    .replace(/\(\d+[A-Z]?\)\s*/g, '')
    .replace(/[·•]/g, '. ')
    .replace(/\s+/g, ' ')
    .replace(/\s*([.,;:])\s*/g, '$1 ')
    .replace(/\s+/g, ' ')
    .replace(/^[\s.,;:]+|[\s.,;:]+$/g, '')
    .trim();
}

function fixUnbalancedParentheses(text) {
  let s = normalize(text);
  let balance = 0;
  let out = '';
  for (const ch of s) {
    if (ch === '(') {
      balance += 1;
      out += ch;
      continue;
    }
    if (ch === ')') {
      if (balance === 0) continue;
      balance -= 1;
      out += ch;
      continue;
    }
    out += ch;
  }
  if (balance > 0) {
    out = out.replace(/\(+$/g, '');
  }
  return out.trim();
}

function primaryMeaning(meaning) {
  const cleaned = fixUnbalancedParentheses(cleanMeaning(meaning));
  const normalized = cleaned
    .replace(/…/g, '')
    .replace(/\s+/g, ' ')
    .replace(/\s*([.,;:])\s*/g, '$1 ')
    .replace(/\s+/g, ' ')
    .trim();
  const parts = normalized
    .split(/[.;。]/)
    .map((x) => x.trim())
    .filter(Boolean);
  const head = parts[0] || normalized;
  return head.replace(/^[,;:]+|[,;:]+$/g, '').trim();
}

function stripJapanese(text) {
  return normalize(text).replace(/[\p{sc=Hiragana}\p{sc=Katakana}\p{sc=Han}]/gu, '').trim();
}

function koMeaningForTranslation(text) {
  let s = stripJapanese(text)
    .replace(/[ー→←⇒⇔=]/g, ' ')
    .replace(/[‘’“”"'「」『』]/g, '')
    .replace(/^\s*의\s+/u, '')
    .replace(/\s+/g, ' ')
    .replace(/^[,.;:]+|[,.;:]+$/g, '')
    .trim();
  if (!s) s = '관련 의미';
  return s;
}

function isAllKanaOrKatakana(text) {
  return /^[\p{sc=Hiragana}\p{sc=Katakana}ー・]+$/u.test(normalize(text));
}

function hasKoreanToken(text, tokenSet) {
  const tokens = normalize(text).split(/[.,;·•\s]+/).map((x) => x.trim()).filter(Boolean);
  return tokens.some((t) => tokenSet.has(t));
}

function stripParen(text) {
  return normalize(text).replace(/\([^)]*\)/g, ' ').replace(/\s+/g, ' ').trim();
}

function isConjunctionHead(meaningHead) {
  const h = stripParen(meaningHead);
  if (!h) return false;
  if (KO_CONJ_HINTS.has(h)) return true;
  return /^(그러나|하지만|또는|혹은|즉|게다가|한편|다만|그래도|그리고|내지)([.,\s]|$)/.test(h);
}

function isAdverbHead(meaningHead) {
  const h = stripParen(meaningHead);
  if (!h) return false;
  if (KO_ADVERB_HINTS.has(h)) return true;
  if (/^(변함없이|여전히|우연히|드디어|마침내|점점|자주|곧|즉시|바로|대강|대략|대체로|결코|어쩐지|어딘지|아무래도|아마|공교롭게도|언젠가)([.,\s]|$)/.test(h)) {
    return true;
  }
  if (/(게|히|없이|도록)$/.test(h) && h.length <= 8) return true;
  return false;
}

function inferPos(word, reading, meaningKo, currentPos) {
  const w = normalize(word);
  const r = normalize(reading);
  const m = primaryMeaning(meaningKo);
  const mAll = normalize(meaningKo);
  const wordVerbEnding = /[うくぐすつぬぶむる]$/.test(w);
  const readVerbEnding = /[うくぐすつぬぶむる]$/.test(r);

  if (w.startsWith('-') || m.startsWith('-')) return 'SUFFIX';
  if (w.endsWith('-')) return 'PREFIX';

  if (CONJUNCTION_WORDS.has(w) || CONJUNCTION_WORDS.has(r)) return 'CONJUNCTION';
  if (ADVERB_WORDS.has(w) || ADVERB_WORDS.has(r)) return 'ADVERB';

  if (/(격조사|접속조사|보조사|종조사|부조사|조사\s*\(|조사$)/.test(m)) return 'PARTICLE';
  if (/인사|감탄|관용/.test(m)) return 'EXPRESSION';

  if (/([0-9]+|몇).*(개|명|번|회|층|잔|마리|권)/.test(m)) return 'COUNTER';

  if (currentPos === 'I_ADJECTIVE') return 'I_ADJECTIVE';
  if (currentPos === 'NA_ADJECTIVE' && (w.endsWith('な') || r.endsWith('な') || /한$/.test(m))) return 'NA_ADJECTIVE';

  if (w.endsWith('する') || r.endsWith('する')) return 'VERB';

  if (w.endsWith('な') || r.endsWith('な')) return 'NA_ADJECTIVE';

  if (
    (w.endsWith('い') || r.endsWith('い')) &&
    /(하다|스럽다|롭다|답다|같다|어렵다|쉽다|나다|있다|없다)$/.test(m)
  ) {
    return 'I_ADJECTIVE';
  }

  if (
    /다$/.test(m) &&
    (currentPos === 'VERB' || readVerbEnding || wordVerbEnding)
  ) {
    return 'VERB';
  }

  if (currentPos === 'VERB' && /(ます|です)$/.test(w + r)) return 'VERB';

  if (/(하다|되다|지다|맞다|들다|나다|오다|가다|보다|놓다|키다|끄다|먹다|마시다|앉다|서다|살다|죽다)$/.test(m)) {
    return 'VERB';
  }

  if (currentPos === 'ADVERB' && isAdverbHead(m)) return 'ADVERB';
  if (currentPos === 'CONJUNCTION' && isConjunctionHead(m)) return 'CONJUNCTION';

  if (isAdverbHead(m) && isAllKanaOrKatakana(w)) return 'ADVERB';
  if (isConjunctionHead(m) && isAllKanaOrKatakana(w)) return 'CONJUNCTION';

  if (currentPos === 'ADVERB') {
    if (isAllKanaOrKatakana(w) && (hasKoreanToken(mAll, KO_ADVERB_HINTS) || /(히|게|없이|마침내)$/.test(m))) {
      return 'ADVERB';
    }
  }

  if (currentPos === 'CONJUNCTION' && hasKoreanToken(mAll, KO_CONJ_HINTS) && isConjunctionHead(m)) {
    return 'CONJUNCTION';
  }

  return 'NOUN';
}

function inferTags(meaningKo, pos) {
  const m = normalize(meaningKo);
  const out = [];
  for (const rule of TAG_RULES) {
    if (rule.keys.some((k) => m.includes(k))) {
      out.push(rule.tag);
    }
    if (out.length >= 2) break;
  }

  if (out.length > 0) return out;

  if (pos === 'VERB') return ['동작', '기본'];
  if (pos === 'I_ADJECTIVE' || pos === 'NA_ADJECTIVE') return ['상태', '기본'];
  if (['PARTICLE', 'CONJUNCTION', 'PREFIX', 'SUFFIX', 'COUNTER', 'EXPRESSION', 'ADVERB'].includes(pos)) {
    return ['문법'];
  }
  return ['기본'];
}

function hashIndex(seed, len) {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return Math.abs(h >>> 0) % len;
}

function exampleByPos(pos, word, reading, meaning) {
  const m = koMeaningForTranslation(meaning);

  const table = {
    NOUN: [
      {
        j: `辞書で${word}という語の意味を確認した。`,
        r: `じしょで${reading}というごのいみをかくにんした。`,
        k: `사전에서 '${m}'라는 어휘의 의미를 확인했다.`,
      },
      {
        j: `授業で${word}という語彙を学んだ。`,
        r: `じゅぎょうで${reading}というごいをまなんだ。`,
        k: `수업에서 '${m}'라는 어휘를 배웠다.`,
      },
      {
        j: `ノートに${word}の使い方をまとめた。`,
        r: `のーとに${reading}のつかいかたをまとめた。`,
        k: `노트에 '${m}'의 쓰임을 정리했다.`,
      },
    ],
    VERB: [
      {
        j: `例文で「${word}」という動詞の使い方を確認した。`,
        r: `れいぶんで「${reading}」というどうしのつかいかたをかくにんした。`,
        k: `예문에서 '${m}' 동사의 쓰임을 확인했다.`,
      },
      {
        j: `授業で「${word}」という動詞を練習した。`,
        r: `じゅぎょうで「${reading}」というどうしをれんしゅうした。`,
        k: `수업에서 '${m}' 동사를 연습했다.`,
      },
      {
        j: `辞書で「${word}」の活用を調べた。`,
        r: `じしょで「${reading}」のかつようをしらべた。`,
        k: `사전에서 '${m}' 동사의 활용을 찾아봤다.`,
      },
    ],
    I_ADJECTIVE: [
      {
        j: `「${word}」という形容詞の使い方を学んだ。`,
        r: `「${reading}」というけいようしのつかいかたをまなんだ。`,
        k: `'${m}' 형용사의 쓰임을 익혔다.`,
      },
      {
        j: `例文で「${word}」という形容詞を確認した。`,
        r: `れいぶんで「${reading}」というけいようしをかくにんした。`,
        k: `예문에서 '${m}' 형용사를 확인했다.`,
      },
      {
        j: `ノートに「${word}」の意味と用法を整理した。`,
        r: `のーとに「${reading}」のいみとようほうをせいりした。`,
        k: `노트에 '${m}' 형용사의 의미와 용법을 정리했다.`,
      },
    ],
    NA_ADJECTIVE: [
      {
        j: `「${word}」という形容動詞の使い方を学んだ。`,
        r: `「${reading}」というけいようどうしのつかいかたをまなんだ。`,
        k: `'${m}' 형용동사의 쓰임을 익혔다.`,
      },
      {
        j: `例文で「${word}」という形容動詞を確認した。`,
        r: `れいぶんで「${reading}」というけいようどうしをかくにんした。`,
        k: `예문에서 '${m}' 형용동사를 확인했다.`,
      },
      {
        j: `ノートに「${word}」の用法をまとめた。`,
        r: `のーとに「${reading}」のようほうをまとめた。`,
        k: `노트에 '${m}' 형용동사의 용법을 정리했다.`,
      },
    ],
    ADVERB: [
      {
        j: `文の中で「${word}」という副詞の位置を確認した。`,
        r: `ぶんのなかで「${reading}」というふくしのいちをかくにんした。`,
        k: `문장 속에서 '${m}' 부사의 위치를 확인했다.`,
      },
      {
        j: `例文で「${word}」という副詞の使い方を練習した。`,
        r: `れいぶんで「${reading}」というふくしのつかいかたをれんしゅうした。`,
        k: `예문에서 '${m}' 부사의 쓰임을 연습했다.`,
      },
      {
        j: `会話練習で「${word}」を自然に使う練習をした。`,
        r: `かいわれんしゅうで「${reading}」をしぜんにつかうれんしゅうをした。`,
        k: `회화 연습에서 '${m}' 부사를 자연스럽게 쓰는 연습을 했다.`,
      },
    ],
    CONJUNCTION: [
      {
        j: `文章練習で「${word}」という接続詞を使った。`,
        r: `ぶんしょうれんしゅうで「${reading}」というせつぞくしをつかった。`,
        k: `문장 연습에서 '${m}' 접속사를 사용했다.`,
      },
      {
        j: `「${word}」を使って二つの文をつないだ。`,
        r: `「${reading}」をつかってふたつのぶんをつないだ。`,
        k: ` '${m}' 접속사를 사용해 두 문장을 연결했다.`,
      },
      {
        j: `授業で「${word}」という接続表現を復習した。`,
        r: `じゅぎょうで「${reading}」というせつぞくひょうげんをふくしゅうした。`,
        k: `수업에서 '${m}' 접속 표현을 복습했다.`,
      },
    ],
    PARTICLE: [
      {
        j: `文法問題で「${word}」という助詞の用法を復習した。`,
        r: `ぶんぽうもんだいで「${reading}」というじょしのようほうをふくしゅうした。`,
        k: `문법 문제에서 '${m}' 조사 용법을 복습했다.`,
      },
      {
        j: `例文で「${word}」の使い分けを確認した。`,
        r: `れいぶんで「${reading}」のつかいわけをかくにんした。`,
        k: `예문에서 '${m}' 조사의 구분 사용을 확인했다.`,
      },
      {
        j: `授業で「${word}」の位置に注意して練習した。`,
        r: `じゅぎょうで「${reading}」のいちにちゅういしてれんしゅうした。`,
        k: `수업에서 '${m}' 조사의 위치에 주의하며 연습했다.`,
      },
    ],
    COUNTER: [
      {
        j: `買い物の例文で「${word}」という助数詞を練習した。`,
        r: `かいもののれいぶんで「${reading}」というじょすうしをれんしゅうした。`,
        k: `쇼핑 예문에서 '${m}' 조수사 표현을 연습했다.`,
      },
      {
        j: `「${word}」を使った数え方を確認した。`,
        r: `「${reading}」をつかったかぞえかたをかくにんした。`,
        k: ` '${m}' 조수사를 활용한 세는 법을 확인했다.`,
      },
      {
        j: `授業で「${word}」の数え方を復習した。`,
        r: `じゅぎょうで「${reading}」のかぞえかたをふくしゅうした。`,
        k: `수업에서 '${m}' 조수사의 세는 법을 복습했다.`,
      },
    ],
    EXPRESSION: [
      {
        j: `会話練習で「${word}」という表現を使った。`,
        r: `かいわれんしゅうで「${reading}」というひょうげんをつかった。`,
        k: `회화 연습에서 '${m}' 표현을 사용했다.`,
      },
      {
        j: `例文で「${word}」のニュアンスを確認した。`,
        r: `れいぶんで「${reading}」のにゅあんすをかくにんした。`,
        k: `예문에서 '${m}' 표현의 뉘앙스를 확인했다.`,
      },
      {
        j: `授業で「${word}」の丁寧さの違いを学んだ。`,
        r: `じゅぎょうで「${reading}」のていねいさのちがいをまなんだ。`,
        k: `수업에서 '${m}' 표현의 공손도 차이를 배웠다.`,
      },
    ],
    PREFIX: [
      {
        j: `語彙学習で接頭語「${word}」の働きを確認した。`,
        r: `ごいがくしゅうでせっとうご「${reading}」のはたらきをかくにんした。`,
        k: `어휘 학습에서 접두어 '${m}'의 기능을 확인했다.`,
      },
      {
        j: `「${word}」が語の前で果たす役割を学んだ。`,
        r: `「${reading}」がごのまえではたすやくわりをまなんだ。`,
        k: ` '${m}'가 단어 앞에서 하는 역할을 배웠다.`,
      },
      {
        j: `例文で接頭語「${word}」の使い方を練習した。`,
        r: `れいぶんでせっとうご「${reading}」のつかいかたをれんしゅうした。`,
        k: `예문에서 접두어 '${m}'의 쓰임을 연습했다.`,
      },
    ],
    SUFFIX: [
      {
        j: `語彙学習で接尾語「${word}」の働きを確認した。`,
        r: `ごいがくしゅうでせつびご「${reading}」のはたらきをかくにんした。`,
        k: `어휘 학습에서 접미어 '${m}'의 기능을 확인했다.`,
      },
      {
        j: `「${word}」が語の後ろで果たす役割を学んだ。`,
        r: `「${reading}」がごのうしろではたすやくわりをまなんだ。`,
        k: ` '${m}'가 단어 뒤에서 하는 역할을 배웠다.`,
      },
      {
        j: `例文で接尾語「${word}」の使い方を練習した。`,
        r: `れいぶんでせつびご「${reading}」のつかいかたをれんしゅうした。`,
        k: `예문에서 접미어 '${m}'의 쓰임을 연습했다.`,
      },
    ],
  };

  const list = table[pos] || table.NOUN;
  const idx = hashIndex(`${word}__${reading}__${pos}__${m}`, list.length);
  return list[idx];
}

function loadRawMap(level) {
  const dir = join(RAW_DIR, level);
  const csvFile = readdirSync(dir).find((x) => x.toLowerCase().endsWith('.csv'));
  if (!csvFile) throw new Error(`raw csv not found: ${dir}`);

  const full = join(dir, csvFile);
  const text = readFileSync(full, 'utf-8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = text.split('\n').filter((line) => line.trim().length > 0);
  const map = new Map();

  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    if (cols.length < 4) continue;
    const reading = normalize(cols[0]);
    const word = normalize(cols[1]);
    const jlptLevel = normalize(cols[2]).toUpperCase();
    const meaningKo = cleanMeaning(cols.slice(3).join(','));
    if (!word || !reading || !jlptLevel) continue;
    const key = `${word}__${reading}__${jlptLevel}`;
    if (!map.has(key)) map.set(key, meaningKo);
  }

  return map;
}

function loadV2(level) {
  const file = join(REVIEWED_DIR, `${level}-words-reviewed-final-v2.json`);
  if (!existsSync(file)) {
    throw new Error(`v2 file not found: ${file}`);
  }
  const rows = JSON.parse(readFileSync(file, 'utf-8'));
  if (!Array.isArray(rows)) throw new Error(`invalid json: ${file}`);
  return { file, rows };
}

function validateRows(rows) {
  const errors = [];
  const keySet = new Set();

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const key = `${normalize(r.word)}__${normalize(r.reading)}__${normalize(r.jlptLevel).toUpperCase()}`;
    if (keySet.has(key)) errors.push(`duplicate key: ${key}`);
    keySet.add(key);

    if (!normalize(r.word)) errors.push(`row ${i + 1}: empty word`);
    if (!normalize(r.reading)) errors.push(`row ${i + 1}: empty reading`);
    if (!normalize(r.meaningKo)) errors.push(`row ${i + 1}: empty meaningKo`);
    if (!VALID_POS.has(normalize(r.partOfSpeech))) errors.push(`row ${i + 1}: invalid POS ${r.partOfSpeech}`);
    if (!normalize(r.exampleSentence)) errors.push(`row ${i + 1}: empty exampleSentence`);
    if (!normalize(r.exampleReading)) errors.push(`row ${i + 1}: empty exampleReading`);
    if (!normalize(r.exampleTranslation)) errors.push(`row ${i + 1}: empty exampleTranslation`);
    if (!Array.isArray(r.tags) || r.tags.length === 0) errors.push(`row ${i + 1}: invalid tags`);
    if (KANJI_RE.test(normalize(r.exampleReading))) errors.push(`row ${i + 1}: kanji in exampleReading`);
    if (JAPANESE_RE.test(normalize(r.exampleTranslation))) errors.push(`row ${i + 1}: japanese in exampleTranslation`);
    if (!KOREAN_RE.test(normalize(r.exampleTranslation))) errors.push(`row ${i + 1}: no korean in exampleTranslation`);
  }

  return errors;
}

function isMeaningSuspicious(meaning) {
  const m = normalize(meaning);
  if (!m) return true;
  if (/^(관련 표현|동일한 의미의 표현|반대 의미의 표현)$/u.test(m)) return true;
  if (/\(\s*$/.test(m)) return true;
  return false;
}

function scoreRow(row, inferredPos) {
  const reasons = [];
  let score = 0;

  if (row.partOfSpeech !== inferredPos) {
    if (row.partOfSpeech === 'NOUN' && inferredPos !== 'NOUN') {
      score += 100;
      reasons.push(`POS_MISMATCH_HIGH: ${row.partOfSpeech} -> ${inferredPos}`);
    } else {
      score += 80;
      reasons.push(`POS_MISMATCH: ${row.partOfSpeech} -> ${inferredPos}`);
    }
  }

  if (row.partOfSpeech === 'ADVERB' && !ADVERB_WORDS.has(row.word) && !ADVERB_WORDS.has(row.reading)) {
    score += 70;
    reasons.push('ADVERB_SUSPECT');
  }

  if (row.partOfSpeech === 'CONJUNCTION' && !CONJUNCTION_WORDS.has(row.word) && !CONJUNCTION_WORDS.has(row.reading)) {
    score += 70;
    reasons.push('CONJUNCTION_SUSPECT');
  }

  if (isMeaningSuspicious(row.meaningKo)) {
    score += 60;
    reasons.push('MEANING_SUSPECT');
  }

  if (LOW_INFO_TRANSLATION_RES.some((re) => re.test(normalize(row.exampleTranslation)))) {
    score += 50;
    reasons.push('LOW_INFO_TRANSLATION');
  }

  if (!Array.isArray(row.tags) || row.tags.length === 0 || row.tags.every((x) => ['기본', '생활', '문법'].includes(x))) {
    score += 20;
    reasons.push('GENERIC_TAGS');
  }

  return { score, reasons };
}

function recorrectLevel(level) {
  const rawMap = loadRawMap(level);
  const { file: sourceFile, rows } = loadV2(level);
  const outRows = [];
  const queue = [];
  let corrected = 0;
  let posChanged = 0;
  let exampleChanged = 0;
  let meaningChanged = 0;
  let tagsChanged = 0;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const jlpt = normalize(row.jlptLevel).toUpperCase();
    const key = `${normalize(row.word)}__${normalize(row.reading)}__${jlpt}`;
    const rawMeaning = rawMap.get(key);
    const baseMeaning = rawMeaning ? cleanMeaning(rawMeaning) : cleanMeaning(row.meaningKo);
    const inferredPos = inferPos(row.word, row.reading, baseMeaning || row.meaningKo, row.partOfSpeech);
    const scored = scoreRow(row, inferredPos);

    const next = {
      word: row.word,
      reading: row.reading,
      meaningKo: row.meaningKo,
      partOfSpeech: row.partOfSpeech,
      jlptLevel: jlpt,
      exampleSentence: row.exampleSentence,
      exampleReading: row.exampleReading,
      exampleTranslation: row.exampleTranslation,
      tags: Array.isArray(row.tags) ? row.tags : [],
      order: i + 1,
    };

    if (scored.score > 0) {
      corrected += 1;

      const normalizedMeaning = fixUnbalancedParentheses(baseMeaning || row.meaningKo);
      if (normalizedMeaning && normalizedMeaning !== next.meaningKo) {
        next.meaningKo = normalizedMeaning;
        meaningChanged += 1;
      }

      if (next.partOfSpeech !== inferredPos) {
        next.partOfSpeech = inferredPos;
        posChanged += 1;
      }

      const pm = primaryMeaning(next.meaningKo) || primaryMeaning(row.meaningKo);
      const ex = exampleByPos(next.partOfSpeech, next.word, next.reading, pm);

      if (
        next.exampleSentence !== ex.j ||
        next.exampleReading !== ex.r ||
        next.exampleTranslation !== ex.k
      ) {
        next.exampleSentence = ex.j;
        next.exampleReading = ex.r;
        next.exampleTranslation = ex.k;
        exampleChanged += 1;
      }

      const nextTags = inferTags(next.meaningKo, next.partOfSpeech);
      if (JSON.stringify(next.tags) !== JSON.stringify(nextTags)) {
        next.tags = nextTags;
        tagsChanged += 1;
      }

      queue.push({
        rankScore: scored.score,
        order: i + 1,
        key,
        word: row.word,
        reading: row.reading,
        jlptLevel: jlpt,
        before: {
          meaningKo: row.meaningKo,
          partOfSpeech: row.partOfSpeech,
          exampleSentence: row.exampleSentence,
          exampleTranslation: row.exampleTranslation,
          tags: row.tags,
        },
        after: {
          meaningKo: next.meaningKo,
          partOfSpeech: next.partOfSpeech,
          exampleSentence: next.exampleSentence,
          exampleTranslation: next.exampleTranslation,
          tags: next.tags,
        },
        reasons: scored.reasons,
      });
    }

    outRows.push(next);
  }

  queue.sort((a, b) => b.rankScore - a.rankScore || a.order - b.order);
  for (let i = 0; i < queue.length; i++) queue[i].priorityOrder = i + 1;

  const outFile = join(REVIEWED_DIR, `${level}-words-reviewed-final-v3.json`);
  const queueFile = join(REVIEWED_DIR, `${level}-priority-recorrection-queue-v3.json`);
  const reportFile = join(REVIEWED_DIR, `${level}-priority-recorrection-report-v3.json`);

  writeFileSync(outFile, `${JSON.stringify(outRows, null, 2)}\n`, 'utf-8');
  writeFileSync(queueFile, `${JSON.stringify(queue, null, 2)}\n`, 'utf-8');

  const validationErrors = validateRows(outRows);
  const report = {
    generatedAt: new Date().toISOString(),
    level: level.toUpperCase(),
    sourceFile,
    outputFile: outFile,
    queueFile,
    totalRows: outRows.length,
    correctedRows: corrected,
    changeStats: {
      meaningChanged,
      posChanged,
      exampleChanged,
      tagsChanged,
    },
    validation: {
      passed: validationErrors.length === 0,
      errorCount: validationErrors.length,
      errors: validationErrors.slice(0, 30),
    },
    topPriorities: queue.slice(0, 20).map((x) => ({
      priorityOrder: x.priorityOrder,
      rankScore: x.rankScore,
      key: x.key,
      word: x.word,
      reading: x.reading,
      reasons: x.reasons,
    })),
  };

  writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`, 'utf-8');
  return { report, outFile, queueFile, reportFile };
}

function main() {
  const results = [];
  for (const level of LEVELS) {
    results.push(recorrectLevel(level));
  }

  const summary = {
    generatedAt: new Date().toISOString(),
    levels: results.map((r) => ({
      level: r.report.level,
      totalRows: r.report.totalRows,
      correctedRows: r.report.correctedRows,
      posChanged: r.report.changeStats.posChanged,
      exampleChanged: r.report.changeStats.exampleChanged,
      validationPassed: r.report.validation.passed,
      reportFile: r.reportFile,
      queueFile: r.queueFile,
      outputFile: r.outFile,
    })),
  };

  const summaryFile = join(REVIEWED_DIR, 'n1-n3-priority-recorrection-summary-v3.json');
  writeFileSync(summaryFile, `${JSON.stringify(summary, null, 2)}\n`, 'utf-8');

  console.log('✅ priority recorrection complete (v3)');
  for (const row of summary.levels) {
    console.log(
      `- ${row.level}: corrected=${row.correctedRows}/${row.totalRows}, posChanged=${row.posChanged}, exampleChanged=${row.exampleChanged}, validation=${row.validationPassed ? 'PASS' : 'FAIL'}`
    );
    console.log(`  out: ${row.outputFile}`);
    console.log(`  queue: ${row.queueFile}`);
    console.log(`  report: ${row.reportFile}`);
  }
  console.log(`- summary: ${summaryFile}`);
}

main();
