'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { planStatus } from '@/lib/status-labels';
import { ExerciseCategoriesCell } from './exercise-categories-cell';
import { ExerciseDeleteCell } from './exercise-delete-cell';
import { ExercisePhotoCell } from './exercise-photo-cell';
import { ExercisePublication } from './exercise-publication';
import { Badge } from './ui/badge';
import { PanelSection, SidePanel } from './ui/side-panel';

/**
 * La fiche d'un exercice, ouverte depuis la liste : tout ce qu'on peut faire
 * d'un exercice, rangé par rubrique, au lieu de cinq colonnes de boutons par
 * ligne. Les gestes sont les mêmes composants qu'avant, testés à part.
 */
export function ExerciseSheet({
  exercise,
  onClose,
}: {
  exercise: AdminExerciseSummary;
  onClose: () => void;
}) {
  return (
    <SidePanel
      title={exercise.name}
      subtitle={
        <span className="flex flex-wrap items-center gap-2">
          <span className="font-mono text-xs">{exercise.slug}</span>
          {exercise.isPremium && <Badge status={planStatus(true)} />}
        </span>
      }
      onClose={onClose}
    >
      <PanelSection title="Photo">
        <ExercisePhotoCell exercise={exercise} layout="panel" />
      </PanelSection>
      <PanelSection title="Catégories">
        <ExerciseCategoriesCell exercise={exercise} inline />
      </PanelSection>
      <PanelSection title="Publication">
        <ExercisePublication exercise={exercise} />
      </PanelSection>
      <PanelSection title="Retrait du catalogue">
        <ExerciseDeleteCell exercise={exercise} />
      </PanelSection>
    </SidePanel>
  );
}
