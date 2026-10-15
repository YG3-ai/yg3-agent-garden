import assert from 'node:assert/strict'
import test from 'node:test'
import { GardenEnv, VectorGardenEnv } from '../src/control.mjs'
import { garden } from '../src/world.mjs'

function faceAndInteract(episodeId, x, z, tileX, tileZ) {
  const base = garden.snapshot(episodeId)
  base.state.x = x
  base.state.z = z
  base.state.yaw = Math.atan2(tileZ + 0.5 - z, tileX + 0.5 - x)
  return garden.fork(base)
}

test('the operational world requires diagnosis before recovery', () => {
  const episode = garden.createEpisode(3)
  let positioned = faceAndInteract(episode.id, 7.5, 4.5, 6, 4)
  assert.match(garden.interact(positioned.id).feedback, /Audience Signal captured/)
  positioned = faceAndInteract(positioned.id, 3.5, 7.5, 2, 7)
  assert.equal(garden.interact(positioned.id).failure, 'stale_route_overload')
  const prematureReset = faceAndInteract(positioned.id, 8.5, 3.5, 9, 3)
  assert.equal(garden.interact(prematureReset.id).failure, 'reset_without_diagnosis')
  positioned = faceAndInteract(positioned.id, 8.5, 7.5, 9, 7)
  assert.match(garden.interact(positioned.id).feedback, /stale route/)
  positioned = faceAndInteract(positioned.id, 8.5, 3.5, 9, 3)
  assert.match(garden.interact(positioned.id).feedback, /restored/)
  positioned = faceAndInteract(positioned.id, 3.5, 7.5, 2, 7)
  assert.match(garden.interact(positioned.id).feedback, /package is ready/)
  positioned = faceAndInteract(positioned.id, 8.5, 7.5, 9, 7)
  assert.match(garden.interact(positioned.id).feedback, /brief is live/)
  assert.equal(garden.verify(positioned.id).completed, true)
  assert.equal(garden.verify(positioned.id).recoveries, 1)
})

test('snapshots fork identical state into isolated counterfactual episodes', () => {
  const source = garden.createEpisode(11)
  garden.turn(source.id, 45)
  const saved = garden.snapshot(source.id)
  const left = garden.fork(saved)
  const right = garden.fork(saved)
  assert.deepEqual(garden.observe(left.id, 96, 96).png, garden.observe(right.id, 96, 96).png)
  garden.move(left.id, 'forward', 0.5)
  assert.notDeepEqual(garden.snapshot(left.id).state, garden.snapshot(right.id).state)
})

test('trajectory records privileged state diffs without adding them to observations', () => {
  const environment = new GardenEnv({ width: 64 })
  const reset = environment.reset({ seed: 5 })
  const result = environment.step({ type: 'turn', degrees: 30 })
  const [transition] = environment.trajectory()
  assert.equal(reset.observation.metadata.x, undefined)
  assert.equal(result.observation.metadata.yaw, undefined)
  assert.ok(transition.stateDiff.some(change => change.path === 'pose.yaw'))
  environment.close()
})

test('vector control plane isolates parallel episode lifecycle', () => {
  const vector = new VectorGardenEnv(3, { width: 64 })
  const resets = vector.reset([1, 2, 3])
  const ids = resets.map(item => item.info.episodeId)
  assert.equal(new Set(ids).size, 3)
  const results = vector.step([
    { type: 'turn', degrees: 10 },
    { type: 'turn', degrees: 20 },
    { type: 'turn', degrees: 30 },
  ])
  assert.deepEqual(results.map(item => item.info.verifier.steps), [1, 1, 1])
  vector.close()
})

test('control plane requires reset after termination', () => {
  const environment = new GardenEnv({ width: 64 })
  environment.reset({ seed: 1 })
  const result = environment.step({ type: 'finish' })
  assert.equal(result.terminated, true)
  assert.throws(() => environment.step({ type: 'turn', degrees: 10 }), /Episode is done/)
  environment.close()
})
