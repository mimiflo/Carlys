import { type Response } from 'express';
import { sseEmitter, sseKeepAlive } from './sse';

/** Une réponse Express réduite à ce que le flux touche. */
function fakeResponse() {
  const written: string[] = [];
  const response = {
    headersSent: false,
    writableEnded: false,
    destroyed: false,
    status: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    flushHeaders: jest.fn(() => {
      response.headersSent = true;
    }),
    write: jest.fn((chunk: string) => written.push(chunk)),
  };
  return { response, written, express: response as unknown as Response };
}

describe('flux SSE', () => {
  beforeEach(() => jest.useFakeTimers());
  afterEach(() => jest.useRealTimers());

  it('un évènement ouvre le flux (200, sans tampon) puis s’écrit', () => {
    const { response, written, express } = fakeResponse();

    sseEmitter(express)('delta', { text: 'Salut' });

    expect(response.status).toHaveBeenCalledWith(200);
    expect(response.set).toHaveBeenCalledWith(
      expect.objectContaining({ 'X-Accel-Buffering': 'no' }) as Record<string, string>,
    );
    expect(written).toEqual(['event: delta\ndata: {"text":"Salut"}\n\n']);
  });

  it('le battement : RIEN avant son échéance — un refus rapide garde son statut HTTP', () => {
    const { response, express } = fakeResponse();

    sseKeepAlive(express, 15_000);
    jest.advanceTimersByTime(14_999);

    expect(response.headersSent).toBe(false);
    expect(response.write).not.toHaveBeenCalled();
  });

  it('puis un commentaire SSE à chaque échéance, que le client ignore', () => {
    const { response, written, express } = fakeResponse();

    sseKeepAlive(express, 15_000);
    jest.advanceTimersByTime(45_000);

    expect(response.headersSent).toBe(true);
    expect(written).toEqual([': ping\n\n', ': ping\n\n', ': ping\n\n']);
  });

  it('s’arrête quand on le lui dit, et se tait sur une réponse finie', () => {
    const { response, written, express } = fakeResponse();

    const stop = sseKeepAlive(express, 15_000);
    jest.advanceTimersByTime(15_000);
    response.writableEnded = true;
    jest.advanceTimersByTime(15_000);
    stop();
    jest.advanceTimersByTime(60_000);

    expect(written).toEqual([': ping\n\n']);
  });
});
