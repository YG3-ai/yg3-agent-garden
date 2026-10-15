import { randomUUID } from 'node:crypto'
import { encodeRgbPng } from './png.mjs'

const WORLD_ID = 'yg3-operations-recovery-v1'
const MAP = [
  '##############',
  '#............#',
  '#..##........#',
  '#..#.....D...#',
  '#..#..A......#',
  '#.....###....#',
  '#............#',
  '#.B......C...#',
  '#............#',
  '#....##......#',
  '#............#',
  '##############',
]

const STATIONS = {
  A: { name: 'Audience Signal Console', color: [248, 188, 70] },
  B: { name: 'Writing Engine Console', color: [76, 194, 255] },
  C: { name: 'Publishing Rail Console', color: [210, 91, 255] },
  D: { name: 'Reliability Relay', color: [97, 224, 137] },
}

const sessions = new Map()

function clone(value) {
  return structuredClone(value)
}

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

function initialWorkflow() {
  return {
    audienceSignal: 'unknown',
    draft: 'absent',
    publishingRail: 'stale_route',
    railDiagnosed: false,
    package: 'absent',
    published: false,
    failures: [],
    recoveries: 0,
  }
}

function makeSession(seed = 0, restoredState) {
  const session = restoredState
    ? { ...clone(restoredState), id: randomUUID(), trajectory: [] }
    : {
        id: randomUUID(),
        worldId: WORLD_ID,
        seed,
        x: 6.5,
        z: 9.5,
        yaw: seededAngle(seed),
        step: 0,
        collisions: 0,
        workflow: initialWorkflow(),
        trajectory: [],
      }
  sessions.set(session.id, session)
  return session
}

function requireSession(id) {
  const session = sessions.get(id)
  if (!session) throw new Error(`Unknown episode: ${id}`)
  return session
}

function stationColor(tile, session) {
  if (tile === 'A' && session.workflow.audienceSignal === 'captured') return [255, 232, 139]
  if (tile === 'B' && session.workflow.package === 'ready') return [141, 229, 255]
  if (tile === 'C' && session.workflow.publishingRail === 'overloaded') return [255, 55, 47]
  if (tile === 'C' && session.workflow.published) return [240, 169, 255]
  if (tile === 'D' && session.workflow.recoveries > 0) return [174, 255, 192]
  return STATIONS[tile]?.color ?? [53, 168, 126]
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
    const base = stationColor(hit.tile, session)
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

function milestones(session) {
  const workflow = session.workflow
  return [
    workflow.audienceSignal === 'captured',
    workflow.draft === 'held',
    workflow.railDiagnosed,
    workflow.recoveries > 0,
    workflow.package === 'ready',
    workflow.published,
  ].filter(Boolean).length
}

function publicMetadata(session) {
  return {
    episodeId: session.id,
    worldId: session.worldId,
    step: session.step,
    completedMilestones: milestones(session),
    taskComplete: session.workflow.published,
  }
}

function observation(session, width = 256, height = width, transportPaddingKiB = 0) {
  return { png: render(session, width, height, transportPaddingKiB), publicState: publicMetadata(session) }
}

function comparableState(session) {
  return {
    pose: { x: session.x, z: session.z, yaw: session.yaw },
    step: session.step,
    collisions: session.collisions,
    workflow: clone(session.workflow),
  }
}

function stateDiff(before, after, prefix = '') {
  const changes = []
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after ?? {})])
  for (const key of keys) {
    const path = prefix ? `${prefix}.${key}` : key
    const left = before?.[key]
    const right = after?.[key]
    if (left && right && typeof left === 'object' && typeof right === 'object' && !Array.isArray(left) && !Array.isArray(right)) {
      changes.push(...stateDiff(left, right, path))
    } else if (JSON.stringify(left) !== JSON.stringify(right)) {
      changes.push({ path, before: clone(left), after: clone(right) })
    }
  }
  return changes
}

function addFailure(session, kind) {
  session.workflow.failures.push({ kind, step: session.step })
}

function moveAction(session, direction, distance) {
  const heading = direction === 'backward' ? session.yaw + Math.PI : session.yaw
  const amount = Math.min(1, Math.max(0.05, distance))
  const nextX = session.x + Math.cos(heading) * amount
  const nextZ = session.z + Math.sin(heading) * amount
  if (isBlocked(nextX, nextZ)) {
    session.collisions += 1
    return { moved: false, feedback: 'Movement was blocked by an obstacle.' }
  }
  session.x = nextX
  session.z = nextZ
  return { moved: true, feedback: 'Movement completed.' }
}

function turnAction(session, degrees) {
  session.yaw = (session.yaw + (degrees * Math.PI) / 180) % (Math.PI * 2)
  return { turnedDegrees: degrees, feedback: `Turned ${degrees} degrees.` }
}

function interactWithStation(session, tile) {
  const workflow = session.workflow
  if (tile === 'A') {
    workflow.audienceSignal = 'captured'
    return { changed: true, station: 'A', feedback: 'Audience Signal captured: a client needs a useful operational brief delivered through the publishing rail.' }
  }
  if (tile === 'B') {
    if (workflow.audienceSignal !== 'captured') {
      addFailure(session, 'missing_audience_signal')
      return { changed: false, station: 'B', failure: 'missing_audience_signal', feedback: 'Writing Engine refused the run: no audience signal has been captured.' }
    }
    if (workflow.publishingRail === 'stale_route') {
      workflow.draft = 'held'
      workflow.publishingRail = 'overloaded'
      addFailure(session, 'stale_route_overload')
      return { changed: true, station: 'B', failure: 'stale_route_overload', feedback: 'The Writing Engine produced a draft, but delivery failed. A warning pulse travelled toward the Publishing Rail.' }
    }
    if (workflow.publishingRail === 'overloaded') {
      return { changed: false, station: 'B', feedback: 'The draft remains held while the Publishing Rail reports an unresolved overload.' }
    }
    workflow.package = 'ready'
    return { changed: true, station: 'B', feedback: 'The Writing Engine rebuilt the brief against the repaired route. The delivery package is ready.' }
  }
  if (tile === 'C') {
    if (workflow.publishingRail === 'overloaded') {
      workflow.railDiagnosed = true
      return { changed: true, station: 'C', feedback: 'Publishing Rail diagnostic: a stale route caused the overload. The Reliability Relay can now perform a safe reset.' }
    }
    if (workflow.package === 'ready') {
      workflow.published = true
      return { changed: true, station: 'C', feedback: 'Publishing Rail accepted the repaired package. The operational brief is live.' }
    }
    return { changed: false, station: 'C', feedback: 'Publishing Rail is available, but no delivery package is waiting.' }
  }
  if (tile === 'D') {
    if (workflow.publishingRail !== 'overloaded') {
      return { changed: false, station: 'D', feedback: 'Reliability Relay reports no active fault to reset.' }
    }
    if (!workflow.railDiagnosed) {
      addFailure(session, 'reset_without_diagnosis')
      return { changed: false, station: 'D', failure: 'reset_without_diagnosis', feedback: 'Reliability Relay refused a blind reset. Inspect the affected system first.' }
    }
    workflow.publishingRail = 'ready'
    workflow.recoveries += 1
    return { changed: true, station: 'D', feedback: 'Reliability Relay cleared the stale route and restored the Publishing Rail.' }
  }
  return { changed: false, feedback: 'Nothing responds within reach.' }
}

function interactAction(session) {
  const aheadX = session.x + Math.cos(session.yaw) * 0.85
  const aheadZ = session.z + Math.sin(session.yaw) * 0.85
  return interactWithStation(session, tileAt(aheadX, aheadZ))
}

function verify(session) {
  return {
    completed: session.workflow.published,
    reward: session.workflow.published ? 1 : 0,
    milestones: milestones(session),
    failures: session.workflow.failures.length,
    recoveries: session.workflow.recoveries,
    collisions: session.collisions,
    steps: session.step,
  }
}

function perform(session, action) {
  const before = comparableState(session)
  session.step += 1
  let outcome
  if (action.type === 'move') outcome = moveAction(session, action.direction, action.distance)
  else if (action.type === 'turn') outcome = turnAction(session, action.degrees)
  else if (action.type === 'interact') outcome = interactAction(session)
  else if (action.type === 'finish') outcome = { ...verify(session), feedback: session.workflow.published ? 'Task completed.' : 'Task incomplete.' }
  else throw new Error(`Unknown action type: ${action.type}`)
  const after = comparableState(session)
  const transition = {
    index: session.trajectory.length,
    action: clone(action),
    outcome: clone(outcome),
    stateDiff: stateDiff(before, after),
    verifier: verify(session),
  }
  session.trajectory.push(transition)
  return { outcome, transition }
}

function snapshot(session) {
  const state = clone(session)
  delete state.id
  delete state.trajectory
  return { schemaVersion: 1, worldId: WORLD_ID, state }
}

export const garden = {
  worldId: WORLD_ID,
  createEpisode: makeSession,
  getEpisode: requireSession,
  observe(id, width, height, transportPaddingKiB = 0) {
    return observation(requireSession(id), width, height, transportPaddingKiB)
  },
  metadata(id) {
    return publicMetadata(requireSession(id))
  },
  act(id, action) {
    return perform(requireSession(id), action)
  },
  move(id, direction, distance) {
    return perform(requireSession(id), { type: 'move', direction, distance }).outcome
  },
  turn(id, degrees) {
    return perform(requireSession(id), { type: 'turn', degrees }).outcome
  },
  interact(id) {
    return perform(requireSession(id), { type: 'interact' }).outcome
  },
  finish(id) {
    return perform(requireSession(id), { type: 'finish' }).outcome
  },
  verify(id) {
    return verify(requireSession(id))
  },
  snapshot(id) {
    return snapshot(requireSession(id))
  },
  fork(snapshotValue) {
    if (snapshotValue?.schemaVersion !== 1 || snapshotValue?.worldId !== WORLD_ID) throw new Error('Incompatible world snapshot')
    return makeSession(snapshotValue.state.seed, snapshotValue.state)
  },
  trajectory(id) {
    return clone(requireSession(id).trajectory)
  },
  deleteEpisode(id) {
    return sessions.delete(id)
  },
  episodeCount() {
    return sessions.size
  },
}
