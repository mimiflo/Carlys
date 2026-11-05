import { NotFoundException } from '@nestjs/common';

/**
 * Un 404 qui dit « ce code-barres, la base ne le connaît pas » : le filtre
 * d'exceptions le rend sous le code `PRODUCT_NOT_FOUND`, pour que le client
 * propose la saisie à la main SEULEMENT dans ce cas — un 404 de routage (une
 * API plus ancienne, un proxy) reste une erreur.
 */
export class ProductNotFoundException extends NotFoundException {}
