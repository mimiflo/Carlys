import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { Badge } from './badge.js';
import { Button } from './button.js';
import { Card } from './card.js';
import { ErrorState } from './error-state.js';
import { Metric } from './metric.js';
import { CarlysProvider } from './provider.js';
import { TextField } from './text-field.js';

describe('CarlysProvider', () => {
  it('applique la racine et le thème demandé', () => {
    const { container } = render(
      <CarlysProvider theme="oled">
        <span>contenu</span>
      </CarlysProvider>,
    );
    const root = container.firstElementChild;
    expect(root).toHaveClass('carlys-root');
    expect(root).toHaveAttribute('data-carlys-theme', 'oled');
  });
});

describe('Button', () => {
  it('déclenche onClick et porte la variante', () => {
    const onClick = vi.fn();
    render(
      <Button variant="secondary" onClick={onClick}>
        Valider
      </Button>,
    );
    const button = screen.getByRole('button', { name: 'Valider' });
    expect(button).toHaveClass('carlys-button--secondary');
    button.click();
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('en chargement : désactivé, indicateur visible', () => {
    render(<Button isLoading>Envoi</Button>);
    const button = screen.getByRole('button');
    expect(button).toBeDisabled();
    expect(button.querySelector('.carlys-spinner')).not.toBeNull();
  });
});

describe('Card', () => {
  it('est un bouton quand onClick est fourni', () => {
    const onClick = vi.fn();
    render(
      <Card onClick={onClick} aria-label="Ouvrir la fiche">
        Fiche
      </Card>,
    );
    screen.getByRole('button', { name: 'Ouvrir la fiche' }).click();
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('est une simple surface sinon', () => {
    render(<Card>Contenu</Card>);
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.getByText('Contenu')).toHaveClass('carlys-card');
  });
});

describe('Badge et Metric', () => {
  it('rendent variante et libellés', () => {
    render(
      <>
        <Badge variant="accent">Premium</Badge>
        <Metric value="2759 kcal" label="Objectif quotidien" size="lg" />
      </>,
    );
    expect(screen.getByText('Premium')).toHaveClass('carlys-badge--accent');
    expect(
      screen.getByRole('group', { name: 'Objectif quotidien : 2759 kcal' }),
    ).toBeInTheDocument();
  });
});

describe('TextField', () => {
  it("l'erreur remplace l'aide et marque le champ invalide", () => {
    render(<TextField label="Taille (cm)" hint="Par exemple 178" error="Requis" />);
    const input = screen.getByLabelText('Taille (cm)');
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByRole('alert')).toHaveTextContent('Requis');
    expect(screen.queryByText('Par exemple 178')).toBeNull();
  });
});

describe('ErrorState', () => {
  it('propose la relance', () => {
    const onRetry = vi.fn();
    render(<ErrorState title="Indisponible" onRetry={onRetry} />);
    screen.getByRole('button', { name: 'Réessayer' }).click();
    expect(onRetry).toHaveBeenCalledOnce();
  });
});
