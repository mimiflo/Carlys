import { registerDecorator, type ValidationOptions } from 'class-validator';

/** Marge, en jours, autour du jour UTC courant. */
const TOLERANCE_DAYS = 1;

/**
 * Le champ porte un jour `YYYY-MM-DD` PLAUSIBLE : celui du serveur, à un
 * jour près de part et d'autre.
 *
 * La marge couvre les fuseaux (un appareil à UTC+14 est déjà demain, un
 * autre à UTC-11 encore hier) et rien de plus. Sans elle, le jour était un
 * champ libre : une seule leçon, renvoyée avec des dates fabriquées
 * (`2020-01-01`, `2020-01-02`, …), franchissait autant de fois la
 * contrainte d'unicité qu'on voulait — et chaque envoi créditait le défi
 * collectif EN COURS, puisque le comptage visait l'instant serveur. Le
 * quota mensuel d'un groupe entier tombait en quelques minutes.
 */
export function IsRecentDayKey(options?: ValidationOptions): PropertyDecorator {
  return function (object: object, propertyName: string | symbol): void {
    registerDecorator({
      name: 'isRecentDayKey',
      target: object.constructor,
      propertyName: propertyName as string,
      options: {
        message:
          'Jour hors de la fenêtre acceptée : le jour local de l’appareil est attendu ' +
          '(un jour d’écart au maximum avec le serveur).',
        ...options,
      },
      validator: {
        validate: (value: unknown) => {
          if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
            return false;
          }
          const day = Date.parse(`${value}T00:00:00Z`);
          if (Number.isNaN(day)) {
            return false;
          }
          const today = new Date();
          const todayUtc = Date.UTC(
            today.getUTCFullYear(),
            today.getUTCMonth(),
            today.getUTCDate(),
          );
          const toleranceMs = TOLERANCE_DAYS * 24 * 60 * 60 * 1_000;
          return Math.abs(day - todayUtc) <= toleranceMs;
        },
      },
    });
  };
}

/**
 * L'instant de référence d'un jour `YYYY-MM-DD` : MIDI UTC.
 *
 * Midi, et pas minuit : le jour déclaré vient d'un appareil dont le fuseau
 * peut décaler de ±14 h, et midi UTC est le seul instant qui reste dans la
 * journée civile de tout le monde.
 */
export function dayKeyToInstant(dayKey: string): Date {
  return new Date(`${dayKey}T12:00:00Z`);
}
