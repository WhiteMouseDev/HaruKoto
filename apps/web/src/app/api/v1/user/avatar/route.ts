import { NextResponse } from 'next/server';
import sharp from 'sharp';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';
import { uploadToGCS, getAvatarPath, getAvatarUrl } from '@/lib/gcs';

const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2MB
const AVATAR_SIZE = 200; // 200x200px
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const formData = await request.formData();
    const file = formData.get('file');

    if (!file || !(file instanceof File)) {
      return NextResponse.json(
        { error: '파일이 필요합니다' },
        { status: 400 }
      );
    }

    if (!ALLOWED_TYPES.includes(file.type)) {
      return NextResponse.json(
        { error: 'JPG, PNG, WebP, GIF 이미지만 업로드 가능합니다' },
        { status: 400 }
      );
    }

    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: '파일 크기는 2MB 이하만 가능합니다' },
        { status: 400 }
      );
    }

    // Convert to 200x200 WebP
    const arrayBuffer = await file.arrayBuffer();
    const webpBuffer = await sharp(Buffer.from(arrayBuffer))
      .resize(AVATAR_SIZE, AVATAR_SIZE, {
        fit: 'cover',
        position: 'center',
      })
      .webp({ quality: 80 })
      .toBuffer();

    // Upload to GCS (overwrites existing avatar)
    const filePath = getAvatarPath(user.id);
    await uploadToGCS(filePath, webpBuffer, 'image/webp');

    // Update DB with cache-busted URL
    const avatarUrl = `${getAvatarUrl(user.id)}?v=${Date.now()}`;
    await prisma.user.update({
      where: { id: user.id },
      data: { avatarUrl },
    });

    return NextResponse.json({ avatarUrl });
  } catch (err) {
    console.error('Avatar upload error:', err);
    return NextResponse.json(
      { error: '업로드에 실패했습니다' },
      { status: 500 }
    );
  }
}
