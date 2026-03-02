import {
  type LucideIcon,
  Target,
  FileText,
  Library,
  Trophy,
  CheckCheck,
  MessageCircle,
  MessagesSquare,
  Mic,
  Flame,
  Zap,
  Sparkles,
  Crown,
  BookOpen,
  BookMarked,
  Star,
  Moon,
  Flower2,
  Gem,
  Medal,
  Award,
  PartyPopper,
  Megaphone,
  HelpCircle,
} from 'lucide-react';

const ICON_MAP: Record<string, LucideIcon> = {
  target: Target,
  'file-text': FileText,
  library: Library,
  trophy: Trophy,
  'check-check': CheckCheck,
  'message-circle': MessageCircle,
  'messages-square': MessagesSquare,
  mic: Mic,
  flame: Flame,
  zap: Zap,
  sparkles: Sparkles,
  crown: Crown,
  'book-open': BookOpen,
  'book-marked': BookMarked,
  star: Star,
  moon: Moon,
  'flower-2': Flower2,
  gem: Gem,
  medal: Medal,
  award: Award,
  'party-popper': PartyPopper,
  megaphone: Megaphone,
};

type GameIconProps = {
  name: string;
  className?: string;
};

export function GameIcon({ name, className }: GameIconProps) {
  const Icon = ICON_MAP[name] ?? HelpCircle;
  return <Icon className={className} />;
}
