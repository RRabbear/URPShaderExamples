Shader "SimpleLit/DiffusePerVertex"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
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

            v2f vert (appData input)
            {
                v2f output;
                
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                
                //set posCS
                output.positionCS = posInputs.positionCS;

                //get normalWS
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                float3 normalWS = normalInputs.normalWS;

                //get light
                Light worldLight = GetMainLight();

                //compute diffuse
                float3 diffuse = _Diffuse.rgb * LightingLambert(worldLight.color, worldLight.direction, normalWS);
                output.color = diffuse + UNITY_LIGHTMODEL_AMBIENT.xyz;

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
