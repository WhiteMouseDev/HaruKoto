export function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <span className="text-muted-foreground px-1 text-xs font-medium">
      {children}
    </span>
  );
}
