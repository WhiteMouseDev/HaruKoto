import { describe, it } from 'vitest';

describe('Auth', () => {
  it.todo('requireReviewer redirects unauthenticated user to /login');
  it.todo('requireReviewer redirects non-reviewer to /login?error=access_denied');
  it.todo('requireReviewer returns user when reviewer role is present');
  it.todo('proxy.ts uses getUser() not getSession()');
});
