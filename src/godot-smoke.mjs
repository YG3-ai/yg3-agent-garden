import assert from 'node:assert/strict'
import { garden } from './world.mjs'
import { findGodot, GodotWorker } from './godot.mjs'

const binary = await findGodot()
const episode = garden.createEpisode(17)
const snapshot = garden.snapshot(episode.id)
snapshot.state.x = 8.5
snapshot.state.z = 7.5
snapshot.state.yaw = 0

const worker = await GodotWorker.start({ width: 128, height: 96 })
const result = await worker.render(snapshot, { width: 128, height: 96 })
assert.equal(result.png.subarray(1, 4).toString('ascii'), 'PNG')
assert.equal(result.png.readUInt32BE(16), 128)
assert.equal(result.png.readUInt32BE(20), 96)
const second = await worker.render(snapshot, { width: 128, height: 96 })
assert.deepEqual(second.png, result.png)
await worker.close()
console.log(JSON.stringify({ godot: binary, imageBytes: result.png.length, width: 128, height: 96, persistentRenders: 2 }))
