// @vitest-environment node
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import {
  canonicalStudyWritePath,
  studyWriteRouteDecision,
  STUDY_WRITE_ROUTE_POLICY,
  STUDY_WRITE_STOP_MESSAGE,
  studyWriteErrorMessage,
} from '@/lib/study-write-stop';
import { STUDY_WRITES_PAUSED } from '@/lib/study-write-stop-policy';

describe('legacy study writer STOP policy', () => {
  it('exposes a source-controlled boolean switch', () => {
    // Both reviewed OFF and activation builds must execute the regressions.
    expect(typeof STUDY_WRITES_PAUSED).toBe('boolean');
  });

  it.each(STUDY_WRITE_ROUTE_POLICY)(
    '$method $path is explicitly $decision: $reason',
    ({ method, path: pathname, decision }) => {
      expect(studyWriteRouteDecision(method, pathname)).toBe(decision);
    }
  );

  it.each([
    '/api/v1/quiz/answer/',
    '/api//v1/quiz/answer',
    '/api/v1/quiz/%61nswer',
    '/api%2fv1%2fquiz%2fanswer',
    '/%61pi/v1/quiz/answer',
    '/api%252fv1%252fquiz%252fanswer',
  ])('fences canonical path aliases %s', (pathname) => {
    expect(canonicalStudyWritePath(pathname)).toBe('/api/v1/quiz/answer');
    expect(studyWriteRouteDecision('POST', pathname)).toBe('pause');
  });

  it('covers generated HEAD mission execution while OPTIONS remains open', () => {
    expect(studyWriteRouteDecision('HEAD', '/api/v1/missions/today')).toBe(
      'pause'
    );
    expect(
      studyWriteRouteDecision('OPTIONS', '/api/v1/quiz/answer')
    ).toBeUndefined();
    expect(
      studyWriteRouteDecision('GET', '/api/v1/quiz/answer')
    ).toBeUndefined();
  });

  it('does not treat neighboring paths as learning writers', () => {
    expect(
      studyWriteRouteDecision('POST', '/api/v1/quiz/answering')
    ).toBeUndefined();
    expect(studyWriteRouteDecision('POST', '/api/v1/chat/tts')).toBe('allow');
    expect(studyWriteRouteDecision('POST', '/api/v1/webhook/portone')).toBe(
      'allow'
    );
    expect(studyWriteRouteDecision('DELETE', '/api/v1/chat/id.svg')).toBe(
      'pause'
    );
  });

  it('pauses lesson activity POSTs while keeping receipt lookup read-only', () => {
    // FastAPI owns these routes; the browser proxy must preserve its boundary.
    expect(
      studyWriteRouteDecision(
        'POST',
        '/api/v1/lessons/lesson-id/study-activities'
      )
    ).toBe('pause');
    expect(
      studyWriteRouteDecision(
        'GET',
        '/api/v1/lessons/lesson-id/study-activities/activity-id'
      )
    ).toBe('allow');
    expect(
      studyWriteRouteDecision(
        'HEAD',
        '/api/v1/lessons/lesson-id/study-activities/activity-id'
      )
    ).toBe('allow');
  });

  it('classifies every current API route method, including side-effecting GETs', () => {
    const root = fileURLToPath(new URL('../app/api', import.meta.url));
    const found: string[] = [];
    function visit(directory: string) {
      for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const absolute = path.join(directory, entry.name);
        if (entry.isDirectory()) visit(absolute);
        else if (entry.name === 'route.ts') {
          const pathname = `/api/${path.relative(root, directory).split(path.sep).join('/')}`;
          const source = readFileSync(absolute, 'utf8');
          const methods = [
            ...source.matchAll(
              /export\s+(?:async\s+)?function\s+(GET|HEAD|POST|PUT|PATCH|DELETE|OPTIONS)\b/g
            ),
          ];
          expect(
            methods.length,
            `Unrecognized route exports: ${pathname}`
          ).toBeGreaterThan(0);
          for (const [, method] of methods) {
            found.push(`${method} ${pathname}`);
            expect(
              studyWriteRouteDecision(method, pathname),
              `Classify ${method} ${pathname} before adding it`
            ).toBeDefined();
          }
        }
      }
    }
    visit(root);
    expect(found.length).toBeGreaterThan(40);
  });

  it('exposes the pause explanation without changing unrelated errors', () => {
    expect(
      studyWriteErrorMessage(new Error(STUDY_WRITE_STOP_MESSAGE), 'fallback')
    ).toBe(STUDY_WRITE_STOP_MESSAGE);
    expect(studyWriteErrorMessage(new Error('other'), 'fallback')).toBe(
      'fallback'
    );
  });
});
