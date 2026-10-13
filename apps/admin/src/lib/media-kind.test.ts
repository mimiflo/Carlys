import { describe, expect, it } from 'vitest';
import { mediaKindOf, withServerType } from './media-kind';

describe('mediaKindOf', () => {
  it('lit le genre dans le type MIME', () => {
    expect(mediaKindOf({ type: 'image/webp', name: 'a.webp' })).toBe('IMAGE');
    expect(mediaKindOf({ type: 'video/mp4', name: 'a.mp4' })).toBe('VIDEO');
    expect(mediaKindOf({ type: 'model/gltf-binary', name: 'a.glb' })).toBe('MESH_3D');
  });

  it('un .glb sans type passe par son extension', () => {
    expect(mediaKindOf({ type: '', name: 'squat.GLB' })).toBe('MESH_3D');
  });

  it('un .glb sans type part avec le type de son extension', () => {
    expect(withServerType(new File(['x'], 'squat.glb')).type).toBe('model/gltf-binary');
    expect(withServerType(new File(['x'], 'scene.gltf')).type).toBe('model/gltf+json');
    const photo = new File(['x'], 'a.webp', { type: 'image/webp' });
    expect(withServerType(photo)).toBe(photo);
  });

  it('un type refusé par le serveur est refusé ici aussi', () => {
    expect(mediaKindOf({ type: 'application/pdf', name: 'a.pdf' })).toBeNull();
    expect(mediaKindOf({ type: '', name: 'a.txt' })).toBeNull();
  });
});
