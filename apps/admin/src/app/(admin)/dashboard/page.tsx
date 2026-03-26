import { getTranslations } from 'next-intl/server';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { requireReviewer } from '@/lib/supabase/auth';

export default async function DashboardPage() {
  const t = await getTranslations();
  const user = await requireReviewer();

  const displayName =
    (user.user_metadata?.full_name as string | undefined) ??
    user.email?.split('@')[0] ??
    'Reviewer';

  const contentTypes = [
    { key: 'vocabulary', label: t('dashboard.vocabulary') },
    { key: 'grammar', label: t('dashboard.grammar') },
    { key: 'quiz', label: t('dashboard.quiz') },
    { key: 'conversation', label: t('dashboard.conversation') },
  ] as const;

  return (
    <div>
      <h1 className="mb-6 text-xl font-semibold">
        {t('dashboard.welcome', { name: displayName })}
      </h1>

      <div className="grid max-w-[960px] grid-cols-2 gap-4">
        {contentTypes.map(({ key, label }) => (
          <Card key={key}>
            <CardHeader>
              <CardTitle>{label}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                {t('dashboard.emptyBody')}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
