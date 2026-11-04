> Public source snapshot: see [setup and included/excluded outputs](../README.md), [asset attribution and licenses](../THIRD_PARTY_ASSETS.md), and [finished videos](../../docs/media/README.md). Historical recording/session filenames below describe locally retained outputs, not files shipped in this checkout.

# Agent Garden Home Lab

An isolated local Godot loading experiment for a furnished apartment. This folder is a standalone prototype using the Garden pattern of image observations, bounded actions, and recorded tool feedback. It has its own local MCP server and is not integrated into the core Garden world or training verifier. The fixed-position worker has no walking; the separate walk-worker variant below adds collision-aware movement. Source is now public in this lab folder.

## Result

Godot 4.7.2 successfully parsed, instantiated and rendered the supplied GLB using the Compatibility renderer on an NVIDIA GeForce RTX 5080. Initial parsing and scene generation took approximately 37 seconds. This is not a navigation FPS or agent-throughput benchmark. The preview uses simple ambient and directional lighting, not finished architectural lighting.

Source file: `assets/modern-apartment.glb` (download separately; see [setup](../README.md) and [attribution](../THIRD_PARTY_ASSETS.md)).

- File size: 209,556,540 bytes
- Triangles: 2,991,575 across 241 meshes and 241 mesh instances
- Materials: 101
- Embedded images: 85
- Bounds: approximately 20.84 x 3.16 x 8.25 model units; physical scale not calibrated

## Run

Run `preview.ps1` with PowerShell. It loads the GLB, renders an interior image to apartment-interior.png, writes godot-report.json, and exits. inspect.gd contains the camera and preview lighting. asset-report.json contains the glTF metadata extracted from the original GLB.

## Before Garden integration

Confirm room scale and navigable layout; build simple collision proxies; define object IDs and interactions; add deterministic household tasks and verification; keep privileged geometry and labels outside the acting agent interface. Profile rendering and memory before choosing optimization targets. Mesh LOD, room occlusion, texture sizing, and simplified collisions are possible optimizations. Preserve the source GLB.

## Asset credit

Modern Apartment by Visthetique: https://sketchfab.com/3d-models/modern-apartment-1fbb649cd6624f2bb7b7d6e30c6533a5
Author: https://sketchfab.com/visthetique
License recorded in the supplied GLB metadata: CC BY 4.0, http://creativecommons.org/licenses/by/4.0/
This preview changes the camera and lighting. Model geometry is unchanged. Keep attribution and identify any future modifications when sharing.

## Recorded property-viewing demo

`agent-garden-home-viewing.mp4` is a 31-second, silent edit of an actual Codex CLI run. Four image observations show the living area, a right turn toward the dining/kitchen area, an evening-lighting change, and a left turn back. Thinking pauses are removed. It is a sequence of recorded observations with captions, not continuous walking footage. The ending note is the agent's actual tool-submitted summary. No model API key was added; Codex used its existing login.

`home-worker.gd` loads the original GLB using Forward+, then adds AgX tonemapping, antialiasing, ambient occlusion, screen-space indirect lighting and cool/warm preview lights. The lighting is illustrative, not a real solar or photometric simulation. Some bright material/light artifacts remain; this is not a finished architectural visualization.

`record-home.mjs` exposes observe, turn, set_lighting and finish tools over loopback MCP. Agent-selected turns and lighting changes determine the recorded views. The model is instructed to use only these tools; it receives no scene tree, geometry, map or coordinates. This prototype has a fixed camera location and no navigation or spatial-task success verifier. The lighting state is maintained by the renderer, unlike the authoritative external state layer in full Garden.

`session/` retains the exact observations, calls.json, raw codex-events.jsonl, agent-summary.txt and viewing-note.txt from the final run. `recording-first-pass/` preserves an earlier lighting trial. `make-clip.py` composes the MP4 from final-run images and the actual agent notes. Captions identify the shortened pauses and fixed camera. Model attribution is included in the video.

Dependencies: installed Godot 4.7.2, Node, Codex CLI with existing login, Python with Pillow, ffmpeg. Run `npm ci` in this folder to install the MCP SDK and zod. See [public setup instructions](../README.md).

To rerun: start Godot with `--path` pointing to this folder, `--script home-worker.gd --rendering-method forward_plus --resolution 1280x720`. Clear only session/request.json, session/response.json and session/ready.json before a fresh worker starts. Wait for HOME_READY, then run `node record-home.mjs` from this folder and `python make-clip.py`. A new run overwrites final session output; copy it first if retaining another trial. Stop the Godot worker after recording.

## Recorded walking demo

`agent-garden-home-walk.mp4` is a 31.87-second edit of a separate autonomous Codex exploration. The agent made 12 image-returning calls, including seven moves and four turns. One movement was blocked; the agent strafed around the obstacle and reached the adjacent corridor. Total recorded translation was 4.541 uncalibrated model units. It did not enter another room. This demonstrates image-driven exploration, not a benchmarked navigation capability or a verified task-completion score.

`walk-worker.gd` preserves the existing lighting, generates static triangle collision shapes for all 241 mesh instances, and uses a CharacterBody3D capsule for small horizontal movement increments. A downward ray checks for supporting geometry before each increment. There is no gravity, stair climbing or navigation mesh; this is a level-floor walking prototype. Model scale has not been calibrated to physical meters. Camera turns and collision-resolved movement are recorded as actual intermediate engine frames at a nominal 15 frames per second. Capture overhead is not represented as real-time performance.

`record-walk.mjs` adds relative forward/backward/left/right movement to the local MCP tools. The agent only receives final RGB observations and public movement/collision feedback. Private intermediate frames are retained for the human-facing video. No map or coordinates are provided to the acting agent. The exploration route is selected by Codex, not a predefined camera tour.

`walk-session/` contains original observation PNGs, intermediate motion JPEGs, calls.json with frame intervals and movement feedback, raw Codex events and the submitted exploration note. `make-walk-clip.py` assembles actual intermediate frames, removes decision pauses, adds brief endpoint holds and captions, and duplicates frames to encode at 30 fps. It does not synthesize movement between viewpoints. The original fixed-position viewing video and session are preserved.

To repeat this variation, use `walk-worker.gd` instead of home-worker.gd, the `walk-session` folder instead of session, `node record-walk.mjs`, then `python make-walk-clip.py`. Preserve existing recordings first. Only one worker should write to a given session folder at a time.
