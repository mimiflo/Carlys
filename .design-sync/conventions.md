# Conventions Carlys UI

## Mise en place obligatoire

Enveloppe TOUTE composition dans `CarlysProvider` — c'est lui qui pose le
fond, la couleur de texte, la famille Inter et les variables de thème. Sans
lui, les surfaces et le texte n'ont pas leurs couleurs. Thèmes : `light`
(défaut), `dark`, `oled` (fond noir pur).

```jsx
<CarlysProvider theme="dark">
  {/* … composants Carlys … */}
</CarlysProvider>
```

## Idiome de style

Les composants se pilotent par **props** (`variant`, `size`, `isLoading`,
`isExpanded`, `error`…), jamais par classes sur les composants eux-mêmes.
Pour TA colle de mise en page (conteneurs, grilles, espacements), utilise
les variables CSS du design system — jamais de valeurs en dur :

- Couleurs : `var(--carlys-color-primary)` `#9B30FF`, `--carlys-color-accent`
  `#FF7A45`, `--carlys-color-success|warning|danger|info`,
  neutres `--carlys-neutral-0` … `--carlys-neutral-950`.
- Surfaces (suivent le thème) : `--carlys-background`, `--carlys-surface`,
  `--carlys-surface-alt`, `--carlys-text`, `--carlys-text-muted`,
  `--carlys-border`.
- Espacements : `--carlys-spacing-xxs|xs|sm|md|lg|xl|xxl|xxxl` (4→64px).
- Rayons : `--carlys-radius-xs|sm|md|lg|xl|full` ; ombres :
  `--carlys-shadow-sm|md|lg` ; typo : `--carlys-font-body|display|mono`,
  `--carlys-text-xs…display`, `--carlys-weight-regular…bold`.
- Mouvements : `--carlys-duration-instant…deliberate`,
  `--carlys-easing-standard|decelerate|accelerate|emphasized`.

## Composants (10)

`CarlysProvider`, `Button` (variant `primary|secondary|ghost|destructive`,
size `sm|md|lg`, `isLoading`, `isExpanded`, `icon`), `Card` (`onClick` la
rend cliquable), `Badge` (`neutral|primary|accent|warning`), `Metric`
(`value`, `label`, `size="lg"` pour la métrique héro en couleur primaire),
`TextField` (`label`, `hint`, `error`), `SearchField`, `LoadingIndicator`,
`EmptyState` (`title`, `message`, `icon`, `action`), `ErrorState`
(`title`, `message`, `onRetry`).

## Où est la vérité

Lis `styles.css` (tokens générés depuis `tokens.json` + styles composants)
avant d'inventer un style, et le `.d.ts` de chaque composant pour son API
exacte. Contexte produit : Carlys est une app de fitness française —
contenus réalistes en français (séances, exercices, kcal, kg).

## Exemple idiomatique

```jsx
<CarlysProvider>
  <div style={{ padding: 'var(--carlys-spacing-md)', display: 'grid', gap: 'var(--carlys-spacing-sm)' }}>
    <Card>
      <Metric value="2759 kcal" label="Objectif quotidien" size="lg" />
      <Badge variant="accent">Prendre du muscle</Badge>
    </Card>
    <Button isExpanded>Démarrer une séance</Button>
  </div>
</CarlysProvider>
```
