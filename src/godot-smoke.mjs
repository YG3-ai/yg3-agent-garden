import assert from 'node:assert/strict'
import { GodotTrainingEnv } from './control-godot.mjs'
import { GardenEnv } from './control.mjs'
import { garden } from './world.mjs'
import { findGodot, GodotWorker } from './godot.mjs'

const binary = await findGodot()
const episode = garden.createEpisode(17)
const snapshot = garden.snapshot(episode.id)
snapshot.state.x = 8.5
snapshot.state.z = 7.5
snapshot.state.yaw = 0

const worker = await GodotWorker.start({ width: 128, height: 96 })
const freeSnapshot = garden.snapshot(episode.id)
freeSnapshot.state.x = 7.5
freeSnapshot.state.z = 9.5
freeSnapshot.state.yaw = 0
const freeMovement = await worker.resolveMovement(freeSnapshot, { direction: 'forward', distance: 0.5 })
assert.equal(freeMovement.collided, false)
assert.ok(Math.abs(freeMovement.x - 8) < 0.01)
const blockedMovement = await worker.resolveMovement(snapshot, { direction: 'forward', distance: 1 })
assert.equal(blockedMovement.collided, true)
assert.ok(blockedMovement.x > 8.5 && blockedMovement.x < 9)
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
const environment = new GardenEnv({ width: 64, height: 64 })
environment.reset({ snapshot })
const trainingEnvironment = new GodotTrainingEnv(environment, worker)
const physicsStep = await trainingEnvironment.step({ type: 'move', direction: 'forward', distance: 1 })
assert.equal(physicsStep.info.outcome.collided, true)
assert.equal(physicsStep.labels.depthMetadata.unit, 'meter')
await trainingEnvironment.close()
console.log(JSON.stringify({ godot: binary, imageBytes: result.png.length, width: 128, height: 96, persistentRenders: 4, physicsQueries: 3, collisionStopX: Number(blockedMovement.x.toFixed(3)), trainingLabels: ['segmentation', 'depth', 'calibration'], centerDepthMeters: Number(centerDepth.toFixed(3)), trainingPhysicsIntegrated: true }))
