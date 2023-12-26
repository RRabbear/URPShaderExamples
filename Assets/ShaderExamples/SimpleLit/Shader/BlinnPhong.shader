Shader "SimpleLit/SpecularBlinnPhong"
{
    Properties
    {
        [MainColor] _Color ("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _MainTex ("MainTex", 2D) = "white" {}
        [NoScaleOffset][Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 1)) = 1.0
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
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
            Name "BlinnPhongLightPass"
            
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
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            float4 _NormalMap_ST;

            struct appData
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : NORMAL;
                float4 tangentWS : TANGENT;
                float2 uv : TEXCOORD1;
            };

            v2f vert (appData input)
            {
                v2f output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w);

                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                return output;
            }

            float4 _Color;
            float4 _Diffuse;
            float4 _Specular;
            float _Smoothness;
            float _NormalStrength;

            float4 frag (v2f input) : SV_TARGET
            {
                //get main light
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light worldLight = GetMainLight(shadowCoord);

                //diffuse
                float3 diffuse = LightingLambert(worldLight.color, worldLight.direction, input.normalWS);

                //specular
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float3 specular = LightingSpecular(worldLight.color, worldLight.direction, input.normalWS, viewDirWS, _Specular, _Smoothness);

                //calculate pixel color
                float4 texSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;

                //tangent
                float3 normalWS = normalize(input.normalWS);
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv), _NormalStrength);
                float3x3 tangentToWorld = CreateTangentToWorld(normalWS, input.tangentWS.xyz, input.tangentWS.w);
                normalWS = normalize(TransformTangentToWorld(normalTS, tangentToWorld));

                InputData LightingInput = (InputData)0;
                LightingInput.positionWS = input.positionWS;
                LightingInput.normalWS = normalWS;
                LightingInput.viewDirectionWS = viewDirWS;
                LightingInput.shadowCoord = shadowCoord;

                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = texSample.rgb;
                surfaceInput.specular = specular;
                surfaceInput.smoothness = _Smoothness;
                //alpha is not supported now
                surfaceInput.alpha = texSample.a;
                
                return UniversalFragmentBlinnPhong(LightingInput, surfaceInput);
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
