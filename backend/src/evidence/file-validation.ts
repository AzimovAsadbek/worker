/**
 * Upload validation by content (magic bytes), not by what the client claims.
 * Only inert formats are accepted; SVG/HTML/executables are rejected.
 */
export interface DetectedType {
  mime: 'image/jpeg' | 'image/png' | 'image/webp' | 'application/pdf';
  ext: 'jpg' | 'png' | 'webp' | 'pdf';
  kind: 'PHOTO' | 'DOCUMENT';
}

export function detectFileType(buf: Buffer): DetectedType | null {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { mime: 'image/jpeg', ext: 'jpg', kind: 'PHOTO' };
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return { mime: 'image/png', ext: 'png', kind: 'PHOTO' };
  if (buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') {
    return { mime: 'image/webp', ext: 'webp', kind: 'PHOTO' };
  }
  if (buf.subarray(0, 5).toString('latin1') === '%PDF-') return { mime: 'application/pdf', ext: 'pdf', kind: 'DOCUMENT' };
  return null;
}

const EXT_ALIASES: Record<string, DetectedType['ext']> = { jpg: 'jpg', jpeg: 'jpg', png: 'png', webp: 'webp', pdf: 'pdf' };

/** The declared extension (if any) must agree with the detected content. */
export function extensionMatches(originalName: string | undefined, detected: DetectedType): boolean {
  if (!originalName || !originalName.includes('.')) return true;
  const ext = originalName.split('.').pop()!.toLowerCase();
  return EXT_ALIASES[ext] === detected.ext;
}

/** Keeps a short, display-only name: no paths, no control chars, no double extensions games. */
export function sanitizeFilename(name: string | undefined): string | null {
  if (!name) return null;
  const base = name.split(/[\\/]/).pop() ?? '';
  const cleaned = base
    .normalize('NFKC')
    .replace(/[^\p{L}\p{N}._ -]/gu, '_')
    .replace(/\.{2,}/g, '.')
    .replace(/^[.\s]+/, '')
    .slice(0, 120)
    .trim();
  return cleaned || null;
}
