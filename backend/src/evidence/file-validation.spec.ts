import { detectFileType, extensionMatches, sanitizeFilename } from './file-validation';

const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(20)]);
const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(20)]);
const webp = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP'), Buffer.alloc(10)]);
const pdf = Buffer.concat([Buffer.from('%PDF-1.7\n'), Buffer.alloc(10)]);

describe('upload validation', () => {
  it('detects allowed types by magic bytes', () => {
    expect(detectFileType(jpeg)?.mime).toBe('image/jpeg');
    expect(detectFileType(png)?.mime).toBe('image/png');
    expect(detectFileType(webp)?.mime).toBe('image/webp');
    expect(detectFileType(pdf)?.kind).toBe('DOCUMENT');
  });
  it('rejects scripts, html, svg, executables and tiny files', () => {
    expect(detectFileType(Buffer.from('<?php system($_GET["c"]); ?>'))).toBeNull();
    expect(detectFileType(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'))).toBeNull();
    expect(detectFileType(Buffer.from('<html><body>hi</body></html>'))).toBeNull();
    expect(detectFileType(Buffer.from([0x4d, 0x5a, 0x90, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0]))).toBeNull(); // PE/EXE
    expect(detectFileType(Buffer.from([0x7f, 0x45, 0x4c, 0x46, 0, 0, 0, 0, 0, 0, 0, 0, 0]))).toBeNull(); // ELF
    expect(detectFileType(Buffer.from([0xff, 0xd8]))).toBeNull();
  });
  it('extension must match content (polyglot / double extension)', () => {
    const t = detectFileType(jpeg)!;
    expect(extensionMatches('photo.jpg', t)).toBe(true);
    expect(extensionMatches('photo.JPEG', t)).toBe(true);
    expect(extensionMatches('shell.php', t)).toBe(false);
    expect(extensionMatches('photo.jpg.exe', t)).toBe(false);
    expect(extensionMatches('photo.png', t)).toBe(false);
    expect(extensionMatches(undefined, t)).toBe(true);
  });
  it('sanitises filenames (path traversal, control chars)', () => {
    expect(sanitizeFilename('../../etc/passwd')).toBe('passwd');
    expect(sanitizeFilename('..\\..\\windows\\system32\\cmd.exe')).toBe('cmd.exe');
    expect(sanitizeFilename('rasm<script>.jpg')).toBe('rasm_script_.jpg');
    expect(sanitizeFilename('...hidden')).toBe('hidden');
    expect(sanitizeFilename('')).toBeNull();
    expect(sanitizeFilename("G'isht 3-qavat.jpg")).toBe('G_isht 3-qavat.jpg');
  });
});
