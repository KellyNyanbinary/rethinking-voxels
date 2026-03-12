#ifdef VOXY_PATCH
    #undef CONNECTED_GLASS_EFFECT
    #undef GENERATED_NORMALS
    #undef CUSTOM_PBR
#endif


#ifdef CUSTOM_PBR
    float smoothnessD, materialMaskPh;
    GetCustomMaterials(color, normalM, lmCoordM, NdotU, shadowMult, smoothnessG, smoothnessD, highlightMult, emission, materialMaskPh, viewPos, lViewPos);
    reflectMult = smoothnessD;
#endif

if (mat == 32000) { // Water
    #include "/lib/materials/specificMaterials/translucents/water.glsl"
}
