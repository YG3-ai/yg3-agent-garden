import { access, mkdtemp, readFile, rm } from 'node:fs/promises'
import { spawn } from 'node:child_process'
import { createConnection } from 'node:net'
import { homedir, tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const DEFAULT_CANDIDATES = [
  '/Applications/Godot.app/Contents/MacOS/Godot',
  join(homedir(), 'Applications/Godot.app/Contents/MacOS/Godot'),
  join(homedir(), 'Downloads/Godot.app/Contents/MacOS/Godot'),
  join(homedir(), 'Downloads/Godot 2.app/Contents/MacOS/Godot'),
]

async function firstExecutable(candidates) {
  for (const candidate of candidates) {
    try {
      await access(candidate)
      return candidate
    } catch {
      // Continue through the explicit candidate list.
    }
  }
  throw new Error('Godot executable not found. Set GODOT_BIN to the Godot 4 executable path.')
}

function run(binary, args) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(binary, args, { stdio: ['ignore', 'pipe', 'pipe'] })
    let stdout = ''
    let stderr = ''
    child.stdout.setEncoding('utf8').on('data', chunk => { stdout += chunk })
    child.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk })
    child.once('error', reject)
    child.once('exit', code => {
      if (code === 0) resolvePromise({ stdout, stderr })
      else reject(new Error(`Godot exited with code ${code}: ${stderr || stdout}`))
    })
  })
}

export async function findGodot() {
  return firstExecutable([process.env.GODOT_BIN, ...DEFAULT_CANDIDATES].filter(Boolean))
}

export async function renderGodotSnapshot(snapshot, { width = 256, height = width } = {}) {
  if (snapshot?.schemaVersion !== 1 || snapshot?.worldId !== 'yg3-operations-recovery-v1') {
    throw new Error('Godot renderer received an incompatible world snapshot')
  }
  const binary = await findGodot()
  const project = resolve('engine/godot')
  const scratch = await mkdtemp(join(tmpdir(), 'yg3-garden-godot-'))
  const output = join(scratch, 'rgb.png')
  const state = snapshot.state
  try {
    const result = await run(binary, [
      '--path', project,
      '--audio-driver', 'Dummy',
      '--resolution', `${width}x${height}`,
      '--',
      `--output=${output}`,
      `--camera-x=${state.x}`,
      `--camera-z=${state.z}`,
      `--camera-yaw=${state.yaw}`,
      `--width=${width}`,
      `--height=${height}`,
      `--audience-signal=${state.workflow.audienceSignal}`,
      `--publishing-rail=${state.workflow.publishingRail}`,
      `--package-status=${state.workflow.package}`,
      `--published=${state.workflow.published}`,
      `--recoveries=${state.workflow.recoveries}`,
    ])
    return { png: await readFile(output), diagnostics: result }
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

export class GodotWorker {
  constructor({ binary, project, child, socket, diagnostics }) {
    this.binary = binary
    this.project = project
    this.child = child
    this.socket = socket
    this.diagnostics = diagnostics
    this.nextId = 1
    this.pending = new Map()
    this.buffer = ''
    socket.setEncoding('utf8')
    socket.on('data', chunk => this.#receive(chunk))
    socket.on('error', error => this.#failAll(error))
    child.once('exit', code => this.#failAll(new Error(`Godot worker exited with code ${code}: ${diagnostics.stderr}`)))
  }

  static async start({ width = 256, height = width } = {}) {
    const binary = await findGodot()
    const project = resolve('engine/godot')
    const child = spawn(binary, [
      '--path', project,
      '--audio-driver', 'Dummy',
      '--resolution', `${width}x${height}`,
      '--',
      '--worker-port=0',
      `--width=${width}`,
      `--height=${height}`,
    ], { stdio: ['ignore', 'pipe', 'pipe'] })
    const diagnostics = { stdout: '', stderr: '' }
    child.stderr.setEncoding('utf8').on('data', chunk => { diagnostics.stderr += chunk })
    const port = await new Promise((resolvePromise, reject) => {
      let buffer = ''
      const timeout = setTimeout(() => reject(new Error(`Timed out waiting for Godot worker: ${diagnostics.stderr || diagnostics.stdout}`)), 20000)
      const fail = error => {
        clearTimeout(timeout)
        reject(error)
      }
      child.once('error', fail)
      child.once('exit', code => fail(new Error(`Godot worker exited before ready with code ${code}: ${diagnostics.stderr || diagnostics.stdout}`)))
      child.stdout.setEncoding('utf8').on('data', chunk => {
        diagnostics.stdout += chunk
        buffer += chunk
        let newline = buffer.indexOf('\n')
        while (newline >= 0) {
          const line = buffer.slice(0, newline).trim()
          buffer = buffer.slice(newline + 1)
          if (line.startsWith('GARDEN_WORKER ')) {
            clearTimeout(timeout)
            resolvePromise(JSON.parse(line.slice('GARDEN_WORKER '.length)).port)
            return
          }
          newline = buffer.indexOf('\n')
        }
      })
    })
    const socket = await new Promise((resolvePromise, reject) => {
      const connection = createConnection({ host: '127.0.0.1', port })
      connection.once('connect', () => resolvePromise(connection))
      connection.once('error', reject)
    })
    const worker = new GodotWorker({ binary, project, child, socket, diagnostics })
    await worker.request('ping')
    return worker
  }

  #receive(chunk) {
    this.buffer += chunk
    let newline = this.buffer.indexOf('\n')
    while (newline >= 0) {
      const line = this.buffer.slice(0, newline)
      this.buffer = this.buffer.slice(newline + 1)
      if (line) {
        const response = JSON.parse(line)
        const pending = this.pending.get(response.id)
        if (pending) {
          this.pending.delete(response.id)
          clearTimeout(pending.timeout)
          if (response.ok) pending.resolve(response)
          else pending.reject(new Error(`Godot worker request failed: ${response.error}`))
        }
      }
      newline = this.buffer.indexOf('\n')
    }
  }

  #failAll(error) {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timeout)
      pending.reject(error)
    }
    this.pending.clear()
  }

  request(type, payload = {}) {
    const id = this.nextId++
    return new Promise((resolvePromise, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id)
        reject(new Error(`Godot worker request ${id} timed out`))
      }, 30000)
      this.pending.set(id, { resolve: resolvePromise, reject, timeout })
      this.socket.write(`${JSON.stringify({ id, type, ...payload })}\n`)
    })
  }

  async render(snapshot, { width = 256, height = width, includeLabels = false } = {}) {
    if (snapshot?.schemaVersion !== 1 || snapshot?.worldId !== 'yg3-operations-recovery-v1') {
      throw new Error('Godot worker received an incompatible world snapshot')
    }
    const response = await this.request('render', { state: snapshot.state, width, height, includeLabels })
    const result = {
      png: Buffer.from(response.pngBase64, 'base64'),
      width: response.width,
      height: response.height,
    }
    if (includeLabels) {
      result.segmentationPng = Buffer.from(response.segmentationBase64, 'base64')
      result.segmentationLegend = response.segmentationLegend
      result.calibration = response.calibration
    }
    return result
  }

  renderTrainingFrame(snapshot, options) {
    return this.render(snapshot, { ...options, includeLabels: true })
  }

  async close() {
    if (this.child.exitCode !== null) return
    try {
      await this.request('close')
    } finally {
      this.socket.end()
    }
  }
}
