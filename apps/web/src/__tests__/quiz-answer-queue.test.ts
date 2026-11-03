import { describe, expect, it, vi } from 'vitest';
import { QuizAnswerQueue } from '@/lib/quiz-answer-queue';

function deferred() {
  let resolve!: () => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<void>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

describe('durable answer completion barrier', () => {
  it('waits for every in-flight answer before permitting completion', async () => {
    const first = deferred(); const second = deferred();
    const send = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
    const queue = new QuizAnswerQueue(send, vi.fn());
    queue.enqueue({ questionId: 'one' }); queue.enqueue({ questionId: 'two' });
    const finished = vi.fn(); const wait = queue.flush().then(finished);
    expect(send).toHaveBeenCalledTimes(1);
    first.resolve(); await Promise.resolve(); await Promise.resolve();
    expect(send).toHaveBeenCalledTimes(2); expect(finished).not.toHaveBeenCalled();
    second.resolve(); await wait;
    expect(finished).toHaveBeenCalledWith(true);
  });
  it('retains the exact failed payload and blocks later answers until an explicit retry', async () => {
    const send = vi.fn().mockRejectedValueOnce(new Error('response lost')).mockResolvedValue({});
    const changed = vi.fn(); const queue = new QuizAnswerQueue(send, changed);
    const payload = { questionId: 'one', selectedOptionId: 'right', timeSpentSeconds: 8 };
    queue.enqueue(payload); queue.enqueue({ questionId: 'two' });
    expect(await queue.flush()).toBe(false);
    expect(send).toHaveBeenCalledTimes(1);
    expect(await queue.flush()).toBe(false);
    expect(await queue.retry()).toBe(true);
    expect(send.mock.calls[0][0]).toBe(send.mock.calls[1][0]);
    expect(send).toHaveBeenCalledTimes(3);
    expect(changed).toHaveBeenLastCalledWith({ pending: 0, saving: false, error: null });
  });
  it('does not send queued answers or update UI after screen disposal', async () => {
    const request = deferred(); const send = vi.fn().mockReturnValue(request.promise); const changed = vi.fn();
    const queue = new QuizAnswerQueue(send, changed);
    queue.enqueue({ questionId: 'one' }); queue.enqueue({ questionId: 'two' });
    queue.cancel(); changed.mockClear(); request.resolve(); await Promise.resolve(); await Promise.resolve();
    expect(send).toHaveBeenCalledTimes(1); expect(changed).not.toHaveBeenCalled();
    expect(await queue.flush()).toBe(false);
  });
  it('supports React effect cleanup/setup without accepting an old request into a new lifecycle', async () => {
    const old = deferred(); const send = vi.fn().mockReturnValueOnce(old.promise).mockResolvedValue({});
    const queue = new QuizAnswerQueue(send, vi.fn());
    queue.enqueue('old'); queue.cancel(); queue.activate(); queue.enqueue('new');
    old.resolve(); expect(await queue.flush()).toBe(true);
    expect(send.mock.calls.map(([payload]) => payload)).toEqual(['old', 'new']);
  });
});
