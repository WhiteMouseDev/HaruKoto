import { redirect } from 'next/navigation';
import { createClient } from './server';

export async function getReviewerUser() {
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
