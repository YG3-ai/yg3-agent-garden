import { McpServer, createMcpHandler } from '@modelcontextprotocol/server'
import * as z from 'zod/v4'
import { garden } from './world.mjs'

function imageResult(observation, text) {
  return {
    content: [
      { type: 'text', text },
      { type: 'image', data: observation.png.toString('base64'), mimeType: 'image/png' },
    ],
    structuredContent: observation.publicState,
  }
}

export function createGardenMcpServer() {
  const server = new McpServer(
    { name: 'yg3-agent-garden', version: '0.0.1' },
    {
      capabilities: { tools: {} },
      instructions:
        'Explore through first-person observations. Coordinates, maps, scene graphs, and hidden simulator state are intentionally unavailable.',
    },
  )

  server.registerTool(
    'enter_world',
    {
      description: 'Start a fresh, deterministic YG3 spatial episode.',
      inputSchema: z.object({ seed: z.number().int().default(0), imageWidth: z.number().int().min(64).max(768).default(256) }),
    },
    async ({ seed, imageWidth }) => {
      const episode = garden.createEpisode(seed)
      const observation = garden.observe(episode.id, imageWidth, imageWidth)
      return imageResult(
        observation,
        'Activate the Audience Signal, Writing Engine, and Publishing Rail consoles. You must discover them visually; no map or coordinates are provided.',
      )
    },
  )

  server.registerTool(
    'observe',
    {
      description: 'Receive the current first-person RGB observation without privileged spatial state.',
      inputSchema: z.object({
        episodeId: z.string().uuid(),
        width: z.number().int().min(64).max(768).default(256),
        height: z.number().int().min(64).max(768).default(256),
        transportPaddingKiB: z.number().int().min(0).max(1024).default(0).describe('Benchmark-only private PNG payload padding.'),
      }),
    },
    async ({ episodeId, width, height, transportPaddingKiB }) =>
      imageResult(garden.observe(episodeId, width, height, transportPaddingKiB), 'First-person RGB observation.'),
  )

  server.registerTool(
    'move',
    {
      description: 'Move relative to the current facing direction, then receive a fresh RGB observation.',
      inputSchema: z.object({
        episodeId: z.string().uuid(),
        direction: z.enum(['forward', 'backward']),
        distance: z.number().min(0.05).max(1).default(0.5),
        imageWidth: z.number().int().min(64).max(768).default(256),
      }),
    },
    async ({ episodeId, direction, distance, imageWidth }) => {
      const outcome = garden.move(episodeId, direction, distance)
      return imageResult(garden.observe(episodeId, imageWidth, imageWidth), outcome.feedback)
    },
  )

  server.registerTool(
    'turn',
    {
      description: 'Rotate the embodied camera, then receive a fresh RGB observation.',
      inputSchema: z.object({
        episodeId: z.string().uuid(),
        degrees: z.number().min(-180).max(180),
        imageWidth: z.number().int().min(64).max(768).default(256),
      }),
    },
    async ({ episodeId, degrees, imageWidth }) => {
      garden.turn(episodeId, degrees)
      return imageResult(garden.observe(episodeId, imageWidth, imageWidth), `Turned ${degrees} degrees.`)
    },
  )

  server.registerTool(
    'interact',
    {
      description: 'Interact with the object directly ahead, then receive a fresh RGB observation.',
      inputSchema: z.object({ episodeId: z.string().uuid(), imageWidth: z.number().int().min(64).max(768).default(256) }),
    },
    async ({ episodeId, imageWidth }) => {
      const outcome = garden.interact(episodeId)
      return imageResult(garden.observe(episodeId, imageWidth, imageWidth), outcome.feedback)
    },
  )

  server.registerTool(
    'finish',
    {
      description: 'End the episode and receive the deterministic verifier result.',
      inputSchema: z.object({ episodeId: z.string().uuid() }),
    },
    async ({ episodeId }) => {
      const result = garden.finish(episodeId)
      garden.deleteEpisode(episodeId)
      return {
        content: [{ type: 'text', text: result.completed ? 'Task completed.' : 'Task incomplete.' }],
        structuredContent: result,
      }
    },
  )

  return server
}

export function createGardenHandler() {
  return createMcpHandler(createGardenMcpServer, { responseMode: 'json' })
}
