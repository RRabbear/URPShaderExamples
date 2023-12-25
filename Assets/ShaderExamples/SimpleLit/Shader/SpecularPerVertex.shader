Shader "SimpleLit/SpecularPerVertex"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        //specular area size
        _Glossiness ("Glossiness", float) = 20.0
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
            Name "SpecularPerVertexPass"

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
                float3 color : COLOR;
            };

            float4 _Color;
            float4 _Diffuse;
            float4 _Specular;
            float _Glossiness;

            v2f vert (appData input)
            {
                v2f output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;
                
                //positionWS
                float3 positionWS = posInputs.positionWS;

                //get main light
                Light worldLight = GetMainLight();

                //normalWS
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                float3 normalWS = normalInputs.normalWS;

                //diffuse
                float3 diffuse = _Diffuse.rgb * LightingLambert(worldLight.color, worldLight.direction, normalWS);

                //specular
                float3 viewDirWS = GetWorldSpaceViewDir(positionWS);
                #if defined(_MODEL_BLINN)
                    float3 specular = LightingSpecular(worldLight.color, worldLight.direction, normalWS, viewDirWS, _Specular, _Glossiness);
                #else
                    float3 reflectDir = SafeNormalize(reflect(-worldLight.direction, normalWS));
                    float3 specular = worldLight.color.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDirWS)), _Glossiness);
                #endif

                output.color = diffuse + specular + UNITY_LIGHTMODEL_AMBIENT.xyz;

                return output;
            }

            float4 frag (v2f input) : SV_TARGET
            {
                return float4(input.color, 1.0) * _Color;
            }

            ENDHLSL
        }
        
    }
    FallBack "Diffuse"
}
