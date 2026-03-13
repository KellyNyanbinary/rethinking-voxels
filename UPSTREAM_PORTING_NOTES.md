# RV vs Complementary Unbound Porting Notes

Date: 2026-03-13

## Summary

Rethinking Voxels (RV) currently behaves like a hybrid fork: it contains RV/Voxy-specific compute and voxel systems layered on top of Complementary-like shading code, but with a different render-target contract than upstream Complementary Unbound.

Because of this, upstream updates should be ported by subsystem and adapted to RV's buffer layout, not copied file-for-file.

## High-Impact Differences (Current)

1. Render-target contract and buffer roles differ significantly.
     - Files:
         - `shaders/lib/pipelineSettings.glsl`
         - `ComplementaryUnbound_r5.8_dev4/shaders/lib/pipelineSettings.glsl`
     - RV uses a broader MRT/compute-oriented layout (`colortex9-14`, prepare/deferred compute paths), while Unbound uses a different `colortex4/5/6/7/8` role mapping.

2. Deferred reflection/color encoding diverged.
     - Files:
         - `shaders/program/deferred1.glsl`
         - `ComplementaryUnbound_r5.8_dev4/shaders/program/deferred1.glsl`
     - Reflection buffer encode/decode behavior differs unless explicitly aligned.

3. Material-handling architecture diverged.
     - Upstream-only material handling modules include:
         - `deferredIPBR.glsl`
         - `entityIPBR.glsl`
         - `irisIPBR.glsl`
         - `translucentIPBR.glsl`
     - RV still routes through older/local material handling files plus RV-specific overrides.

4. Reflection helper feature gap remains.
     - Upstream-only file:
         - `ComplementaryUnbound_r5.8_dev4/shaders/lib/materials/materialMethods/reflectionBlurFilter.glsl`

5. `shaders.properties` profiles and reflection-related settings differ heavily.
     - Files:
         - `shaders/shaders.properties`
         - `ComplementaryUnbound_r5.8_dev4/shaders/shaders.properties`
     - Differences in defaults/macros can significantly alter visuals even when shader code is close.

## Recent Reflection Fix Alignment Already Applied

The following were aligned to reduce near-water reflection color issues:

1. Upstream-like deferred reflection color encoding updates in `deferred1`:
    - `waterRefColor` now follows upstream-style encode (`sqrt(...) * 0.5` path).
    - alpha for the reflection output was aligned to carry cloud depth semantics.

2. Nearby-water reflection sampling in `reflections.glsl`:
    - switched from alias-based reads to explicit reflection buffer reads (`colortex5`) to avoid alias ambiguity (`gaux2` mapping differences).

## Recommended Porting Strategy (RV Features on Top of Complementary)

1. Treat RV buffer layout as source-of-truth.
    - Keep RV's compute/voxel pipeline contract.
    - Adapt upstream logic into RV's contract instead of replacing `pipelineSettings` wholesale.

2. Port by subsystem, in this order:
    - Reflection encode/decode chain (`deferred1`, `reflections`, `reflectionBackground`).
    - Material handling modernization (IPBR split modules).
    - Reflection quality helpers (e.g., `reflectionBlurFilter`).
    - Settings/profile parity for reflection-relevant options in `shaders.properties`.

3. Avoid legacy alias assumptions in critical paths.
    - Prefer explicit `colortex*` buffers over `gaux*` aliases where color correctness matters.

4. Mirror upstream logic across RV-specific execution paths.
    - RV has additional compute path(s), e.g. `deferred1_csh`, that must stay behaviorally consistent with `deferred1`.

5. Add compatibility wrappers for recurring drift points.
    - Macro naming differences.
    - function signature differences (e.g., fog helpers).

## Practical Next Ports

1. Port `reflectionBlurFilter.glsl` and integrate into RV reflection path with RV's buffer contract.
2. Port the upstream IPBR split material-handling modules and adapt call sites.
3. Do a targeted reflection settings parity pass in `shaders.properties` (not a full replacement).
