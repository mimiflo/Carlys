import { runCli, UsageError } from './run-cli';

/** Ce que runCli fait d'un `main` : son code, 2 + aide sur un mauvais usage, 1 sinon. */
async function sortie(
  main: () => Promise<number>,
  usage?: () => string,
): Promise<{ code: typeof process.exitCode; stderr: string }> {
  const stderr = jest.spyOn(process.stderr, 'write').mockImplementation(() => true);
  try {
    runCli(main, usage);
    await new Promise(setImmediate);
    return { code: process.exitCode, stderr: stderr.mock.calls.map(([t]) => String(t)).join('') };
  } finally {
    stderr.mockRestore();
    process.exitCode = undefined;
  }
}

describe('runCli', () => {
  it('rend le code de sortie de main', async () => {
    expect(await sortie(() => Promise.resolve(3))).toEqual({ code: 3, stderr: '' });
  });

  it('dit un mauvais usage avec l’aide, code 2', async () => {
    const main = () => Promise.reject(new UsageError('Option inconnue : « --x ».'));
    expect(await sortie(main, () => 'Usage : carlys …')).toEqual({
      code: 2,
      stderr: 'Option inconnue : « --x ».\n\nUsage : carlys …\n',
    });
  });

  it('dit tout autre échec en « Échec : … », code 1', async () => {
    const main = () => Promise.reject(new Error('base injoignable'));
    expect(await sortie(main, () => 'Usage')).toEqual({
      code: 1,
      stderr: 'Échec : base injoignable\n',
    });
  });
});
