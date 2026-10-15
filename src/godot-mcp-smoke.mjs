import assert from 'node:assert/strict'
import { Client, StreamableHTTPClientTransport } from '@modelcontextprotocol/client'
import { startGardenServer } from './server.mjs'

const running = await startGardenServer({ rendererMode: 'godot' })
const client = new Client({ name: 'garden-godot-smoke', version: '0.1.0' })
try {
  await client.connect(new StreamableHTTPClientTransport(running.url))
  const entered = await client.callTool({ name: 'enter_world', arguments: { seed: 31, imageWidth: 128 } })
  const episodeId = entered.structuredContent.episodeId
  const firstImage = entered.content.find(item => item.type === 'image')
  assert.ok(firstImage)
  const turned = await client.callTool({ name: 'turn', arguments: { episodeId, degrees: 45, imageWidth: 128 } })
  const secondImage = turned.content.find(item => item.type === 'image')
  assert.ok(secondImage)
  assert.notEqual(secondImage.data, firstImage.data)
  assert.equal(turned.structuredContent.x, undefined)
  await client.callTool({ name: 'finish', arguments: { episodeId } })
  console.log(JSON.stringify({ renderer: 'godot', mcpImages: 2, imageWidth: 128, privilegedPoseLeaked: false }))
} finally {
  await client.close()
  await running.close()
}
