import { performance } from 'node:perf_hooks'
import { garden } from './world.mjs'
import { GodotWorker } from './godot.mjs'

function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p))]
}

const episode = garden.createEpisode(23)
const started = performance.now()
const worker = await GodotWorker.start({ width: 256 })
const startupMs = performance.now() - started

try {
  for (let index = 0; index < 3; index += 1) await worker.render(garden.snapshot(episode.id), { width: 256 })
  const latencies = []
  let bytes = 0
  for (let index = 0; index < 20; index += 1) {
    garden.turn(episode.id, 9)
    const frameStarted = performance.now()
    const result = await worker.render(garden.snapshot(episode.id), { width: 256 })
    latencies.push(performance.now() - frameStarted)
    bytes = result.png.length
  }
  console.table([{
    startupMs: Number(startupMs.toFixed(2)),
    frames: latencies.length,
    imageKiB: Number((bytes / 1024).toFixed(1)),
    p50Ms: Number(percentile(latencies, 0.5).toFixed(2)),
    p95Ms: Number(percentile(latencies, 0.95).toFixed(2)),
    framesPerSecond: Number((1000 / (latencies.reduce((sum, value) => sum + value, 0) / latencies.length)).toFixed(2)),
  }])
} finally {
  await worker.close()
}
