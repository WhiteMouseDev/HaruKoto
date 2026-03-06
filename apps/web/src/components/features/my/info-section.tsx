'use client';

import { motion } from 'framer-motion';
import {
  ChevronRight,
  ScrollText,
  Shield,
  Mail,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useRouter } from 'next/navigation';
import { openExternalUrl } from '@/lib/flutter-bridge';
import { SectionLabel } from './section-label';

export function InfoSection() {
  const router = useRouter();

  return (
    <motion.div
      initial={{ y: 10, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: 0.2 }}
      className="flex flex-col gap-1.5"
    >
      <SectionLabel>정보</SectionLabel>
      <Card>
        <CardContent className="flex flex-col p-0">
          {/* Terms */}
          <button
            className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
            onClick={() => router.push('/terms')}
          >
            <div className="flex items-center gap-3">
              <ScrollText className="text-muted-foreground size-5" />
              <span className="text-sm font-medium">이용약관</span>
            </div>
            <ChevronRight className="text-muted-foreground size-4" />
          </button>

          <Separator />

          {/* Privacy */}
          <button
            className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
            onClick={() => router.push('/privacy')}
          >
            <div className="flex items-center gap-3">
              <Shield className="text-muted-foreground size-5" />
              <span className="text-sm font-medium">개인정보처리방침</span>
            </div>
            <ChevronRight className="text-muted-foreground size-4" />
          </button>

          <Separator />

          {/* Contact */}
          <button
            className="hover:bg-accent flex items-center justify-between px-4 py-3.5 text-left transition-colors"
            onClick={() => openExternalUrl('mailto:whitemousedev@whitemouse.dev')}
          >
            <div className="flex items-center gap-3">
              <Mail className="text-muted-foreground size-5" />
              <span className="text-sm font-medium">문의하기</span>
            </div>
            <ChevronRight className="text-muted-foreground size-4" />
          </button>
        </CardContent>
      </Card>
    </motion.div>
  );
}
