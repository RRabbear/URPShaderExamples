Shader "SimpleLit/SpecularBlinnPhong"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Glossiness ("Glossiness", Float) = 20
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            //use Blinn-Phong model
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

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
                float3 positionWS : TEXCOORD0;
                float3 normalWS : NORMAL;
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
                float3 viewDirWS = GetWorldSpaceViewDir(input.normalWS);
                float3 specular = LightingSpecular(worldLight.color, worldLight.direction, input.normalWS, viewDirWS, _Specular, _Glossiness);

                InputData LightingInput = (InputData)0;
                LightingInput.positionWS = input.positionWS;
                LightingInput.normalWS = input.normalWS;
                LightingInput.viewDirectionWS = viewDirWS;

                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = diffuse;
                surfaceInput.specular = specular;
                surfaceInput.smoothness = _Glossiness;
                //alpha is not supported now
                surfaceInput.alpha = _Color.a;
                
                return UniversalFragmentBlinnPhong(LightingInput, surfaceInput) * _Color;
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
