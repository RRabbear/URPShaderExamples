Shader "SimpleLit/SpecularPerPixel"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Glossiness ("Glossiness", Float) = 20
        [KeywordEnum(Phong, Blinn)] _Model ("Model.mode", float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            //use Blinn model with LightingSpecular function
            Name "SpecularPerPixel"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            //include
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"

            //register
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MODEL_PHONG _MODEL_BLINN

            struct appData
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : NORMAL;
                float3 positionWS : TEXCOORD0;
            };

            v2f vert (appData input)
            {
                v2f output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                return output;
            }

            float4 _Color;
            float4 _Diffuse;
            float4 _Specular;
            float _Glossiness;

            float4 frag (v2f input) : SV_TARGET
            {
                //world light
                Light worldLight = GetMainLight();

                //diffuse
                float3 diffuse = LightingLambert(worldLight.color, worldLight.direction, input.normalWS);

                //specular
                float3 viewDirWS = GetWorldSpaceViewDir(input.positionWS);
                #if defined(_MODEL_BLINN)
                    float3 specular = LightingSpecular(worldLight.color, worldLight.direction, input.normalWS, viewDirWS, _Specular, _Glossiness);
                #else
                    float3 reflectDir = SafeNormalize(reflect(-worldLight.direction, input.normalWS));
                    float3 specular = worldLight.color.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDirWS)), _Glossiness);
                #endif

                return float4(diffuse + specular + UNITY_LIGHTMODEL_AMBIENT.xyz, 1.0) * _Color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
