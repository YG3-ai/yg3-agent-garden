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

  async #withWorker(operation) {
    const worker = await this.#worker()
    try {
      return await operation(worker)
    } catch (firstError) {
      this.workerPromise = undefined
      try {
        await worker.close()
      } catch {
        // A failed worker may already be gone.
      }
      try {
        return await operation(await this.#worker())
      } catch (retryError) {
        retryError.cause = firstError
        throw retryError
      }
    }
  }

  async observe(episodeId, width, height, transportPaddingKiB = 0) {
    if (this.mode === 'cpu' || transportPaddingKiB > 0) {
      return garden.observe(episodeId, width, height, transportPaddingKiB)
    }
    const snapshot = garden.snapshot(episodeId)
    const rendered = await this.#withWorker(worker => worker.render(snapshot, { width, height }))
    return { png: rendered.png, publicState: garden.metadata(episodeId) }
  }

  async move(episodeId, direction, distance) {
    if (this.mode === 'cpu') return garden.move(episodeId, direction, distance)
    const snapshot = garden.snapshot(episodeId)
    const resolution = await this.#withWorker(worker => worker.resolveMovement(snapshot, { direction, distance }))
    return garden.moveResolved(episodeId, direction, distance, resolution)
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
