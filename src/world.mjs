import { randomUUID } from 'node:crypto'
import { encodeRgbPng } from './png.mjs'

const MAP = [
  '############',
  '#..........#',
  '#..##......#',
  '#..#.......#',
  '#..#..A....#',
  '#.....###..#',
  '#..........#',
  '#.B.....C..#',
  '#..........#',
  '#....##....#',
  '#..........#',
  '############',
]

const STATIONS = {
  A: { name: 'Audience Signal Console', color: [248, 188, 70] },
  B: { name: 'Writing Engine Console', color: [76, 194, 255] },
  C: { name: 'Publishing Rail Console', color: [210, 91, 255] },
}

const sessions = new Map()

function seededAngle(seed) {
  let hash = 2166136261
  for (const char of String(seed)) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619)
  return ((hash >>> 0) / 0xffffffff) * Math.PI * 2
}

function tileAt(x, z) {
  const row = MAP[Math.floor(z)]
  return row?.[Math.floor(x)] ?? '#'
}

function isBlocked(x, z) {
  return tileAt(x, z) === '#'
}

function makeSession(seed = 0) {
  const id = randomUUID()
  const session = {
    id,
    seed,
    x: 5.5,
    z: 8.5,
    yaw: seededAngle(seed),
    step: 0,
    activated: new Set(),
    collisions: 0,
  }
  sessions.set(id, session)
  return session
}

function requireSession(id) {
  const session = sessions.get(id)
  if (!session) throw new Error(`Unknown episode: ${id}`)
  return session
}

function castRay(session, angle) {
  const dx = Math.cos(angle)
  const dz = Math.sin(angle)
  let distance = 0
  let tile = '.'
  while (distance < 20) {
    distance += 0.025
    tile = tileAt(session.x + dx * distance, session.z + dz * distance)
    if (tile !== '.') break
  }
  return { distance, tile }
}

function paintPixel(rgb, width, x, y, color) {
  const index = (y * width + x) * 3
  rgb[index] = color[0]
  rgb[index + 1] = color[1]
  rgb[index + 2] = color[2]
}

function render(session, width, height, transportPaddingKiB = 0) {
  const rgb = Buffer.allocUnsafe(width * height * 3)
  const horizon = Math.floor(height * 0.48)

  for (let y = 0; y < height; y += 1) {
    const sky = y < horizon
    const t = sky ? y / Math.max(1, horizon) : (y - horizon) / Math.max(1, height - horizon)
    const color = sky
      ? [Math.round(22 + t * 22), Math.round(29 + t * 25), Math.round(48 + t * 32)]
      : [Math.round(34 - t * 20), Math.round(37 - t * 22), Math.round(43 - t * 24)]
    for (let x = 0; x < width; x += 1) paintPixel(rgb, width, x, y, color)
  }

  const fov = Math.PI / 3
  for (let column = 0; column < width; column += 1) {
    const rayAngle = session.yaw + (column / Math.max(1, width - 1) - 0.5) * fov
    const hit = castRay(session, rayAngle)
    const corrected = Math.max(0.08, hit.distance * Math.cos(rayAngle - session.yaw))
    const wallHeight = Math.min(height, Math.floor(height * 0.82 / corrected))
    const top = Math.max(0, horizon - Math.floor(wallHeight / 2))
    const bottom = Math.min(height - 1, top + wallHeight)
    const base = STATIONS[hit.tile]?.color ?? [53, 168, 126]
    const shade = Math.max(0.22, 1 - corrected / 13)
    const color = base.map(channel => Math.round(channel * shade))
    for (let y = top; y <= bottom; y += 1) paintPixel(rgb, width, column, y, color)
  }

  const cx = Math.floor(width / 2)
  const cy = Math.floor(height / 2)
  for (let delta = -5; delta <= 5; delta += 1) {
    if (cx + delta >= 0 && cx + delta < width) paintPixel(rgb, width, cx + delta, cy, [245, 245, 245])
    if (cy + delta >= 0 && cy + delta < height) paintPixel(rgb, width, cx, cy + delta, [245, 245, 245])
  }

  return encodeRgbPng(width, height, rgb, transportPaddingKiB * 1024)
}

function observation(session, width = 256, height = width, transportPaddingKiB = 0) {
  const png = render(session, width, height, transportPaddingKiB)
  return {
    png,
    publicState: {
      episodeId: session.id,
      step: session.step,
      activatedStations: session.activated.size,
      taskComplete: session.activated.size === Object.keys(STATIONS).length,
    },
  }
}

function move(session, direction, distance) {
  const heading = direction === 'backward' ? session.yaw + Math.PI : session.yaw
  const amount = Math.min(1, Math.max(0.05, distance))
  const nextX = session.x + Math.cos(heading) * amount
  const nextZ = session.z + Math.sin(heading) * amount
  session.step += 1
  if (isBlocked(nextX, nextZ)) {
    session.collisions += 1
    return { moved: false, feedback: 'Movement was blocked by an obstacle.' }
  }
  session.x = nextX
  session.z = nextZ
  return { moved: true, feedback: 'Movement completed.' }
}

function turn(session, degrees) {
  session.yaw = (session.yaw + (degrees * Math.PI) / 180) % (Math.PI * 2)
  session.step += 1
  return { turnedDegrees: degrees }
}

function interact(session) {
  session.step += 1
  const aheadX = session.x + Math.cos(session.yaw) * 0.85
  const aheadZ = session.z + Math.sin(session.yaw) * 0.85
  const tile = tileAt(aheadX, aheadZ)
  const station = STATIONS[tile]
  if (!station) return { changed: false, feedback: 'Nothing responds within reach.' }
  session.activated.add(tile)
  return { changed: true, feedback: `${station.name} is now active.` }
}

function finish(session) {
  session.step += 1
  const completed = session.activated.size === Object.keys(STATIONS).length
  return {
    completed,
    reward: completed ? 1 : 0,
    activatedStations: session.activated.size,
    collisions: session.collisions,
    steps: session.step,
  }
}

export const garden = {
  createEpisode: makeSession,
  getEpisode: requireSession,
  observe(id, width, height, transportPaddingKiB = 0) {
    return observation(requireSession(id), width, height, transportPaddingKiB)
  },
  move(id, direction, distance) {
    return move(requireSession(id), direction, distance)
  },
  turn(id, degrees) {
    return turn(requireSession(id), degrees)
  },
  interact(id) {
    return interact(requireSession(id))
  },
  finish(id) {
    return finish(requireSession(id))
  },
  deleteEpisode(id) {
    return sessions.delete(id)
  },
  episodeCount() {
    return sessions.size
  },
}
