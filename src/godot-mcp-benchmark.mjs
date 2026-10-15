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

const running = await startGardenServer({ rendererMode: 'godot' })
const client = new Client({ name: 'garden-godot-mcp-benchmark', version: '0.1.0' })
try {
  await client.connect(new StreamableHTTPClientTransport(running.url))
  const coldStarted = performance.now()
  const entered = await client.callTool({ name: 'enter_world', arguments: { seed: 41, imageWidth: 256 } })
  const coldStartMs = performance.now() - coldStarted
  const episodeId = entered.structuredContent.episodeId
  const latencies = []
  let bytes = imageBytes(entered)
  for (let index = 0; index < 20; index += 1) {
    const started = performance.now()
    const result = await client.callTool({
      name: 'turn',
      arguments: { episodeId, degrees: 9, imageWidth: 256 },
    })
    latencies.push(performance.now() - started)
    bytes = imageBytes(result)
  }
  await client.callTool({ name: 'finish', arguments: { episodeId } })
  console.table([{
    coldStartMs: Number(coldStartMs.toFixed(2)),
    actions: latencies.length,
    imageKiB: Number((bytes / 1024).toFixed(1)),
    p50ActionMs: Number(percentile(latencies, 0.5).toFixed(2)),
    p95ActionMs: Number(percentile(latencies, 0.95).toFixed(2)),
    actionsPerSecond: Number((1000 / (latencies.reduce((sum, value) => sum + value, 0) / latencies.length)).toFixed(2)),
  }])
} finally {
  await client.close()
  await running.close()
}
