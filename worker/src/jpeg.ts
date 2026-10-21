export interface JpegInfo {
  /** Displayed width (EXIF orientation applied). */
  width: number;
  /** Displayed height (EXIF orientation applied). */
  height: number;
  /** EXIF orientation 1–8; 1 when absent or unparseable. */
  orientation: number;
}

const SOI = 0xd8;
const EOI = 0xd9;
const SOS = 0xda;
const APP1 = 0xe1;

function isSof(marker: number): boolean {
  // SOF0–SOF15, excluding DHT (C4), JPG (C8) and DAC (CC).
  return marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
}

function isStandalone(marker: number): boolean {
  // TEM and RST0–7 carry no length field.
  return marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7);
}

function u16be(b: Uint8Array, at: number): number {
  return (b[at]! << 8) | b[at + 1]!;
}

/**
 * Reads dimensions and EXIF orientation from JPEG bytes. Pure and bounds-checked:
 * truncated or malformed input returns null, never throws or loops.
 */
export function parseJpeg(bytes: Uint8Array): JpegInfo | null {
  const n = bytes.length;
  if (n < 4 || bytes[0] !== 0xff || bytes[1] !== SOI) return null;

  let orientation = 1;
  let off = 2;

  while (off < n) {
    if (bytes[off] !== 0xff) return null;
    while (off < n && bytes[off] === 0xff) off++; // fill bytes
    if (off >= n) return null;
    const marker = bytes[off]!;
    off++;

    if (marker === EOI || marker === SOS) return null; // no SOF before image data
    if (isStandalone(marker)) continue;

    if (off + 2 > n) return null;
    const len = u16be(bytes, off);
    if (len < 2 || off + len > n) return null;

    if (isSof(marker)) {
      if (len < 7) return null;
      const height = u16be(bytes, off + 3);
      const width = u16be(bytes, off + 5);
      if (width === 0 || height === 0) return null;
      const swap = orientation >= 5 && orientation <= 8;
      return { width: swap ? height : width, height: swap ? width : height, orientation };
    }

    if (marker === APP1 && orientation === 1) {
      orientation = readExifOrientation(bytes.subarray(off + 2, off + len));
    }

    off += len;
  }
  return null;
}

const EXIF_HEADER = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"

/** Returns the IFD0 orientation tag, or 1 if absent or anything is off. */
export function readExifOrientation(app1: Uint8Array): number {
  if (app1.length < EXIF_HEADER.length + 8) return 1;
  for (let i = 0; i < EXIF_HEADER.length; i++) if (app1[i] !== EXIF_HEADER[i]) return 1;

  const tiff = app1.subarray(EXIF_HEADER.length);
  const t = tiff.length;
  let little: boolean;
  if (tiff[0] === 0x49 && tiff[1] === 0x49) little = true;
  else if (tiff[0] === 0x4d && tiff[1] === 0x4d) little = false;
  else return 1;

  const u16 = (at: number) => (little ? tiff[at]! | (tiff[at + 1]! << 8) : (tiff[at]! << 8) | tiff[at + 1]!);
  const u32 = (at: number) =>
    little
      ? (tiff[at]! | (tiff[at + 1]! << 8) | (tiff[at + 2]! << 16) | (tiff[at + 3]! << 24)) >>> 0
      : ((tiff[at]! << 24) | (tiff[at + 1]! << 16) | (tiff[at + 2]! << 8) | tiff[at + 3]!) >>> 0;

  if (u16(2) !== 42) return 1;
  const ifd = u32(4);
  if (ifd < 8 || ifd + 2 > t) return 1;
  const count = u16(ifd);
  for (let i = 0; i < count; i++) {
    const entry = ifd + 2 + i * 12;
    if (entry + 12 > t) return 1;
    if (u16(entry) !== 0x0112) continue;
    if (u16(entry + 2) !== 3) return 1; // must be SHORT
    const value = u16(entry + 8);
    return value >= 1 && value <= 8 ? value : 1;
  }
  return 1;
}
