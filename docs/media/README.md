# Agent Garden lab videos

This directory contains the two finished square social edits and the learned-navigation test video linked from the main README. Source code and selected navigation results are now in [labs/](../../labs/README.md). GLBs, extracted textures, reference photographs, account credentials and raw image sessions are not included.

## Home lab

[home-lab-square.mp4](home-lab-square.mp4), 1080 x 1080, H.264/AAC, 23 seconds.

The video combines two actual Codex CLI episodes in a Godot apartment: a fixed-position visual layout/lighting inspection using an example buyer brief, and a separate collision-aware walk toward the corridor. Captions summarize actual findings; they are not a transcript of a live buyer chat. Thinking pauses are removed, and a brief dissolve compares simulated lighting presets. No improvement in learned spatial reasoning is claimed.

Apartment asset: **Modern Apartment**, by **Visthétique** ([creator](https://sketchfab.com/visthetique), [source model](https://sketchfab.com/3d-models/modern-apartment-1fbb649cd6624f2bb7b7d6e30c6533a5)), licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Lighting, camera placement, captions, edit, and an original locally synthesized soundtrack were added for this experiment. Source model geometry is unchanged and is not distributed here. The finished home video is shared under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with the above attribution retained.

## Showroom lab

[showroom-lab-square.mp4](showroom-lab-square.mp4), 1080 x 1080, H.264/AAC, 16.2 seconds.

This edit combines an actual six-view Codex visual inspection of the exterior, cockpit, cabin, and seats with excerpts from a separate agent-controlled drive. Inspection images are held for editorial timing; driving frames retain source speed, with decision pauses and some approach actions omitted. The agent receives rendered images and tool feedback rather than maps or hidden scene state. This is a virtual 3D model inspection, not an assessment of a real vehicle's condition or specifications.

The drive uses simplified kinematic steering, barrier collision, and ground-aligned wheels on an added synthetic test road. The mountains are a static photographic panorama, not driveable terrain. The underlying faster run stopped short of its target; the video makes no task-completion or real-world autonomous-driving claim. The footage is edited with warm lighting, camera/depth-of-field effects, edge softness, restrained temporal motion blur, captions, and original synthesized music.

Car asset: **Ferrari Laferrari | www.vecarz.com**, by **vecarz** ([creator](https://sketchfab.com/heynic), [source model](https://sketchfab.com/3d-models/ferrari-laferrari-wwwvecarzcom-979f7085012e4d6399f38de3f9c39012)), licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

Scenery: **Gotthard-Pass enviroment panorama**, by **Bau-3d** ([creator](https://sketchfab.com/Bau-3d), [source model](https://sketchfab.com/3d-models/gotthard-pass-enviroment-panorama-49935c5fb305478db94e277344477d3e)), licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

The source car geometry and panorama image are unchanged. Placement, wheel-pivot animation, lighting, camera work, cabin fill light, road, captions, soundtrack, and edit are added contributions. Neither original GLB is distributed here.

The finished showroom video and these added audiovisual contributions are shared under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Retain attribution, identify changes, use non-commercially, and share adaptations under the same license. The luxury-car-sales caption is a concept illustration; this video is not offered as a commercially licensed dealership advertisement.

## Scope of media permissions

These video notices apply to the videos and their credited content. They do not change the licensing of the repository's software. No endorsement by the asset creators, Ferrari, or any dealership is implied. Original GLBs are excluded; lab source is now public.

## Learned navigation test

[navigation-learning.mp4](navigation-learning.mp4), 1280 x 800, H.264, silent, 60 fps, 13.12 seconds.

The actual local feed-forward policy controls the shared Godot capsule/step controller on task `test-0005`. It reaches the lower-floor destination in 10.72 simulated seconds. The recording includes startup/arrival holds. The rendered trajectory exactly matches this episode's headless evaluation. The camera automatically chooses unobstructed views; it does not control the character or change the policy's sensor frame.

This is an illustrative successful route, selected as the first successful different-floor test episode within 25 seconds. It is not a random sample of the policy's success rate. The policy reached 34/50 reserved destinations, including 15/28 different-floor routes, with zero respawns. All 50 outcomes and trajectories, including 16 failures, are [published with the experiment](../../labs/navigation/experiments/navigation-v1-20261104/REPORT.md). This is one known lobby, not an unseen-building result. Inputs are ray distances and relative goal/velocity; no RGB perception, LLM inference, map-based fallback or joint-level learning is involved.

Environment: **Lobby**, by **local.yany** ([creator](https://sketchfab.com/local.yany), [source model](https://sketchfab.com/3d-models/lobby-9057cb241be74393b91952143c3ffe87)), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Character: **Free 018 Kana Walk**, by **ddd** ([creator](https://sketchfab.com/endonoriko), [source model](https://sketchfab.com/3d-models/free-018-kana-walk-f465652729944a66aed790cd88fa0b0f)), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Original GLBs are unchanged. Runtime scale, horizontal root-travel locking, animation playback, collision/step controller, lighting, cameras, HUD and learned navigation were added. The finished navigation video and added audiovisual contributions are shared under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with both asset credits retained. [Full third-party asset notices](../../labs/THIRD_PARTY_ASSETS.md).
