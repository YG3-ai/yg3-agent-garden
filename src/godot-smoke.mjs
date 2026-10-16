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
const trainingFrame = await worker.renderTrainingFrame(snapshot, { width: 128, height: 96 })
assert.equal(trainingFrame.segmentationPng.subarray(1, 4).toString('ascii'), 'PNG')
assert.notDeepEqual(trainingFrame.segmentationPng, trainingFrame.png)
assert.equal(trainingFrame.calibration.intrinsics.width, 128)
assert.equal(trainingFrame.segmentationLegend.ff00ff.name, 'publishing_rail_console')
assert.equal(trainingFrame.depthFloat32.length, 128 * 96 * 4)
assert.equal(trainingFrame.depthMetadata.convention, 'camera_z')
const centerDepth = trainingFrame.depthFloat32.readFloatLE((48 * 128 + 64) * 4)
assert.ok(
  centerDepth > 0.5 && centerDepth < 0.8,
  `expected center depth between 0.5m and 0.8m, received ${centerDepth}`,
)
await worker.close()
console.log(JSON.stringify({ godot: binary, imageBytes: result.png.length, width: 128, height: 96, persistentRenders: 3, trainingLabels: ['segmentation', 'depth', 'calibration'], centerDepthMeters: Number(centerDepth.toFixed(3)) }))
