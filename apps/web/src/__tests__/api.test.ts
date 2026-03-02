import { describe, it, expect, vi, beforeEach } from 'vitest';
import { apiFetch } from '@/lib/api';

describe('apiFetch', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('should return parsed JSON on successful response', async () => {
    const mockData = { hello: 'world' };
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify(mockData), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    );

    const result = await apiFetch<{ hello: string }>('/api/test');
    expect(result).toEqual(mockData);
  });

  it('should include Content-Type header', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({}), { status: 200 })
    );

    await apiFetch('/api/test');

    expect(fetch).toHaveBeenCalledWith('/api/test', {
      headers: { 'Content-Type': 'application/json' },
    });
  });

  it('should merge custom headers with Content-Type', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({}), { status: 200 })
    );

    await apiFetch('/api/test', {
      headers: { Authorization: 'Bearer token123' },
    });

    expect(fetch).toHaveBeenCalledWith('/api/test', {
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer token123',
      },
    });
  });

  it('should pass through other RequestInit options', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({}), { status: 200 })
    );

    await apiFetch('/api/test', {
      method: 'POST',
      body: JSON.stringify({ data: 'test' }),
    });

    expect(fetch).toHaveBeenCalledWith('/api/test', {
      method: 'POST',
      body: JSON.stringify({ data: 'test' }),
      headers: { 'Content-Type': 'application/json' },
    });
  });

  it('should throw Error with server error message on non-ok response', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
      })
    );

    await expect(apiFetch('/api/test')).rejects.toThrow('Unauthorized');
  });

  it('should throw Error with status code when error body is not JSON', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response('not json', { status: 500 })
    );

    await expect(apiFetch('/api/test')).rejects.toThrow('Unknown error');
  });

  it('should throw Error with fallback message when error has no error field', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ message: 'some message' }), {
        status: 400,
      })
    );

    await expect(apiFetch('/api/test')).rejects.toThrow('API error: 400');
  });
});
