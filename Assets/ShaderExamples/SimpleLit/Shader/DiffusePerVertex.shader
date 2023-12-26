Shader "SimpleLit/DiffusePerVertex"
{
    Properties
    {
        [MainColor] _Color ("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "SimpleLitPerVertexPass"

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
                float3 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            float4 _Color;
            float4 _Diffuse;

            v2f vert (appData input)
            {
                v2f output;
                
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                
                //get posWS
                float3 positionWS = posInputs.positionWS;
                
                //set posCS
                output.positionCS = posInputs.positionCS;

                //set uv
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                //get normalWS
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                float3 normalWS = normalInputs.normalWS;
                
                //compute shadow
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                Light worldLight = GetMainLight(shadowCoord);   //get main light
                half shadow = worldLight.shadowAttenuation;

                //compute diffuse
                float3 diffuse = _Diffuse.rgb * LightingLambert(worldLight.color, worldLight.direction, normalWS);
                
                //set color
                output.color = (diffuse + UNITY_LIGHTMODEL_AMBIENT.xyz) * shadow;

                return output;
            }

            float4 frag (v2f input) : SV_TARGET
            {
                float4 texSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

                return float4(input.color, 1.0) * _Color * texSample;
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
