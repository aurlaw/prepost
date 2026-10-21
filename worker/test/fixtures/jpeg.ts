// Builds synthetic JPEG byte arrays at runtime. They are structurally valid
// (markers, segments) but carry no real image data — no photos in the repo.

export interface JpegOptions {
  width: number;
  height: number;
  /** SOF marker: 0xc0 (baseline) or 0xc2 (progressive). Default 0xc0. */
  sof?: number;
  /** EXIF orientation to embed in an APP1 segment. Omit for no EXIF. */
  orientation?: number;
  byteOrder?: "II" | "MM";
  /** Raw APP1 payload (after the length field), e.g. to test corrupt EXIF. */
  app1?: Uint8Array;
  /** Insert a DHT segment before the SOF. */
  dhtBeforeSof?: boolean;
  /** Number of APP0-style filler segments before the SOF. */
  fillers?: number;
  /** Leave out the SOF marker entirely. */
  omitSof?: boolean;
}

function segment(marker: number, payload: Uint8Array): Uint8Array {
  const len = payload.length + 2;
  return Uint8Array.from([0xff, marker, len >> 8, len & 0xff, ...payload]);
}

export function exifPayload(orientation: number, byteOrder: "II" | "MM" = "II"): Uint8Array {
  const le = byteOrder === "II";
  const u16 = (v: number) => (le ? [v & 0xff, v >> 8] : [v >> 8, v & 0xff]);
  const u32 = (v: number) =>
    le ? [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, v >>> 24] : [v >>> 24, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
  const tiff = [
    ...(le ? [0x49, 0x49] : [0x4d, 0x4d]),
    ...u16(42),
    ...u32(8), // IFD0 offset
    ...u16(1), // entry count
    ...u16(0x0112), ...u16(3), ...u32(1), ...u16(orientation), 0, 0,
    ...u32(0), // next IFD
  ];
  return Uint8Array.from([0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...tiff]);
}

export function makeJpeg(o: JpegOptions): Uint8Array {
  const parts: Uint8Array[] = [Uint8Array.from([0xff, 0xd8])];
  if (o.app1) parts.push(segment(0xe1, o.app1));
  else if (o.orientation !== undefined) parts.push(segment(0xe1, exifPayload(o.orientation, o.byteOrder)));
  for (let i = 0; i < (o.fillers ?? 0); i++) parts.push(segment(0xe0, new Uint8Array(16).fill(0x20)));
  if (o.dhtBeforeSof) parts.push(segment(0xc4, new Uint8Array(20)));
  if (!o.omitSof) {
    const { width: w, height: h } = o;
    parts.push(segment(o.sof ?? 0xc0, Uint8Array.from([8, h >> 8, h & 0xff, w >> 8, w & 0xff, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1])));
  }
  parts.push(segment(0xda, Uint8Array.from([1, 1, 0, 0, 0x3f, 0])));
  parts.push(Uint8Array.from([0x12, 0x34, 0x56, 0xff, 0xd9]));

  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}
