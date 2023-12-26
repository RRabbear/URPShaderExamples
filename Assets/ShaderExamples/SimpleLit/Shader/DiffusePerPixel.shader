Shader "SimpleLit/DiffusePerPixel"
{
    Properties
    {
        [MainColor] _Color ("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        [Toggle(HALF_LAMBERT)] _Pro ("HalfLambert", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "SimpleLitPerPixelPass"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            //include
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //register
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature HALF_LAMBERT

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            struct appData
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                //to transfer normalWS to frag
                float3 normalWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            v2f vert (appData input)
            {
                v2f output;

                //set posCS & posWS
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                //set normalWS
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                //set uv
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                return output;
            }

            float4 _Color;
            float4 _Diffuse;

            float4 frag (v2f input) : SV_TARGET
            {
                //if cascade on, do this in fragment
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);

                //get main light
                Light worldLight = GetMainLight(shadowCoord);

                //get shadow
                half shadow = worldLight.shadowAttenuation;

                //compute diffuse
                float3 diffuse = _Diffuse.rgb * LightingLambert(worldLight.color, worldLight.direction, input.normalWS);

                //sample texture
                float4 texSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                //if shader_feature HALF_LAMBERT is on
                #if defined(HALF_LAMBERT)
                    diffuse = _Diffuse.rgb * (dot(input.normalWS, worldLight.direction) * 0.5 + 0.5) * worldLight.color;
                #endif

                return float4((diffuse + UNITY_LIGHTMODEL_AMBIENT.xyz) * shadow, 1.0) * _Color * texSample; 
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShaderCasterPass"

            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM
            #include "ShaderCaster.hlsl"
            ENDHLSL
        }
    }
}
