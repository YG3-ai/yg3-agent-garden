import { GodotWorker } from './godot.mjs'
import { garden } from './world.mjs'

export class GardenRenderer {
  constructor({ mode = process.env.GARDEN_RENDERER ?? 'cpu' } = {}) {
    if (!['cpu', 'godot'].includes(mode)) throw new Error(`Unknown Garden renderer: ${mode}`)
    this.mode = mode
    this.workerPromise = undefined
  }

  async #worker() {
    if (!this.workerPromise) this.workerPromise = GodotWorker.start()
    return this.workerPromise
  }

  async observe(episodeId, width, height, transportPaddingKiB = 0) {
    if (this.mode === 'cpu' || transportPaddingKiB > 0) {
      return garden.observe(episodeId, width, height, transportPaddingKiB)
    }
    const snapshot = garden.snapshot(episodeId)
    const worker = await this.#worker()
    try {
      const rendered = await worker.render(snapshot, { width, height })
      return { png: rendered.png, publicState: garden.metadata(episodeId) }
    } catch (firstError) {
      this.workerPromise = undefined
      try {
        await worker.close()
      } catch {
        // A failed worker may already be gone.
      }
      try {
        const rendered = await (await this.#worker()).render(snapshot, { width, height })
        return { png: rendered.png, publicState: garden.metadata(episodeId) }
      } catch (retryError) {
        retryError.cause = firstError
        throw retryError
      }
    }
  }

  async close() {
    if (!this.workerPromise) return
    const workerPromise = this.workerPromise
    this.workerPromise = undefined
    try {
      await (await workerPromise).close()
    } catch {
      // The renderer may already have exited; server shutdown remains safe.
    }
  }
}
