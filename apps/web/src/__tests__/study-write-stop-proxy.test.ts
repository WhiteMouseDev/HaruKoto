// @vitest-environment node
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { NextRequest } from 'next/server';
import { unstable_doesMiddlewareMatch } from 'next/experimental/testing/server';
import { proxy, config } from '@/proxy';
import {
  STUDY_WRITE_ROUTE_POLICY,
  STUDY_WRITE_STOP_MESSAGE,
} from '@/lib/study-write-stop';

const mocks = vi.hoisted(() => ({
  paused: false,
  createServerClient: vi.fn(),
  getUser: vi.fn(),
  prisma: { user: { findUnique: vi.fn(), create: vi.fn() } },
}));
vi.mock('@/lib/study-write-stop-policy', () => ({
  get STUDY_WRITES_PAUSED() {
    return mocks.paused;
  },
}));
vi.mock('@supabase/ssr', () => ({
  createServerClient: mocks.createServerClient,
}));
vi.mock('@harukoto/database', () => ({ prisma: mocks.prisma }));

beforeEach(() => {
  vi.resetAllMocks();
  mocks.paused = true;
  mocks.getUser.mockResolvedValue({ data: { user: null } });
  mocks.createServerClient.mockReturnValue({
    auth: { getUser: mocks.getUser },
  });
});

describe('STOP precedes session and database access', () => {
  it.each(STUDY_WRITE_ROUTE_POLICY.filter((rule) => rule.decision === 'pause'))(
    '$method $path returns 503 before auth/DB/provider code',
    async ({ method, path }) => {
      const response = await proxy(
        new NextRequest(
          `http://localhost${path.replaceAll(/\[[^\]]+\]/g, 'some-id')}`,
          { method }
        )
      );
      expect(response.status).toBe(503);
      expect(await response.json()).toEqual({
        error: STUDY_WRITE_STOP_MESSAGE,
      });
      expect(response.headers.get('Retry-After')).toBe('60');
      expect(response.headers.get('Cache-Control')).toBe('private, no-store');
      expect(mocks.createServerClient).not.toHaveBeenCalled();
      expect(mocks.prisma.user.findUnique).not.toHaveBeenCalled();
      expect(mocks.prisma.user.create).not.toHaveBeenCalled();
    }
  );

  it.each(['GET', 'HEAD'])(
    'stops mission auto-claim via %s',
    async (method) => {
      const response = await proxy(
        new NextRequest('http://localhost/api/v1/missions/today', { method })
      );
      expect(response.status).toBe(503);
      expect(mocks.createServerClient).not.toHaveBeenCalled();
    }
  );

  it.each(STUDY_WRITE_ROUTE_POLICY.filter((rule) => rule.decision === 'allow'))(
    '$method $path keeps the existing auth/route pipeline',
    async ({ method, path }) => {
      const response = await proxy(
        new NextRequest(
          `http://localhost${path.replaceAll(/\[[^\]]+\]/g, 'some-id')}`,
          { method }
        )
      );
      expect(response.status).toBe(200);
      expect(response.headers.get('x-middleware-next')).toBe('1');
      expect(mocks.getUser).toHaveBeenCalledOnce();
    }
  );

  it('leaves OPTIONS preflight and login routing intact', async () => {
    expect(
      (
        await proxy(
          new NextRequest('http://localhost/api/v1/quiz/answer', {
            method: 'OPTIONS',
          })
        )
      ).status
    ).toBe(200);
    expect(
      (await proxy(new NextRequest('http://localhost/login'))).status
    ).toBe(200);
    expect(
      (await proxy(new NextRequest('http://localhost/home'))).headers.get(
        'location'
      )
    ).toBe('http://localhost/login');
  });

  it('keeps an existing authenticated session on a protected page', async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: 'saved-user' } } });
    const response = await proxy(
      new NextRequest('http://localhost/home', {
        headers: { cookie: 'onboarding_completed=saved-user' },
      })
    );
    expect(response.status).toBe(200);
    expect(mocks.prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('delegates unchanged with STOP disabled', async () => {
    mocks.paused = false;
    const response = await proxy(
      new NextRequest('http://localhost/api/v1/quiz/answer', { method: 'POST' })
    );
    expect(response.status).toBe(200);
    expect(mocks.getUser).toHaveBeenCalledOnce();
  });

  it('does not let image-extension dynamic IDs bypass the policy', async () => {
    const response = await proxy(
      new NextRequest('http://localhost/api/v1/chat/id.svg', {
        method: 'DELETE',
      })
    );
    expect(response.status).toBe(503);
    expect(mocks.createServerClient).not.toHaveBeenCalled();
    expect(config.matcher.join(' ')).not.toContain('svg');
  });

  it.each([
    '/api/v1/chat/id.svg',
    '/api%2fv1%2fchat%2fid.svg',
    '/%61pi/v1/chat/id.svg',
    '/api/v1/missions/today',
    '/api/v1/quiz/answer/',
  ])('Next matcher covers the canonical API alias %s', (pathname) => {
    expect(
      unstable_doesMiddlewareMatch({
        config,
        nextConfig: {},
        url: `http://localhost${pathname}`,
      })
    ).toBe(true);
  });
});
