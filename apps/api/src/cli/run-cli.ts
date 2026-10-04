import { parseArgs } from 'node:util';

/** Mauvais usage de la commande : le script le dit avec son aide (code 2). */
export class UsageError extends Error {}

/**
 * Lance un script en ligne de commande : son code de sortie, ou 1 avec un
 * message lisible. Une configuration invalide (validateEnv) ne sort jamais
 * en rejet non géré à pile brute.
 */
export function runCli(main: (argv: readonly string[]) => Promise<number>): void {
  main(process.argv.slice(2))
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`Échec : ${(error as Error).message}\n`);
      process.exitCode = 1;
    });
}

type CliOptions = Record<string, { type: 'string' | 'boolean' }>;
type CliValues<T extends CliOptions> = {
  [K in keyof T]?: T[K]['type'] extends 'boolean' ? boolean : string;
};

/**
 * Les arguments d'un script, lus par `parseArgs` de Node, ses refus dits en
 * français (`UsageError`) : une option inconnue ou un argument en trop, une
 * valeur absente ou qui ressemble à une option (`--delai-minutes -5`). Pour
 * celle-ci, `attentes[option]` : le message de l'option, celui-là même que le
 * script lève sur une valeur invalide.
 */
export function readArgs<T extends CliOptions>(
  argv: readonly string[],
  options: T,
  {
    positionals = false,
    attentes = {},
  }: { positionals?: boolean; attentes?: Partial<Record<keyof T, string>> } = {},
): { values: CliValues<T>; positionals: string[] } {
  try {
    const parsed = parseArgs({ args: [...argv], options, allowPositionals: positionals });
    return { values: parsed.values, positionals: parsed.positionals };
  } catch (error) {
    const code = (error as { code?: unknown }).code;
    const cited = /'(-*[^' ]+)/.exec((error as Error).message)?.[1] ?? '';
    if (
      code === 'ERR_PARSE_ARGS_INVALID_OPTION_VALUE' &&
      /does not take an argument/.test(String(error))
    ) {
      throw new UsageError(`${cited} ne prend pas de valeur.`);
    }
    if (code === 'ERR_PARSE_ARGS_INVALID_OPTION_VALUE') {
      const option = cited.replace(/^--/, '') as keyof T;
      throw new UsageError(attentes[option] ?? `${cited} attend une valeur.`);
    }
    if (
      code === 'ERR_PARSE_ARGS_UNKNOWN_OPTION' ||
      code === 'ERR_PARSE_ARGS_UNEXPECTED_POSITIONAL'
    ) {
      throw new UsageError(`Option inconnue : « ${cited} ».`);
    }
    throw error;
  }
}
