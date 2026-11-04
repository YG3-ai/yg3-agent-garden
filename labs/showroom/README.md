> Public source snapshot: see [setup and included/excluded outputs](../README.md), [asset attribution and licenses](../THIRD_PARTY_ASSETS.md), and [finished videos](../../docs/media/README.md). Historical recording/session filenames below describe locally retained outputs, not files shipped in this checkout.

# Agent Garden Drive Lab

Local asset compatibility and image-driven driving experiment. The code is now public as a standalone lab; download the credited models separately. See [setup](../README.md) and [asset attribution](../THIRD_PARTY_ASSETS.md).

## What fits, and what does not

Both GLBs import in Godot 4.7.2. The LaFerrari contains 587,310 mesh triangles, 85 meshes and four separate wheel groups. Its instantiated bounds are about 2.01 x 1.07 x 4.49 model units, suitable for a car-sized test scene.

The Gotthard asset contains 2,096,448 triangles but is a panorama mapped onto a sphere, not traversable terrain. Its one image is only 1024 x 512. The visible photographic roads have no physical surface or collision geometry. Scaling the sphere does not turn those roads into driveable geometry. Panorama sharpness and lack of translational parallax limit close integration with a detailed car.

For the combined experiment, the original equirectangular image is extracted unchanged into assets/gotthard-panorama.png and used as a sky/background and reflection source. A simple synthetic straight road, lane markings, guardrails, ground apron and green stopping cones are added in Godot. The source environment GLB remains saved intact. This is not a reconstruction or drive through the actual Gotthard roads.

## Agent demonstration

The local MCP tools are inspect_car, enter_car, observe, drive and finish. The agent receives camera RGB images and public action feedback, with no global map, coordinates or scene graph. It chooses inspection angles, forward distances and steering. Driving uses a simplified kinematic bicycle-style heading update, body collision against barriers, cosmetic wheel rolling and a chase camera. Each drive command ends stopped. There is no realistic suspension, tire friction, dynamics, gravity, cockpit embodiment or autonomous driving capability claim.

The deterministic finish verifier checks whether the stationary car is near the marked white line, within its lane and without recorded barrier contacts. The intended task is a small local control demonstration, not an automotive safety evaluation. Model units are not calibrated measurements of the real vehicle or pass.

session/ stores actual returned observations, intermediate engine frames, raw agent events, tool calls and the finish verdict. The video removes thinking pauses and retains the actual inspection and driving movements. See clip-report.json for the run outcome and duration.

## Run locally (Windows)

Dependencies: Godot 4.7.2 with graphics access, Node.js, Codex CLI with its existing login, Python with Pillow and ffmpeg. Run npm ci in this folder. No model API key is added.

Start Godot with --path pointing to this folder, --script drive-worker.gd --rendering-method forward_plus --resolution 1280x720. Wait for DRIVE_READY. Then run node record-drive.mjs in another terminal, followed by python make-drive-clip.py. The recorder uses process-local approvals for only the five local tools. Stop the Godot renderer afterward. Inspection scripts can be rerun with --script inspect.gd and the Compatibility renderer.

Preserve session/ before another run. Clear its request.json, response.json and ready.json before starting a fresh worker. Video scripts currently use Windows Segoe UI font paths. Assets and runtime session paths are project-relative.

## Asset credits

Gotthard-Pass enviroment panorama by Bau-3d: https://sketchfab.com/3d-models/gotthard-pass-enviroment-panorama-49935c5fb305478db94e277344477d3e
Author: https://sketchfab.com/Bau-3d
Embedded license: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
The original texture is extracted without editing; sky/background usage, camera and scene setup are new.

Ferrari Laferrari | www.vecarz.com by vecarz: https://sketchfab.com/3d-models/ferrari-laferrari-wwwvecarzcom-979f7085012e4d6399f38de3f9c39012
Author: https://sketchfab.com/heynic
Embedded license: CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/
Model geometry is unchanged. Placement, wheel pivot animation, lighting, road and camera are added. The car file is marked non-commercial; this experiment is kept local. Do not assume the real estate marketing asset permissions apply to this car.

Original GLBs, embedded metadata reports and scene bounds are preserved. No ownership of the car, brand or panorama is claimed.


## Late-afternoon cinematic variations

The original session and original video are preserved. `cinematic-worker.gd` adds 13-degree warm sunlight, longer shadows, a 22-degree camera field of view, far depth-of-field softness, gentle haze and a screen-space vignette. `replay-cinematic.mjs` replays the original 11 actions through the unchanged movement rules; every movement result, collision flag and completion verdict matches the source. `agent-garden-mountain-drive-cinematic.mp4` is a cinematic presentation of that original run, not a fresh agent run. `cinematic-grade.gdshader` and `make-cinematic-clip.py` retain the rendering and edit settings.

The more dramatic variation is a fresh Codex episode saved separately in `dramatic-session/`, rendered by `dramatic-worker.gd`. It uses a 15-degree camera field of view with the camera moved farther back to compress perspective, stronger edge softness and vignette, focus tracking around the car, and a mild weighted temporal motion-blur pass in `make-dramatic-clip.py`. Original geometry and original asset textures are unchanged.

The new drive tool accepts speed in model units per simulated second. Codex selected speed 9 for three 10-unit open-road moves, then speeds 4, 3 and 2 for its final approach. The old run advanced about 2.5 units per second during its longer moves. Speed is modeled in 15 Hz movement steps; output is duplicated to 30 fps with restrained temporal blending. This is faster simulated motion, not a playback-speed adjustment. The marker is farther down the strip in this variation to provide a longer run.

Grounding uses a downward ray onto the road plus each wheel group's invariant rolling radius. The body is lowered to put the tires at the surface; it does not use an inflated bounding box of the rotating wheel. The recorded final wheel-bottom gaps are 0.0 to 0.0036 model units. These are virtual model-scale checks, not a real vehicle/suspension calibration. `dramatic-session/grounding.json` retains the measurements.

The dramatic run traveled 44 model units without a barrier contact and stopped short of the relocated target. The finish verifier returned incomplete. The cinematic edit does not claim that this new run passed the marked-stop task. All observations, intermediate motion frames, agent events and the actual verdict are saved.

The long-lens/depth-of-field rendering is an artistic treatment of the panorama and synthetic road. It does not turn the photograph into geometrically correct 3D terrain or re-create the physical sun position in the original photo. Rendering references: https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html


## Exterior and interior showroom inspection

`showroom-worker.gd` adds fixed visual inspection views for a closer front-quarter detail, driver cockpit, passenger-side cabin and rear-facing seats, alongside front/rear/side exterior views. These use the existing model geometry, including its steering wheel, dashboard, vents, center console and two seats. A small nonphysical studio fill light is enabled only for interior inspection; edge softness is reduced for readable controls. No doors are animated or removed, and no new cabin geometry or generated imagery is added.

`record-showroom.mjs` records a fresh Codex visual inspection using only inspect_car and finish. The agent viewed front, rear, wheel-detail, cockpit, cabin and seats, and reported directly visible details from the returned images. `showroom-session/` preserves actual observations, intermediate frames, raw events and its inspection summary. This inspection does not involve driving or a navigation completion score. The initial renderer feedback used the generic exterior label even for interior views; recorded arguments/images identify the actual views, and future-run feedback has been corrected without altering the captured logs.

`make-showroom-cut.py` produces the 16.2-second portrait and square videos in showroom-cut/. It combines the new inspection images with a short excerpt of the earlier dramatic-session drive, maintaining minimal AGENT GARDEN branding and the virtual-showroom concept. This is an edited combination of two agent runs, not a single continuous inspection-and-drive episode. Previous social-cut/ versions remain untouched.
