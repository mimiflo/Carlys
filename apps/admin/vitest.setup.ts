import '@testing-library/jest-dom/vitest';

// jsdom n'implémente pas la fenêtre modale native (`<dialog>.showModal`) :
// le minimum pour que le panneau latéral s'ouvre et se ferme comme dans un
// navigateur — `open`, puis l'évènement `close` à la fermeture.
if (
  typeof HTMLDialogElement !== 'undefined' &&
  typeof HTMLDialogElement.prototype.showModal !== 'function'
) {
  HTMLDialogElement.prototype.showModal = function showModal(this: HTMLDialogElement) {
    this.open = true;
  };
  HTMLDialogElement.prototype.close = function close(this: HTMLDialogElement) {
    if (!this.open) return;
    this.open = false;
    this.dispatchEvent(new Event('close'));
  };
}
