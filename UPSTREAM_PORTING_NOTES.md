# RV vs Complementary Unbound Porting Notes

Date: 2026-03-19

## Upstream Baseline

The current upstream source of truth for porting decisions is `ComplementaryUnbound_r5.8_dev5`.

Older `dev4` references are still useful for historical comparison, but new decisions should be made against `dev5` first and only fall back to `dev4` when tracing how a subsystem changed.

## Executive Summary

Rethinking Voxels is no longer just Complementary with a few local tweaks.

It is a separate renderer with:

1. a custom voxel volume and vx subsystem,
2. compute-driven lighting and reflection support,
3. a different frame graph and buffer contract,
4. a Voxy integration layer that only partially matches upstream.

Because of that, upstream changes fall into three categories:

1. direct ports:
    small correctness fixes that already match RV's live contract,
2. adapted ports:
    useful upstream logic that must be translated into RV's passes and bindings,
3. rearchitecture work:
    upstream features that assume a different lighting, WSR, or program-graph design.

## First-Principles Architecture Differences

## 1. Frame Graph And Buffer Contract

RV and upstream do not share the same pipeline layout.

1. RV uses a broader MRT and compute-oriented contract in `shaders/lib/pipelineSettings.glsl`.
    - RV uses `colortex9` through `colortex14` for compute-heavy lighting and deferred work.
    - RV keeps dedicated Voxy buffers `colortex18` and `colortex19`.
2. Upstream dev5 uses a simpler classic Complementary layout in `ComplementaryUnbound_r5.8_dev5/shaders/lib/pipelineSettings.glsl`.
    - fewer active intermediate buffers,
    - no RV-style compute lighting buffer chain,
    - classic reflection and temporal targets.
3. RV has extra programs that upstream does not.
    - RV-only programs include:
      - `shaders/program/deferred1_csh.glsl`
      - `shaders/program/prepare.glsl`
      - `shaders/program/prepare1.glsl`
      - `shaders/program/prepare2.glsl`
      - `shaders/program/prepare3.glsl`
      - `shaders/program/prepare4_csh.glsl`
      - `shaders/program/prepare4_csh_a.glsl`
      - `shaders/program/shadowcomp1.glsl`
      - `shaders/program/shadowcomp2.glsl`
      - `shaders/program/shadowcomp_sdf_loop.glsl`
4. Upstream dev5 has programs RV does not.
    - upstream-only program files:
      - `ComplementaryUnbound_r5.8_dev5/shaders/program/composite1.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/program/gbuffers_lightning.glsl`

Practical consequence:
do not port whole render programs from upstream unless RV is intentionally changing its frame graph.

## 2. Voxel Lighting Core

RV and upstream solve voxel lighting differently.

1. RV has its own vx subsystem.
    - core files:
      - `shaders/lib/vx/voxelReading.glsl`
      - `shaders/lib/vx/irradianceCache.glsl`
      - `shaders/lib/vx/SSBOs.glsl`
      - `shaders/lib/vx/positionHashing.glsl`
2. RV's lighting path is wired into compute and custom voxel traversal.
    - `shaders/program/prepare4_csh.glsl` builds per-pixel blocklight using occupancy volumes, voxel colors, SDF tracing, and shared-memory light lists.
    - `shaders/lib/lighting/mainLighting.glsl` reads RV's voxel lighting helpers rather than upstream floodfill samplers.
3. Upstream dev5 uses a different model.
    - `ComplementaryUnbound_r5.8_dev5/shaders/lib/lighting/mainLighting.glsl` includes `/lib/voxelization/lightVoxelization.glsl`.
    - `ComplementaryUnbound_r5.8_dev5/shaders/lib/uniforms.glsl` declares `floodfill_sampler` and `floodfill_sampler_copy`.
    - `ComplementaryUnbound_r5.8_dev5/shaders/shaders.properties` wires image-backed floodfill volumes for colored lighting.

Practical consequence:
upstream floodfill-style colored lighting is not a normal port target. It would replace RV's vx light transport model.

## 3. World-Space Reflections

RV and upstream dev5 are only partially aligned.

1. RV still uses SSBO occupancy helpers in the live WSR path.
    - files:
      - `shaders/lib/voxelization/SSBOs/wsrBuffer.glsl`
      - `shaders/lib/voxelization/SSBOs/wsrLodBuffer.glsl`
      - `shaders/lib/voxelization/reflectionVoxelData.glsl`
      - `shaders/lib/voxelization/reflectionVoxelization.glsl`
2. Upstream dev5 moved further toward sampler and image-backed WSR.
    - `ComplementaryUnbound_r5.8_dev5/shaders/lib/uniforms.glsl` declares:
      - `wsr_sampler`
      - `wsr_lod_sampler`
    - `ComplementaryUnbound_r5.8_dev5/shaders/shaders.properties` binds:
      - `image.wsr_img`
      - `image.wsr_lod_img`
3. RV's reflection front-end is also compute-aware.
    - `shaders/program/deferred1_csh.glsl` runs reflection logic in compute.
    - RV's `reflections.glsl` already contains compatibility work to support Voxy and the deferred compute path.

Practical consequence:
upstream WSR logic can be mined for algorithms and bug fixes, but the dev5 texture-backed occupancy architecture is not a drop-in replacement for RV.

## 4. Material System

RV and upstream dev5 have diverged in structure, not just content.

1. RV still uses older local material entry points.
    - active call sites include:
      - `shaders/program/deferred1.glsl` -> `deferredMaterials.glsl`
      - `shaders/program/deferred1_csh.glsl` -> `deferredMaterials.glsl`
      - `shaders/program/gbuffers_entities.glsl` -> `entityMaterials.glsl`
      - `shaders/program/gbuffers_entities.glsl` -> `irisMaterials.glsl`
      - `shaders/program/gbuffers_hand.glsl` -> `irisMaterials.glsl`
      - `shaders/program/gbuffers_water.glsl` -> `translucentMaterials.glsl`
      - `shaders/program/voxy_opaque.glsl` -> `terrainMaterials_voxy.glsl`
      - `shaders/program/voxy_translucent.glsl` -> `translucentMaterials.glsl`
2. RV also has Voxy-specific material forks.
    - files:
      - `shaders/lib/materials/materialHandling/terrainMaterials_voxy.glsl`
      - `shaders/lib/materials/materialHandling/translucentMaterials_voxy.glsl`
3. Upstream dev5 kept evolving around split IPBR modules.
    - upstream-only material handlers:
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialHandling/deferredIPBR.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialHandling/entityIPBR.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialHandling/irisIPBR.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialHandling/translucentIPBR.glsl`

Practical consequence:
this is a good port target, but as adapted modules, not file replacement.

## 5. Settings And Feature Wiring

RV exposes voxel rendering as a first-class feature family.

1. `shaders/shaders.properties` contains a dedicated `VX_SETTINGS` section and VX-specific profiles.
2. `shaders/lib/common.glsl` exposes VX volume size, GI strength, trace limits, blocklight resolution, and related toggles directly.

Upstream dev5 instead treats voxel-related systems as optional Complementary features.

1. `ComplementaryUnbound_r5.8_dev5/shaders/shaders.properties` centers configuration around:
    - `COLORED_LIGHTING`
    - `WORLD_SPACE_REFLECTIONS`
    - reflection resolution and image bindings
2. dev5 has no RV-style VX settings screen.

Practical consequence:
do not replace RV's settings structure wholesale. Port individual options only when the backend exists in RV.

## Port Classification

## Direct Ports

These are safe or near-safe when they match RV's current live contract.

1. Voxy contract fixes.
    - already applied: `shaders/program/voxy_opaque.glsl` now writes to `gbufferData6` to match `shaders/program/voxy.json`.
2. Small shader correctness fixes inside shared helper code.
    - examples include local bug fixes in reflection math, fog usage, helper guards, and compile-context assumptions.
3. File-local visual fixes that do not assume upstream's buffer graph.

## Adapted Ports

These should be ported, but only by translating the logic into RV's architecture.

1. Reflection helper improvements.
    - source files:
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialMethods/reflections.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialMethods/reflectionBackground.glsl`
      - `ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialMethods/reflectionBlurFilter.glsl`
    - target RV files:
      - `shaders/lib/materials/materialMethods/reflections.glsl`
      - `shaders/lib/materials/materialMethods/reflectionBackground.glsl`
      - `shaders/program/deferred1.glsl`
      - `shaders/program/deferred1_csh.glsl`
2. Material handling modernization.
    - source files:
      - `deferredIPBR.glsl`
      - `entityIPBR.glsl`
      - `irisIPBR.glsl`
      - `translucentIPBR.glsl`
    - target RV entry points remain the local handlers and program call sites.
3. Selective settings parity.
    - bring over user-visible controls only when RV already has the backend or when the backend can be added without changing the frame graph.

## Rearchitecture Work

These are attractive features, but they require changing RV's core design.

1. Upstream floodfill-style colored lighting.
    - requires replacing or bypassing RV's vx cone-tracing and irradiance-cache model.
2. Full upstream texture-backed WSR occupancy.
    - requires replacing RV's SSBO occupancy helpers and rewiring uniforms, shadow writes, and tracing.
3. Full frame-graph convergence with upstream.
    - requires replacing RV compute passes with an upstream-like composite pipeline.

## What Should Not Be Ported Wholesale

1. `ComplementaryUnbound_r5.8_dev5/shaders/lib/pipelineSettings.glsl`
2. `ComplementaryUnbound_r5.8_dev5/shaders/shaders.properties`
3. `ComplementaryUnbound_r5.8_dev5/shaders/lib/uniforms.glsl`
4. `ComplementaryUnbound_r5.8_dev5/shaders/lib/lighting/mainLighting.glsl`
5. `ComplementaryUnbound_r5.8_dev5/shaders/program/composite1.glsl`

These files encode upstream assumptions about passes, attachments, and lighting storage that do not match RV.

## dev5 Voxy Delta

Compared against `ComplementaryUnbound_r5.8_dev4`, the meaningful Voxy-related changes in dev5 are small.

1. Safe port:
    - `shaders/program/voxy_opaque.glsl`
    - second output renamed from `gbufferData1` to `gbufferData6`
    - this was safe because RV's `voxy.json` already declared draw buffers `[0, 6]`

2. Not safe as standalone ports:
    - `ComplementaryUnbound_r5.8_dev5/shaders/lib/voxelization/reflectionVoxelData.glsl`
    - `ComplementaryUnbound_r5.8_dev5/shaders/lib/voxelization/reflectionVoxelization.glsl`
    - dev5 assumes the newer WSR sampler and image architecture, while RV still relies on SSBO occupancy helpers in the live path

3. No further Voxy action needed from the remaining dev5 files.
    - `lightVoxelization.glsl`, `puddleVoxelization.glsl`, and `voxy.json` do not create a new direct port requirement beyond the output remap already applied.

## Next Pass: Material Layer Audit

This pass treats `dev5` as source of truth for material-system direction and asks which upstream modules are worth adapting first.

## Current RV Material Entry Points

1. Deferred reflections and material-mask interpretation:
    - `shaders/lib/materials/materialHandling/deferredMaterials.glsl`
    - called from:
      - `shaders/program/deferred1.glsl`
      - `shaders/program/deferred1_csh.glsl`

2. Entity materials:
    - `shaders/lib/materials/materialHandling/entityMaterials.glsl`
    - called from `shaders/program/gbuffers_entities.glsl`

3. Iris and held-item material handling:
    - `shaders/lib/materials/materialHandling/irisMaterials.glsl`
    - called from:
      - `shaders/program/gbuffers_entities.glsl`
      - `shaders/program/gbuffers_hand.glsl`

4. Translucent materials:
    - `shaders/lib/materials/materialHandling/translucentMaterials.glsl`
    - called from:
      - `shaders/program/gbuffers_water.glsl`
      - `shaders/program/voxy_translucent.glsl`

5. Terrain materials:
    - `shaders/lib/materials/materialHandling/terrainMaterials.glsl`
    - plus RV-specific Voxy fork:
      - `shaders/lib/materials/materialHandling/terrainMaterials_voxy.glsl`

## Upstream dev5 Material Modules Worth Adapting

## 1. `deferredIPBR.glsl`

This is the best first material port target.

Why:

1. RV's current `deferredMaterials.glsl` is small and localized.
2. It is called from both raster and compute deferred paths, so improvements here have good leverage.
3. The integration surface is narrow:
    - `materialMaskInt`
    - `smoothnessD`
    - `intenseFresnel`
    - `reflectColor`

Recommendation:
adapt upstream `deferredIPBR.glsl` logic into RV's local `deferredMaterials.glsl` instead of replacing the include path.

## 2. `entityIPBR.glsl`

This is the second-best material port target.

Why:

1. RV already isolates entity handling in `entityMaterials.glsl`.
2. Upstream dev5 expands entity-specific material behavior without forcing frame-graph changes.
3. The local and upstream files solve the same class of problem.

Recommendation:
merge upstream entity-specific material behavior into `shaders/lib/materials/materialHandling/entityMaterials.glsl` gradually, preserving RV-only entity quirks.

## 3. `irisIPBR.glsl`

This is a moderate-risk but worthwhile adapted port.

Why:

1. RV already has a dedicated `irisMaterials.glsl` entry point.
2. Upstream dev5 contains a broader item and held-material rule set.
3. This is mostly logic-level drift, not pipeline drift.

Risk:

1. held-item behavior is very visible,
2. subtle differences in item IDs and armor handling can regress visuals quickly.

Recommendation:
adapt upstream item-material cases incrementally and validate them visually by category.

## 4. `translucentIPBR.glsl`

This is useful but more coupled than the previous three.

Why:

1. RV's `translucentMaterials.glsl` already has Voxy guards and compile-context branching.
2. It is shared by both classic water/translucent rendering and `voxy_translucent`.
3. Upstream translucent behavior is closely tied to connected glass, portal effects, and reflection handling.

Recommendation:
adapt selective upstream translucent material logic, but do not replace RV's entry point. Treat water, glass, portals, and beacon behavior as separate subports.

## 5. Terrain Unification

This is valuable long-term, but it is not the next pass.

Why:

1. `terrainMaterials.glsl` is huge.
2. RV also has `terrainMaterials_voxy.glsl`.
3. Upstream dev5 assumes a more unified path than RV currently has.

Recommendation:
leave terrain/Voxy material unification for later, after deferred/entity/iris/translucent drift is reduced.

## Upstream Reflection Helper To Queue After Material Pass

`ComplementaryUnbound_r5.8_dev5/shaders/lib/materials/materialMethods/reflectionBlurFilter.glsl`

This remains one of the highest-value non-architectural upstream features because:

1. RV already has a custom reflection chain,
2. RV already has deferred compute reflection staging,
3. the feature can be adapted to RV's buffers without replacing RV's light transport model.

## Recommended Port Order After This Audit

1. Adapt `deferredIPBR.glsl` concepts into `shaders/lib/materials/materialHandling/deferredMaterials.glsl`.
2. Adapt `entityIPBR.glsl` into `shaders/lib/materials/materialHandling/entityMaterials.glsl`.
3. Adapt `irisIPBR.glsl` into `shaders/lib/materials/materialHandling/irisMaterials.glsl`.
4. Port reflection blur concepts from `reflectionBlurFilter.glsl` into RV's deferred reflection path.
5. Revisit `translucentIPBR.glsl` after reflection blur is stable.
6. Only then consider terrain/Voxy material unification.

## Current Working Rule

Treat RV's voxel volume, compute passes, and buffer contract as source of truth.

Treat upstream dev5 as source of truth for:

1. material logic direction,
2. reflection helper quality,
3. correctness fixes in shared shading code,
4. feature ideas that can be translated into RV's architecture.
