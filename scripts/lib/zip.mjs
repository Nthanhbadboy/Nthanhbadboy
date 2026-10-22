/**
 * ZIP helpers shared by the Windows build scripts.
 *
 * The MSIX writer deliberately mirrors what Microsoft's own packer does
 * (microsoft/msix-packaging, src/msix/pack/{DeflateStream,AppxBlockMapWriter}.cpp):
 *
 *   - raw deflate, level 9, memLevel 9, one Z_FULL_FLUSH per 64 KiB block, so every block
 *     decompresses on its own and its compressed size can be recorded in AppxBlockMap.xml;
 *   - a final Z_FINISH on an empty tail (the 2 trailing bytes no block claims);
 *   - Local File Header size reported as 30 + name length (no extra fields are written).
 *
 * A .nupkg is also a ZIP, so the reader doubles as the NuGet extractor.
 */

import { createHash } from 'node:crypto';
import { deflateRawSync, inflateRawSync } from 'node:zlib';

export const BLOCK_SIZE = 65536; // 64 KiB, the MSIX block map granularity
const Z_FULL_FLUSH = 3;

/* ------------------------------------------------------------------- checksums */

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

export function crc32(buf) {
  let crc = -1;
  for (let i = 0; i < buf.length; i += 1) {
    crc = CRC_TABLE[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ -1) >>> 0;
}

export function sha256(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

/* ------------------------------------------------------------------ compression */

/**
 * Deflate `data` the way MSIX does: block by block with a full flush in between.
 * Returns the concatenated stream plus the per-block compressed sizes and the
 * base64 SHA-256 of each *uncompressed* block (what AppxBlockMap.xml records).
 */
export function deflateInBlocks(data, blockSize = BLOCK_SIZE) {
  const parts = [];
  const blocks = [];
  for (let offset = 0; offset < data.length; offset += blockSize) {
    const block = data.subarray(offset, Math.min(offset + blockSize, data.length));
    const compressed = deflateRawSync(block, {
      level: 9,
      memLevel: 9,
      finishFlush: Z_FULL_FLUSH,
    });
    parts.push(compressed);
    blocks.push({
      hash: createHash('sha256').update(block).digest('base64'),
      size: compressed.length,
      rawSize: block.length,
    });
  }
  // Closing an empty stream with Z_FINISH emits the final empty stored block.
  const tail = deflateRawSync(Buffer.alloc(0), { level: 9, memLevel: 9 });
  parts.push(tail);
  const compressed = Buffer.concat(parts);
  const roundTrip = inflateRawSync(compressed);
  if (!roundTrip.equals(data)) {
    throw new Error('deflateInBlocks: round trip mismatch (internal error)');
  }
  return { compressed, blocks, tailBytes: tail.length };
}

/* ------------------------------------------------------------------- zip reader */

/** Read a ZIP's central directory into a Map of name -> entry descriptor. */
export function zipEntries(buf) {
  let eocd = -1;
  const floor = Math.max(0, buf.length - 22 - 0xffff);
  for (let i = buf.length - 22; i >= floor; i -= 1) {
    if (buf.readUInt32LE(i) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error('not a ZIP archive (EOCD signature missing)');

  // Microsoft's packer (and some NuGet feeds) emit zip64 records with 0xFFFF/0xFFFFFFFF
  // placeholders in the classic EOCD; follow the locator when that is the case.
  let count = buf.readUInt16LE(eocd + 10);
  let offset = buf.readUInt32LE(eocd + 16);
  if (count === 0xffff || offset === 0xffffffff) {
    const locator = eocd - 20;
    if (locator < 0 || buf.readUInt32LE(locator) !== 0x07064b50) {
      throw new Error('zip64 archive without a zip64 EOCD locator');
    }
    const zip64Eocd = Number(buf.readBigUInt64LE(locator + 8));
    if (buf.readUInt32LE(zip64Eocd) !== 0x06064b50) {
      throw new Error('corrupt zip64 EOCD record');
    }
    count = Number(buf.readBigUInt64LE(zip64Eocd + 32));
    offset = Number(buf.readBigUInt64LE(zip64Eocd + 48));
  }

  const entries = new Map();
  for (let n = 0; n < count; n += 1) {
    if (buf.readUInt32LE(offset) !== 0x02014b50) throw new Error('corrupt ZIP central directory');
    const method = buf.readUInt16LE(offset + 10);
    const crc = buf.readUInt32LE(offset + 16);
    let compSize = buf.readUInt32LE(offset + 20);
    let rawSize = buf.readUInt32LE(offset + 24);
    const nameLen = buf.readUInt16LE(offset + 28);
    const extraLen = buf.readUInt16LE(offset + 30);
    const commentLen = buf.readUInt16LE(offset + 32);
    let localHeaderOffset = buf.readUInt32LE(offset + 42);
    const name = buf.toString('utf8', offset + 46, offset + 46 + nameLen);

    // zip64: placeholder values live in the 0x0001 extra field, in the order the
    // corresponding classic fields appear (raw size, compressed size, header offset).
    if (rawSize === 0xffffffff || compSize === 0xffffffff || localHeaderOffset === 0xffffffff) {
      const extraStart = offset + 46 + nameLen;
      let at = extraStart;
      let zip64 = null;
      while (at + 4 <= extraStart + extraLen) {
        const tag = buf.readUInt16LE(at);
        const size = buf.readUInt16LE(at + 2);
        if (tag === 0x0001) {
          zip64 = buf.subarray(at + 4, at + 4 + size);
          break;
        }
        at += 4 + size;
      }
      if (!zip64) throw new Error(`${name}: zip64 placeholders without a zip64 extra field`);
      let cursor = 0;
      if (rawSize === 0xffffffff) {
        rawSize = Number(zip64.readBigUInt64LE(cursor));
        cursor += 8;
      }
      if (compSize === 0xffffffff) {
        compSize = Number(zip64.readBigUInt64LE(cursor));
        cursor += 8;
      }
      if (localHeaderOffset === 0xffffffff) {
        localHeaderOffset = Number(zip64.readBigUInt64LE(cursor));
      }
    }
    entries.set(name, {
      name,
      method,
      compSize,
      rawSize,
      crc,
      localHeaderOffset,
    });
    offset += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

/** Local file header size (30 + name + extra), as recorded in AppxBlockMap.xml. */
/**
 * Size of the local file header as MSIX records it in AppxBlockMap.xml: 30 + name length.
 * Microsoft's writer ignores any extra field here, and this writer never emits one.
 */
export function localHeaderSize(buf, entry) {
  const at = entry.localHeaderOffset;
  if (buf.readUInt32LE(at) !== 0x04034b50) throw new Error(`bad local header for ${entry.name}`);
  return 30 + buf.readUInt16LE(at + 26) + buf.readUInt16LE(at + 28);
}

export function zipRead(buf, entry) {
  const at = entry.localHeaderOffset;
  if (buf.readUInt32LE(at) !== 0x04034b50) throw new Error(`bad local header for ${entry.name}`);
  const nameLen = buf.readUInt16LE(at + 26);
  const extraLen = buf.readUInt16LE(at + 28);
  const start = at + 30 + nameLen + extraLen;
  const data = buf.subarray(start, start + entry.compSize);
  if (entry.method === 0) return Buffer.from(data);
  if (entry.method === 8) return inflateRawSync(data);
  throw new Error(`unsupported compression method ${entry.method} for ${entry.name}`);
}

/* ------------------------------------------------------------------- zip writer */

/** Fixed timestamp so two builds of the same inputs produce identical packages. */
const DOS_TIME = 0; // 00:00:00
const DOS_DATE = ((2024 - 1980) << 9) | (1 << 5) | 1; // 2024-01-01

/**
 * Write a ZIP archive. Each file is `{ name, data, method }` with method 8 (deflate) or
 * 0 (store), plus an optional `precomputed` result from deflateInBlocks(). Returns the archive bytes; every entry records its own LfhSize so the caller
 * can build the MSIX block map without re-parsing the archive.
 */
export function buildZip(files) {
  const local = [];
  const central = [];
  let offset = 0;

  for (const file of files) {
    const nameBuf = Buffer.from(file.name, 'utf8');
    if (nameBuf.length > 0xffff) throw new Error(`entry name too long: ${file.name}`);
    const method = file.method === 0 ? 0 : 8;
    let stored = file.data;
    let blocks = [];
    if (method === 8) {
      // Callers that need the block hashes before the archive exists (MSIX writes
      // AppxBlockMap.xml into the same zip) can pass the deflated result in.
      const deflated = file.precomputed ?? deflateInBlocks(file.data);
      stored = deflated.compressed;
      blocks = deflated.blocks;
    } else {
      for (let at = 0; at < file.data.length; at += BLOCK_SIZE) {
        const block = file.data.subarray(at, Math.min(at + BLOCK_SIZE, file.data.length));
        blocks.push({
          hash: createHash('sha256').update(block).digest('base64'),
          size: block.length,
          rawSize: block.length,
        });
      }
    }

    const header = Buffer.alloc(30);
    header.writeUInt32LE(0x04034b50, 0);
    header.writeUInt16LE(20, 4); // version needed to extract
    header.writeUInt16LE(0, 6); // flags: names are ASCII, sizes are known up front
    header.writeUInt16LE(method, 8);
    header.writeUInt16LE(DOS_TIME, 10);
    header.writeUInt16LE(DOS_DATE, 12);
    header.writeUInt32LE(crc32(file.data), 14);
    header.writeUInt32LE(stored.length, 18);
    header.writeUInt32LE(file.data.length, 22);
    header.writeUInt16LE(nameBuf.length, 26);
    header.writeUInt16LE(0, 28); // no extra field, ever

    const record = Buffer.alloc(46);
    record.writeUInt32LE(0x02014b50, 0);
    record.writeUInt16LE(20, 4); // version made by
    record.writeUInt16LE(20, 6); // version needed
    record.writeUInt16LE(0, 8); // flags
    record.writeUInt16LE(method, 10);
    record.writeUInt16LE(DOS_TIME, 12);
    record.writeUInt16LE(DOS_DATE, 14);
    record.writeUInt32LE(crc32(file.data), 16);
    record.writeUInt32LE(stored.length, 20);
    record.writeUInt32LE(file.data.length, 24);
    record.writeUInt16LE(nameBuf.length, 28);
    record.writeUInt16LE(0, 30); // extra length
    record.writeUInt16LE(0, 32); // comment length
    record.writeUInt16LE(0, 34); // disk number start
    record.writeUInt16LE(0, 36); // internal attributes
    record.writeUInt32LE(0, 38); // external attributes
    record.writeUInt32LE(offset, 42);

    local.push(header, nameBuf, stored);
    central.push(record, nameBuf);
    file.lfhSize = 30 + nameBuf.length;
    file.blocks = blocks;
    file.compressedSize = stored.length;
    file.crc = crc32(file.data);
    file.method = method;
    offset += header.length + nameBuf.length + stored.length;
  }

  const centralBuf = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(files.length, 8);
  eocd.writeUInt16LE(files.length, 10);
  eocd.writeUInt32LE(centralBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);
  eocd.writeUInt16LE(0, 20);

  return Buffer.concat([...local, centralBuf, eocd]);
}
