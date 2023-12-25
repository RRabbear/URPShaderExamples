Shader "SimpleLit/DiffusePerPixel"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
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

            struct appData
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                //to transfer normalWS to frag
                float3 normalWS : TEXCOORD0;
            };

            v2f vert (appData input)
            {
                v2f output;

                //set posCS
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;

                //set normalWS
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                return output;
            }

            float4 _Color;
            float4 _Diffuse;

            float4 frag (v2f input) : SV_TARGET
            {
                //get main light
                Light worldLight = GetMainLight();

                //compute diffuse
                float3 diffuse = _Diffuse.rgb * LightingLambert(worldLight.color, worldLight.direction, input.normalWS);

                //if shader_feature HALF_LAMBERT is on
                #if defined(HALF_LAMBERT)
                    diffuse = _Diffuse.rgb * (dot(input.normalWS, worldLight.direction) * 0.5 + 0.5) * worldLight.color;
                #endif

                return float4(diffuse + UNITY_LIGHTMODEL_AMBIENT.xyz, 1.0) * _Color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
