import { createAdminClient } from '../src/lib/supabase/admin';

async function provisionReviewer(userId: string): Promise<void> {
  const supabase = createAdminClient();
  const { data, error } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { reviewer: true },
  });

  if (error) {
    console.error(`Failed to grant reviewer role to ${userId}:`, error.message);
    process.exit(1);
  }

  console.log(
    `Reviewer role GRANTED to user: ${data.user.email ?? userId} (id: ${userId})`
  );
}

async function revokeReviewer(userId: string): Promise<void> {
  const supabase = createAdminClient();
  const { data, error } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: { reviewer: false },
  });

  if (error) {
    console.error(
      `Failed to revoke reviewer role from ${userId}:`,
      error.message
    );
    process.exit(1);
  }

  console.log(
    `Reviewer role REVOKED from user: ${data.user.email ?? userId} (id: ${userId})`
  );
}

async function main(): Promise<void> {
  const userId = process.argv[2];
  const action = process.argv[3] as 'grant' | 'revoke' | undefined;

  if (!userId || !action || !['grant', 'revoke'].includes(action)) {
    console.error(
      'Usage: npx tsx scripts/provision-reviewer.ts <userId> <grant|revoke>'
    );
    console.error('Example: npx tsx scripts/provision-reviewer.ts abc-123 grant');
    process.exit(1);
  }

  if (action === 'grant') {
    await provisionReviewer(userId);
  } else {
    await revokeReviewer(userId);
  }
}

main().catch((err: unknown) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
