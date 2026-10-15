import { performance } from 'node:perf_hooks'
import { Client, StreamableHTTPClientTransport } from '@modelcontextprotocol/client'
import { startGardenServer } from './server.mjs'

function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b)
  return sorted[Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * p))]
}

function imageBytes(result) {
  const image = result.content?.find(item => item.type === 'image')
  return image ? Buffer.byteLength(image.data, 'base64') : 0
}

async function clientFor(url, id) {
  const client = new Client({ name: `garden-spike-${id}`, version: '0.0.1' })
  await client.connect(new StreamableHTTPClientTransport(url))
  return client
}

async function callTimed(client, name, args) {
  const started = performance.now()
  const result = await client.callTool({ name, arguments: args })
  return { result, milliseconds: performance.now() - started }
}

async function benchmarkPayloads(url) {
  const client = await clientFor(url, 'payload')
  const entered = await client.callTool({ name: 'enter_world', arguments: { seed: 7, imageWidth: 128 } })
  const episodeId = entered.structuredContent.episodeId
  const rows = []

  for (const paddingKiB of [0, 32, 128, 512]) {
    const latencies = []
    let bytes = 0
    for (let iteration = 0; iteration < 20; iteration += 1) {
      const sample = await callTimed(client, 'observe', {
        episodeId,
        width: 256,
        height: 256,
        transportPaddingKiB: paddingKiB,
      })
      latencies.push(sample.milliseconds)
      bytes = imageBytes(sample.result)
    }
    rows.push({
      frame: '256x256',
      paddingKiB,
      imageKiB: Number((bytes / 1024).toFixed(1)),
      p50Ms: Number(percentile(latencies, 0.5).toFixed(2)),
      p95Ms: Number(percentile(latencies, 0.95).toFixed(2)),
    })
  }

  await client.callTool({ name: 'finish', arguments: { episodeId } })
  await client.close()
  return rows
}

async function runEpisode(client, seed, steps, imageWidth) {
  const entered = await client.callTool({ name: 'enter_world', arguments: { seed, imageWidth } })
  const episodeId = entered.structuredContent.episodeId
  const latencies = []
  for (let step = 0; step < steps; step += 1) {
    const name = step % 3 === 0 ? 'turn' : 'move'
    const args = name === 'turn'
      ? { episodeId, degrees: step % 2 === 0 ? 30 : -15, imageWidth }
      : { episodeId, direction: 'forward', distance: 0.35, imageWidth }
    const sample = await callTimed(client, name, args)
    latencies.push(sample.milliseconds)
  }
  await client.callTool({ name: 'finish', arguments: { episodeId } })
  return latencies
}

async function benchmarkConcurrency(url) {
  const rows = []
  const steps = 12
  const imageWidth = 256

  for (const concurrency of [1, 2, 4, 8, 16]) {
    const clients = await Promise.all(Array.from({ length: concurrency }, (_, index) => clientFor(url, `${concurrency}-${index}`)))
    const started = performance.now()
    const results = await Promise.all(clients.map((client, index) => runEpisode(client, concurrency * 100 + index, steps, imageWidth)))
    const elapsedSeconds = (performance.now() - started) / 1000
    const latencies = results.flat()
    rows.push({
      concurrentEpisodes: concurrency,
      actionSteps: concurrency * steps,
      stepsPerSecond: Number(((concurrency * steps) / elapsedSeconds).toFixed(2)),
      p50StepMs: Number(percentile(latencies, 0.5).toFixed(2)),
      p95StepMs: Number(percentile(latencies, 0.95).toFixed(2)),
    })
    await Promise.all(clients.map(client => client.close()))
  }
  return rows
}

const running = await startGardenServer()
try {
  console.log(`Benchmarking ${running.url}`)
  console.log('\nImage transport over MCP (fixed 256x256 frame, representative payload sizes)')
  console.table(await benchmarkPayloads(running.url))
  console.log('\nConcurrent episode throughput (256x256 RGB)')
  console.table(await benchmarkConcurrency(running.url))
} finally {
  await running.close()
}
