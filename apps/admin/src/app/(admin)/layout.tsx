import { getLocale, getTranslations } from 'next-intl/server';
import { requireReviewer } from '@/lib/supabase/auth';
import { Sidebar } from '@/components/layout/sidebar';

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireReviewer();
  const locale = await getLocale();
  const t = await getTranslations('a11y');

  return (
    <div className="flex h-screen overflow-hidden">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-background focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:ring-2 focus:ring-ring"
      >
        {t('skipToMain')}
      </a>
      <Sidebar user={user} locale={locale} />
      <main
        id="main-content"
        aria-label={t('mainContent')}
        className="flex-1 overflow-y-auto p-8"
      >
        {children}
      </main>
    </div>
  );
}
