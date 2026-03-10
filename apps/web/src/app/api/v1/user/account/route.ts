import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { prisma } from '@harukoto/database';
import { deleteFromGCS, getAvatarPath } from '@/lib/gcs';

export async function DELETE() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    // Delete avatar from GCS (non-blocking, best-effort)
    deleteFromGCS(getAvatarPath(user.id)).catch((err) =>
      console.error('GCS avatar cleanup failed:', err)
    );

    // Prisma first — CASCADE deletes all related records
    await prisma.user.delete({ where: { id: user.id } });

    // Then remove Supabase Auth user
    const admin = createAdminClient();
    await admin.auth.admin.deleteUser(user.id);

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error('Account DELETE error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
