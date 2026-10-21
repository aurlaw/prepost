import { describe, expect, it } from "vitest";
import { parseJpeg } from "../src/jpeg";
import { exifPayload, makeJpeg } from "./fixtures/jpeg";

describe("parseJpeg", () => {
  it("reads SOF0 dimensions", () => {
    expect(parseJpeg(makeJpeg({ width: 1080, height: 1350 }))).toEqual({ width: 1080, height: 1350, orientation: 1 });
  });

  it("reads SOF2 (progressive) dimensions", () => {
    expect(parseJpeg(makeJpeg({ width: 1200, height: 800, sof: 0xc2 }))).toMatchObject({ width: 1200, height: 800 });
  });

  it("skips DHT and filler segments before the SOF", () => {
    expect(parseJpeg(makeJpeg({ width: 640, height: 480, dhtBeforeSof: true, fillers: 3 }))).toMatchObject({
      width: 640,
      height: 480,
    });
  });

  it.each(["II", "MM"] as const)("swaps dimensions for orientation 6 (%s)", (byteOrder) => {
    expect(parseJpeg(makeJpeg({ width: 1350, height: 1080, orientation: 6, byteOrder }))).toEqual({
      width: 1080,
      height: 1350,
      orientation: 6,
    });
  });

  it.each([5, 7, 8])("swaps dimensions for orientation %i", (orientation) => {
    expect(parseJpeg(makeJpeg({ width: 300, height: 200, orientation }))).toMatchObject({ width: 200, height: 300 });
  });

  it.each([1, 2, 3, 4])("does not swap for orientation %i", (orientation) => {
    expect(parseJpeg(makeJpeg({ width: 300, height: 200, orientation }))).toEqual({ width: 300, height: 200, orientation });
  });

  it("does not swap when EXIF is absent", () => {
    expect(parseJpeg(makeJpeg({ width: 300, height: 200 }))).toEqual({ width: 300, height: 200, orientation: 1 });
  });

  it("treats corrupt EXIF as orientation 1", () => {
    const exif = exifPayload(6);
    const badMagic = exif.slice();
    badMagic[8] = 0x99; // TIFF magic 42 broken
    const badOffset = exif.slice();
    badOffset[10] = 0xff; // IFD0 offset points past the end
    const truncated = exif.slice(0, 16);
    const notExif = new TextEncoder().encode("http://ns.adobe.com/xap/1.0/\0<x/>");
    for (const app1 of [badMagic, badOffset, truncated, notExif]) {
      expect(parseJpeg(makeJpeg({ width: 300, height: 200, app1 }))).toEqual({ width: 300, height: 200, orientation: 1 });
    }
  });

  it("ignores out-of-range orientation values", () => {
    expect(parseJpeg(makeJpeg({ width: 300, height: 200, orientation: 9 }))).toMatchObject({ orientation: 1 });
  });

  it("returns null when there is no SOF before SOS", () => {
    expect(parseJpeg(makeJpeg({ width: 1, height: 1, omitSof: true }))).toBeNull();
  });

  it("returns null for truncated input at every length", () => {
    const full = makeJpeg({ width: 1080, height: 1350, orientation: 6, dhtBeforeSof: true });
    const sofEnd = full.findIndex((b, i) => b === 0xff && full[i + 1] === 0xc0) + 2 + 17;
    for (let len = 0; len < sofEnd; len++) {
      expect(parseJpeg(full.subarray(0, len))).toBeNull();
    }
  });

  it("returns null for non-JPEG input", () => {
    expect(parseJpeg(new TextEncoder().encode("GIF89a........"))).toBeNull();
    expect(parseJpeg(new Uint8Array())).toBeNull();
  });

  it("returns null for a segment length that overruns the buffer", () => {
    expect(parseJpeg(Uint8Array.from([0xff, 0xd8, 0xff, 0xe0, 0xff, 0xff, 0, 0]))).toBeNull();
  });

  it("returns null for a zero-length segment instead of looping", () => {
    expect(parseJpeg(Uint8Array.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x00, 0xff, 0xd9]))).toBeNull();
  });
});
