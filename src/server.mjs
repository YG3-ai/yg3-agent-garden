import { createServer } from 'node:http'
import { toNodeHandler } from '@modelcontextprotocol/node'
import { createGardenHandler } from './mcp.mjs'
import { GardenRenderer } from './renderer.mjs'

export async function startGardenServer({ port = 0, host = '127.0.0.1', rendererMode = process.env.GARDEN_RENDERER ?? 'cpu' } = {}) {
  const renderer = new GardenRenderer({ mode: rendererMode })
  const handler = createGardenHandler({ renderer })
  const nodeHandler = toNodeHandler(handler)
  const server = createServer((request, response) => {
    if (request.url !== '/mcp') {
      response.writeHead(404, { 'content-type': 'application/json' })
      response.end(JSON.stringify({ error: 'not_found' }))
      return
    }
    nodeHandler(request, response)
  })

  await new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(port, host, resolve)
  })

  const address = server.address()
  const actualPort = typeof address === 'object' && address ? address.port : port
  return {
    url: new URL(`http://${host}:${actualPort}/mcp`),
    close: async () => {
      await handler.close()
      await new Promise((resolve, reject) => server.close(error => (error ? reject(error) : resolve())))
      await renderer.close()
    },
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT ?? 8787)
  const running = await startGardenServer({ port })
  console.log(`YG3 Agent Garden MCP listening at ${running.url}`)
}
