// Acceptance-only helpers. WebCodecs permits different chroma reconstruction
// when rendering a subsampled VideoFrame into an RGB canvas. Test color at a
// shared 8x8 area resolution and every locally flat pixel; test the decoder's
// actual YUV samples separately, byte for byte, before any RGB conversion.
globalThis.FluvieBrowserPixelOracle = (() => {
  // Fixed 8-bit Y'CbCr-to-R'G'B' reference, independent of the host/wasm
  // libswscale version. Kr/Kb are BT.601 or BT.709; limited range uses 16..235
  // luma and 16..240 chroma. Chroma samples are reconstructed at pixel centers.
  function referenceRgb(yuv, width, height, matrix, fullRange) {
    if (!['bt601', 'bt709'].includes(matrix) || yuv.length !== width * height * 3 / 2) {
      throw Error('Invalid independent YUV reference');
    }
    const kr = matrix === 'bt709' ? 0.2126 : 0.299;
    const kb = matrix === 'bt709' ? 0.0722 : 0.114;
    const kg = 1 - kr - kb, ySize = width * height, cw = width / 2, ch = height / 2;
    const result = new Uint8Array(width * height * 4);
    const clamp = value => Math.max(0, Math.min(255, Math.round(value)));
    function chroma(plane, x, y) {
      const cx = Math.max(0, Math.min(cw - 1, x / 2 - 0.25));
      const cy = Math.max(0, Math.min(ch - 1, y / 2 - 0.25));
      const left = Math.floor(cx), top = Math.floor(cy), dx = cx - left, dy = cy - top;
      const offset = ySize + (plane - 1) * ySize / 4;
      const sample = (xx, yy) => yuv[offset + yy * cw + xx];
      return sample(left, top) * (1 - dx) * (1 - dy) +
        sample(Math.min(left + 1, cw - 1), top) * dx * (1 - dy) +
        sample(left, Math.min(top + 1, ch - 1)) * (1 - dx) * dy +
        sample(Math.min(left + 1, cw - 1), Math.min(top + 1, ch - 1)) * dx * dy;
    }
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const p = y * width + x;
      const luma = (yuv[p] - (fullRange ? 0 : 16)) * (fullRange ? 1 : 255 / 219);
      const cb = (chroma(1, x, y) - 128) * (fullRange ? 1 : 255 / 224);
      const cr = (chroma(2, x, y) - 128) * (fullRange ? 1 : 255 / 224);
      result[p * 4] = clamp(luma + 2 * (1 - kr) * cr);
      result[p * 4 + 1] = clamp(luma - 2 * kb * (1 - kb) / kg * cb - 2 * kr * (1 - kr) / kg * cr);
      result[p * 4 + 2] = clamp(luma + 2 * (1 - kb) * cb);
      result[p * 4 + 3] = 255;
    }
    return result;
  }

  function assertPixels(actual, reference, width, height, label) {
    const bytes = width * height * 4;
    if (actual.length !== bytes || reference.length !== bytes || width % 8 || height % 8) {
      throw Error(`${label}: unexpected RGBA dimensions`);
    }
    let fullError = 0, areaError = 0, flatError = 0, flatPixels = 0;
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const p = (y * width + x) * 4;
      if (actual[p + 3] !== 255) throw Error(`${label}: opaque fixture lost alpha at ${x},${y}`);
      let flat = x >= 2 && y >= 2 && x < width - 2 && y < height - 2;
      for (let dy = -2; flat && dy <= 2; dy++) for (let dx = -2; flat && dx <= 2; dx++) {
        const q = ((y + dy) * width + x + dx) * 4;
        for (let c = 0; c < 3; c++) if (Math.abs(reference[p + c] - reference[q + c]) > 3) flat = false;
      }
      if (flat) flatPixels++;
      for (let c = 0; c < 3; c++) {
        const error = (actual[p + c] - reference[p + c]) ** 2;
        fullError += error;
        if (flat) flatError += error;
      }
    }
    for (let y = 0; y < height; y += 8) for (let x = 0; x < width; x += 8) {
      for (let c = 0; c < 3; c++) {
        let difference = 0;
        for (let dy = 0; dy < 8; dy++) for (let dx = 0; dx < 8; dx++) {
          const p = ((y + dy) * width + x + dx) * 4 + c;
          difference += actual[p] - reference[p];
        }
        areaError += (difference / 64) ** 2;
      }
    }
    const result = {
      fullRgbaRms: Math.sqrt(fullError / (width * height * 3)),
      area8Rms: Math.sqrt(areaError / (width * height / 64 * 3)),
      flatPixelRms: Math.sqrt(flatError / (flatPixels * 3)),
      flatPixelFraction: flatPixels / (width * height),
    };
    if (result.flatPixelFraction < 0.3 || result.area8Rms > 3 || result.flatPixelRms > 3) {
      throw Error(`${label}: decoded colors differ from independent reference: ${JSON.stringify(result)}`);
    }
    return result;
  }

  function packI420(raw, layout, format, width, height) {
    if (width % 2 || height % 2 || !['I420', 'NV12'].includes(format) ||
        layout.length !== (format === 'I420' ? 3 : 2)) throw Error(`Unsupported native frame layout: ${format}`);
    const packed = new Uint8Array(width * height * 3 / 2);
    let target = 0;
    for (let plane = 0; plane < 3; plane++) {
      const rows = plane === 0 ? height : height / 2;
      const columns = plane === 0 ? width : width / 2;
      const interleaved = format === 'NV12' && plane > 0;
      const source = layout[interleaved ? 1 : plane];
      for (let y = 0; y < rows; y++) for (let x = 0; x < columns; x++) {
        const offset = source.offset + y * source.stride + x * (interleaved ? 2 : 1) + (interleaved ? plane - 1 : 0);
        if (offset >= raw.length) throw Error('Native plane exceeds its copied buffer');
        packed[target++] = raw[offset];
      }
    }
    return packed;
  }

  function assertNative(actual, reference, label) {
    if (actual.length !== reference.length) throw Error(`${label}: native frame length differs`);
    for (let i = 0; i < actual.length; i++) {
      if (actual[i] !== reference[i]) throw Error(`${label}: native YUV differs at byte ${i}: ${actual[i]} != ${reference[i]}`);
    }
    return { bytes: actual.length, mismatches: 0 };
  }
  function packRgba(raw, layout, format, width, height) {
    if (!['RGBA', 'RGBX', 'BGRA', 'BGRX'].includes(format) || layout.length !== 1) {
      throw Error(`Unsupported native RGB layout: ${format}`);
    }
    const packed = new Uint8Array(width * height * 4), plane = layout[0];
    const blueFirst = format.startsWith('B'), opaque = format.endsWith('X');
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const source = plane.offset + y * plane.stride + x * 4, target = (y * width + x) * 4;
      if (source + 3 >= raw.length) throw Error('Native RGB exceeds its copied buffer');
      packed[target] = raw[source + (blueFirst ? 2 : 0)];
      packed[target + 1] = raw[source + 1];
      packed[target + 2] = raw[source + (blueFirst ? 0 : 2)];
      packed[target + 3] = opaque ? 255 : raw[source + 3];
    }
    return packed;
  }
  return { referenceRgb, assertPixels, packI420, packRgba, assertNative };
})();
