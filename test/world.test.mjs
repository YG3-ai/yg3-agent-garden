import assert from 'node:assert/strict'
import test from 'node:test'
import { garden } from '../src/world.mjs'

test('seeded episodes render deterministic first observations', () => {
  const first = garden.createEpisode(42)
  const second = garden.createEpisode(42)
  const firstPng = garden.observe(first.id, 128, 128).png
  const secondPng = garden.observe(second.id, 128, 128).png
  assert.deepEqual(firstPng, secondPng)
})

test('agent observations do not expose privileged coordinates', () => {
  const episode = garden.createEpisode(1)
  const observation = garden.observe(episode.id, 64, 64)
  assert.equal(observation.publicState.x, undefined)
  assert.equal(observation.publicState.z, undefined)
  assert.equal(observation.publicState.yaw, undefined)
  assert.equal(observation.png.subarray(1, 4).toString('ascii'), 'PNG')
})

test('invalid episodes fail closed', () => {
  assert.throws(() => garden.observe('00000000-0000-0000-0000-000000000000', 64, 64), /Unknown episode/)
})
