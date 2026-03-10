import { Storage } from '@google-cloud/storage';

const BUCKET_NAME = process.env.GCS_BUCKET_NAME!;
const CDN_URL = process.env.NEXT_PUBLIC_GCS_CDN_URL!;

let storage: Storage | null = null;

function getStorage() {
  if (!storage) {
    storage = new Storage({
      projectId: 'harukoto',
      credentials: {
        client_email: process.env.GCS_CLIENT_EMAIL!,
        private_key: process.env.GCS_PRIVATE_KEY!.replace(/\\n/g, '\n'),
      },
    });
  }
  return storage;
}

function getBucket() {
  return getStorage().bucket(BUCKET_NAME);
}

/**
 * Upload a buffer to GCS and return the public URL.
 */
export async function uploadToGCS(
  filePath: string,
  buffer: Buffer,
  contentType: string
): Promise<string> {
  const file = getBucket().file(filePath);

  await file.save(buffer, {
    contentType,
    metadata: {
      cacheControl: 'public, max-age=3600',
    },
  });

  return `${CDN_URL}/${filePath}`;
}

/**
 * Delete a file from GCS. Silently ignores if file doesn't exist.
 */
export async function deleteFromGCS(filePath: string): Promise<void> {
  try {
    await getBucket().file(filePath).delete();
  } catch (err: unknown) {
    const error = err as { code?: number };
    if (error.code !== 404) {
      console.error('GCS delete error:', err);
    }
  }
}

/**
 * Get the avatar GCS path for a user.
 */
export function getAvatarPath(userId: string): string {
  return `avatars/${userId}.webp`;
}

/**
 * Get the public CDN URL for an avatar.
 */
export function getAvatarUrl(userId: string): string {
  return `${CDN_URL}/avatars/${userId}.webp`;
}
