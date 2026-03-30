import { getLocale } from 'next-intl/server';
import { requireReviewer } from '@/lib/supabase/auth';
import { Sidebar } from '@/components/layout/sidebar';

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireReviewer();
  const locale = await getLocale();

  return (
    <div className="flex min-h-screen">
      <Sidebar user={user} locale={locale} />
      <main className="flex-1 overflow-y-auto p-8">{children}</main>
    </div>
  );
}
