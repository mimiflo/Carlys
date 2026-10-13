import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { auditActionLabel, auditActionTone } from '@/lib/audit-labels';
import { Segmented } from './segmented';
import { Stat } from './stat';

describe('Segmented', () => {
  it('ce sont de vrais boutons radio : le choix part par le clavier comme à la souris', () => {
    const onChange = vi.fn();
    render(
      <Segmented
        legend="Statut"
        name="statut"
        options={[
          { value: 'OPEN', label: 'Ouverts' },
          { value: 'RESOLVED', label: 'Résolus' },
        ]}
        value="OPEN"
        onChange={onChange}
      />,
    );
    expect(screen.getByRole('radio', { name: 'Ouverts' })).toBeChecked();
    expect(screen.getByRole('group', { name: 'Statut' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('radio', { name: 'Résolus' }));
    expect(onChange).toHaveBeenCalledWith('RESOLVED');
  });
});

describe('Stat', () => {
  it('sans animation possible, la valeur finale s’affiche d’emblée, une seule fois', () => {
    render(<Stat label="Comptes" value={1284} />);
    expect(screen.getAllByText('1 284')).toHaveLength(1);
  });
});

describe('audit-labels', () => {
  it('traduit une action connue, garde l’identifiant d’une inconnue', () => {
    expect(auditActionLabel('admin.user_suspended')).toBe('Compte suspendu');
    expect(auditActionLabel('action.inconnue')).toBe('action.inconnue');
  });

  it('un refus ressort, une alerte de sécurité rougit', () => {
    expect(auditActionTone('auth.login_failed')).toBe('warning');
    expect(auditActionTone('admin.login_blocked_lockout')).toBe('warning');
    expect(auditActionTone('auth.refresh_reuse_detected')).toBe('danger');
    expect(auditActionTone('admin.exercise_published')).toBe('neutral');
  });
});
