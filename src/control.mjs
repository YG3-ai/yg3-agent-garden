import { garden } from './world.mjs'

function publicObservation(episodeId, width, height) {
  const rendered = garden.observe(episodeId, width, height)
  return { rgbPng: rendered.png, metadata: rendered.publicState }
}

export class GardenEnv {
  constructor({ width = 256, height = width, maxSteps = 256 } = {}) {
    this.width = width
    this.height = height
    this.maxSteps = maxSteps
    this.episodeId = undefined
    this.previousMilestones = 0
    this.done = false
  }

  reset({ seed = 0, snapshot } = {}) {
    if (this.episodeId) garden.deleteEpisode(this.episodeId)
    const episode = snapshot ? garden.fork(snapshot) : garden.createEpisode(seed)
    this.episodeId = episode.id
    this.previousMilestones = garden.verify(episode.id).milestones
    this.done = false
    return { observation: publicObservation(episode.id, this.width, this.height), info: { episodeId: episode.id, worldId: garden.worldId } }
  }

  step(action, { movementResolution } = {}) {
    if (!this.episodeId) throw new Error('Call reset() before step()')
    if (this.done) throw new Error('Episode is done; call reset() before another step()')
    const { outcome } = action.type === 'move' && movementResolution
      ? { outcome: garden.moveResolved(this.episodeId, action.direction, action.distance, movementResolution) }
      : garden.act(this.episodeId, action)
    const verifier = garden.verify(this.episodeId)
    const gainedMilestones = Math.max(0, verifier.milestones - this.previousMilestones)
    this.previousMilestones = verifier.milestones
    const terminated = action.type === 'finish' || verifier.completed
    const truncated = !terminated && verifier.steps >= this.maxSteps
    this.done = terminated || truncated
    return {
      observation: publicObservation(this.episodeId, this.width, this.height),
      reward: gainedMilestones * 0.1 + (verifier.completed ? 1 : 0) - (outcome.failure ? 0.05 : 0),
      terminated,
      truncated,
      info: { outcome, verifier },
    }
  }

  snapshot() {
    if (!this.episodeId) throw new Error('Call reset() before snapshot()')
    return garden.snapshot(this.episodeId)
  }

  trajectory() {
    if (!this.episodeId) throw new Error('Call reset() before trajectory()')
    return garden.trajectory(this.episodeId)
  }

  close() {
    if (this.episodeId) garden.deleteEpisode(this.episodeId)
    this.episodeId = undefined
    this.done = false
  }
}

export class VectorGardenEnv {
  constructor(count, options) {
    if (!Number.isInteger(count) || count < 1) throw new Error('Vector environment count must be a positive integer')
    this.environments = Array.from({ length: count }, () => new GardenEnv(options))
  }

  reset(seeds = []) {
    return this.environments.map((environment, index) => environment.reset({ seed: seeds[index] ?? index }))
  }

  step(actions) {
    if (actions.length !== this.environments.length) throw new Error('Provide exactly one action per environment')
    return this.environments.map((environment, index) => environment.step(actions[index]))
  }

  close() {
    for (const environment of this.environments) environment.close()
  }
}
