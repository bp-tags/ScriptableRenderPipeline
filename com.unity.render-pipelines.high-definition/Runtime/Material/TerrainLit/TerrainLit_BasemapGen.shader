Shader "Hidden/HDRP/TerrainLit_BasemapGen"
{
    Properties
    {
        [HideInInspector] _DstBlend("DstBlend", Float) = 0.0
    }

    SubShader
    {
        Tags { "SplatCount" = "8" }

        HLSLINCLUDE

        #pragma target 4.5
        #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

        #define USE_LEGACY_UNITY_MATRIX_VARIABLES
        #define SURFACE_GRADIENT // Must use Surface Gradient as the normal map texture format is now RG floating point
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/NormalSurfaceGradient.hlsl"
        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/TerrainLit/TerrainLitSurfaceData.hlsl"

        // Terrain builtin keywords
        #pragma shader_feature _TERRAIN_8_LAYERS
        #pragma shader_feature _NORMALMAP
        #pragma shader_feature _MASKMAP

        #pragma shader_feature _TERRAIN_BLEND_HEIGHT

        #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/TerrainLit/TerrainLit_Splatmap_Includes.hlsl"

        CBUFFER_START(UnityTerrain)
            UNITY_TERRAIN_CB_VARS
            float4 _Control0_ST;
            float4 _Control0_TexelSize;
        CBUFFER_END

        struct Attributes {
            float3 vertex : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float4 texcoord : TEXCOORD0;
        };

        #pragma vertex Vert
        #pragma fragment Frag

        float2 ComputeControlUV(float2 uv)
        {
            // adjust splatUVs so the edges of the terrain tile lie on pixel centers
            return (uv * (_Control0_TexelSize.zw - 1.0f) + 0.5f) * _Control0_TexelSize.xy;
        }

        Varyings Vert(Attributes input)
        {
            Varyings output;
            
            output.positionCS = TransformWorldToHClip(input.vertex.xyz);
            output.texcoord.xy = TRANSFORM_TEX(input.texcoord, _Control0);
            output.texcoord.zw = ComputeControlUV(output.texcoord.xy);
            return output;
        }

        ENDHLSL

        Pass
        {
            Tags
            {
                "Name" = "_MainTex"
                "Format" = "ARGB32"
                "Size" = "1"
            }

            ZTest Always Cull Off ZWrite Off
            Blend One [_DstBlend]

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/TerrainLit/TerrainLit_Splatmap.hlsl"

            float4 Frag(Varyings input) : SV_Target
            {
                TerrainLitSurfaceData surfaceData;
                InitializeTerrainLitSurfaceData(surfaceData);
                TerrainSplatBlend(input.texcoord.zw, input.texcoord.xy, surfaceData);
                return float4(surfaceData.albedo, surfaceData.smoothness);
            }

            ENDHLSL
        }

        Pass
        {
            // _NormalMap pass will get ignored by terrain basemap generation code. Put here so that the VTC can use it to generate cache for normal maps.
            Tags
            {
                "Name" = "_NormalMap"
                "Format" = "R16G16_Float"
                "Size" = "1"
            }

            ZTest Always Cull Off ZWrite Off
            Blend One [_DstBlend]

            HLSLPROGRAM

            #define OVERRIDE_SPLAT_SAMPLER_NAME sampler_Normal0
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/TerrainLit/TerrainLit_Splatmap.hlsl"

            float2 Frag(Varyings input) : SV_Target
            {
                TerrainLitSurfaceData surfaceData;
                InitializeTerrainLitSurfaceData(surfaceData);
                TerrainSplatBlend(input.texcoord.zw, input.texcoord.xy, surfaceData);
                return surfaceData.normalData.xy; // RT format is supposed to be floating point
            }

            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "Name" = "_MetallicTex"
                "Format" = "RG16"
                "Size" = "1/4"
            }

            ZTest Always Cull Off ZWrite Off
            Blend One [_DstBlend]

            HLSLPROGRAM

            #define OVERRIDE_SPLAT_SAMPLER_NAME sampler_Mask0
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/TerrainLit/TerrainLit_Splatmap.hlsl"

            float2 Frag(Varyings input) : SV_Target
            {
                TerrainLitSurfaceData surfaceData;
                InitializeTerrainLitSurfaceData(surfaceData);
                TerrainSplatBlend(input.texcoord.zw, input.texcoord.xy, surfaceData);
                return float2(surfaceData.metallic, surfaceData.ao);
            }

            ENDHLSL
        }
    }
    Fallback Off
}
