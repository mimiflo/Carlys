import tokens from './tokens.json';

/**
 * Design tokens Carlys, typés à partir de `tokens.json`.
 * Consommés par le tableau de bord admin (Tailwind/CSS) et, à terme,
 * par un générateur de code Dart pour le design system Flutter.
 */
export const designTokens = tokens;

export type DesignTokens = typeof tokens;
export type ColorTokens = DesignTokens['color'];
export type SpacingTokens = DesignTokens['spacing'];
export type RadiusTokens = DesignTokens['radius'];
export type TypographyTokens = DesignTokens['typography'];
export type ShadowTokens = DesignTokens['shadow'];
export type MotionTokens = DesignTokens['motion'];
export type BreakpointTokens = DesignTokens['breakpoint'];
