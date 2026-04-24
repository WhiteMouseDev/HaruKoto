import { redirect } from 'next/navigation';
import { createClient } from './server';
import { E2E_REVIEWER_USER, isE2eAuthBypassEnabled } from '@/lib/e2e-auth';

export async function getReviewerUser() {
  if (isE2eAuthBypassEnabled()) {
    return E2E_REVIEWER_USER;
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function requireReviewer() {
  const user = await getReviewerUser();

  if (!user) {
    redirect('/login');
  }

  if (user.app_metadata?.reviewer !== true) {
    redirect('/login?error=access_denied');
  }

  return user;
}
