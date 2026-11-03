export type AnswerQueueState = {
  pending: number;
  saving: boolean;
  error: Error | null;
};

/** A failed request stays at the head; completion waits for every saved answer. */
export class QuizAnswerQueue<Payload> {
  private items: Payload[] = [];
  private running: Promise<boolean> | null = null;
  private error: Error | null = null;
  private cancelled = false;
  private generation = 0;

  constructor(
    private send: (payload: Payload) => Promise<unknown>,
    private readonly changed: (state: AnswerQueueState) => void
  ) {}

  setSender(send: (payload: Payload) => Promise<unknown>): void {
    this.send = send;
  }

  enqueue(payload: Payload): void {
    if (this.cancelled) return;
    this.items.push(payload);
    this.publish();
    void this.flush();
  }

  async flush(): Promise<boolean> {
    if (this.cancelled || this.error) return false;
    if (this.running) return this.running;
    if (this.items.length === 0) return true;
    const generation = this.generation;
    this.running = this.drain(generation);
    this.publish();
    const result = await this.running;
    if (generation !== this.generation) return false;
    this.running = null;
    this.publish();
    return result;
  }

  retry(): Promise<boolean> {
    if (this.cancelled || this.running) return Promise.resolve(false);
    this.error = null;
    return this.flush();
  }

  activate(): void {
    this.cancelled = false;
  }

  cancel(notify = false): void {
    this.cancelled = true;
    this.generation += 1;
    this.items = [];
    this.running = null;
    this.error = null;
    if (notify) this.changed({ pending: 0, saving: false, error: null });
  }

  private async drain(generation: number): Promise<boolean> {
    while (!this.cancelled && this.items.length > 0) {
      const payload = this.items[0];
      try {
        await this.send(payload);
        if (this.cancelled || generation !== this.generation) return false;
        this.items.shift();
      } catch (error) {
        if (this.cancelled || generation !== this.generation) return false;
        this.error =
          error instanceof Error ? error : new Error('답안 저장에 실패했어요.');
        return false;
      }
    }
    return !this.cancelled;
  }

  private publish(): void {
    if (!this.cancelled)
      this.changed({
        pending: this.items.length,
        saving: this.running !== null,
        error: this.error,
      });
  }
}
