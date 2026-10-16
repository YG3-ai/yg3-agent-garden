import { GardenEnv } from './control.mjs'
import { GodotWorker } from './godot.mjs'

export class GodotTrainingEnv {
  constructor(environment, worker) {
    this.environment = environment
    this.worker = worker
  }

  static async create(options = {}) {
    const environment = new GardenEnv(options)
    const worker = await GodotWorker.start({ width: environment.width, height: environment.height })
    return new GodotTrainingEnv(environment, worker)
  }

  async #replaceObservation(lifecycle) {
    const frame = await this.worker.renderTrainingFrame(this.environment.snapshot(), {
      width: this.environment.width,
      height: this.environment.height,
    })
    return {
      ...lifecycle,
      observation: {
        rgbPng: frame.png,
        metadata: lifecycle.observation.metadata,
      },
      labels: {
        segmentationPng: frame.segmentationPng,
        segmentationLegend: frame.segmentationLegend,
        calibration: frame.calibration,
        depthFloat32: frame.depthFloat32,
        depthMetadata: frame.depthMetadata,
      },
    }
  }

  async reset(options) {
    return this.#replaceObservation(this.environment.reset(options))
  }

  async step(action) {
    return this.#replaceObservation(this.environment.step(action))
  }

  snapshot() {
    return this.environment.snapshot()
  }

  trajectory() {
    return this.environment.trajectory()
  }

  async close() {
    this.environment.close()
    await this.worker.close()
  }
}
