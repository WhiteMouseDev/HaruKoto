import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 text-center">
      <h1 className="text-6xl font-bold text-muted-foreground">404</h1>
      <p className="text-xl font-semibold">Page not found</p>
      <p className="text-sm text-muted-foreground">
        The page you are looking for does not exist.
      </p>
      <Link
        href="/dashboard"
        className="text-sm text-primary underline underline-offset-4 hover:opacity-80"
      >
        Back to Dashboard
      </Link>
    </div>
  );
}
