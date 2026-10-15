import { deflateSync } from 'node:zlib'

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])

const CRC_TABLE = new Uint32Array(256)
for (let n = 0; n < 256; n += 1) {
  let c = n
  for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  CRC_TABLE[n] = c >>> 0
}

function crc32(buffer) {
  let crc = 0xffffffff
  for (const byte of buffer) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const name = Buffer.from(type, 'ascii')
  const body = Buffer.concat([name, data])
  const length = Buffer.allocUnsafe(4)
  const checksum = Buffer.allocUnsafe(4)
  length.writeUInt32BE(data.length)
  checksum.writeUInt32BE(crc32(body))
  return Buffer.concat([length, body, checksum])
}

function deterministicBytes(length, seed) {
  const bytes = Buffer.allocUnsafe(length)
  let value = (seed ^ 0x9e3779b9) >>> 0
  for (let index = 0; index < length; index += 1) {
    value ^= value << 13
    value ^= value >>> 17
    value ^= value << 5
    bytes[index] = value & 0xff
  }
  return bytes
}

export function encodeRgbPng(width, height, rgb, paddingBytes = 0) {
  if (rgb.length !== width * height * 3) throw new Error('RGB buffer has the wrong size')

  const scanlines = Buffer.allocUnsafe(height * (width * 3 + 1))
  for (let y = 0; y < height; y += 1) {
    const destination = y * (width * 3 + 1)
    scanlines[destination] = 0
    rgb.copy(scanlines, destination + 1, y * width * 3, (y + 1) * width * 3)
  }

  const header = Buffer.allocUnsafe(13)
  header.writeUInt32BE(width, 0)
  header.writeUInt32BE(height, 4)
  header[8] = 8
  header[9] = 2
  header[10] = 0
  header[11] = 0
  header[12] = 0

  const chunks = [
    PNG_SIGNATURE,
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(scanlines, { level: 3 })),
  ]
  // A private ancillary PNG chunk keeps the image valid while allowing the
  // transport benchmark to model realistic compressed frame sizes without
  // pretending the tiny raycaster has photographic entropy.
  if (paddingBytes > 0) chunks.push(chunk('ygGD', deterministicBytes(paddingBytes, width * 65537 + height)))
  chunks.push(chunk('IEND', Buffer.alloc(0)))
  return Buffer.concat(chunks)
}
