# Third-party assets and attribution

Models and textures are separately downloaded dependencies. This repository does not redistribute their GLBs, embedded images or derived geometry caches. These notices identify their creators and licenses; they do not relicense the repository's software. Retain attribution, a license link and modification notices in any redistributed assets or demo media. No creator, manufacturer or dealership endorsement is implied.

| Asset and creator | Source and license | Expected local path |
|---|---|---|
| **Modern Apartment**, by **Visthétique** ([creator](https://sketchfab.com/visthetique)) | [Source model](https://sketchfab.com/3d-models/modern-apartment-1fbb649cd6624f2bb7b7d6e30c6533a5), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | `home/assets/modern-apartment.glb` |
| **Ferrari Laferrari / www.vecarz.com**, by **vecarz** ([creator](https://sketchfab.com/heynic)) | [Source model](https://sketchfab.com/3d-models/ferrari-laferrari-wwwvecarzcom-979f7085012e4d6399f38de3f9c39012), [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) | `showroom/assets/laferrari.glb` |
| **Gotthard-Pass enviroment panorama**, by **Bau-3d** ([creator](https://sketchfab.com/Bau-3d)) | [Source model](https://sketchfab.com/3d-models/gotthard-pass-enviroment-panorama-49935c5fb305478db94e277344477d3e), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | `showroom/assets/gotthard-pass.glb` and locally extracted `gotthard-panorama.png` |
| **Lobby**, by **local.yany** ([creator](https://sketchfab.com/local.yany)) | [Source model](https://sketchfab.com/3d-models/lobby-9057cb241be74393b91952143c3ffe87), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | `navigation/assets/lobby.glb` |
| **Free 018 Kana Walk**, by **ddd** ([creator](https://sketchfab.com/endonoriko)) | [Source model](https://sketchfab.com/3d-models/free-018-kana-walk-f465652729944a66aed790cd88fa0b0f), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | `navigation/assets/kana-walk.glb` |

Home modifications: camera placement, preview lighting, collision-based movement, MCP tools and video editing. Original model geometry is unchanged; scale is not calibrated for a property survey.

Showroom modifications: placement, wheel-pivot animation, road geometry, ground alignment, lighting, cabin fill, cameras, grading, depth-of-field/temporal effects, captions, soundtrack and editing. The mountain asset is a photographic panorama, not traversable terrain. The source car geometry and panorama image are unchanged. The car model and finished showroom video carry **non-commercial and share-alike restrictions**. The luxury-sales framing is a concept illustration, not a commercially licensed advertisement. The car license does not grant permission to relicense its media under a permissive software license.

Navigation modifications: model scale, locked horizontal root travel, animation playback, posed collision baking, capsule/step controller, lighting, cameras, local sensor generation, training/control code and edited HUD. Original GLBs are unchanged. The navigation video is shared under **CC BY 4.0**, retaining both lobby and character credits. The selected movement policy is trained on synthetic ray-distance observations, not the character's joint animations.

See [video-specific provenance and licenses](../docs/media/README.md) for the published clips. Source-license information comes from the supplied models' embedded metadata and the original lab records.
