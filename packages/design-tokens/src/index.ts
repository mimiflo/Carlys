import tokens from './tokens.json';

/**
 * Design tokens Carlys, typés à partir de `tokens.json`.
 *
 * Consommés par le tableau de bord admin (Tailwind/CSS). Côté Flutter, il n'y
 * a PAS de générateur : le design system écrit ses valeurs à la main, et
 * `apps/mobile/test/design_system/design_tokens_test.dart` lit ce même
 * `tokens.json` pour vérifier que les deux disent la même chose — un écart
 * fait échouer la CI mobile. Le commentaire promettait ici un générateur
 * « à terme » ; c'est le miroir vérifié qui a été retenu, et il tient depuis.
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
