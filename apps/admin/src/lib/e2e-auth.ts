import type { User } from '@supabase/supabase-js';

export function isE2eAuthBypassEnabled(): boolean {
  return (
    process.env.NODE_ENV !== 'production' &&
    process.env.ADMIN_E2E_AUTH_BYPASS === '1'
  );
}

export const E2E_REVIEWER_USER = {
  id: '00000000-0000-4000-8000-000000000001',
  aud: 'authenticated',
  role: 'authenticated',
  email: 'e2e-reviewer@harukoto.test',
  app_metadata: {
    provider: 'email',
    reviewer: true,
  },
  user_metadata: {
    full_name: 'E2E Reviewer',
  },
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
} as User;
