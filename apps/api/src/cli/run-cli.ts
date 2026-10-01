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
