Shader "ToonShader/ToonShader"
{
    Properties
    {
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        [MainTexture] _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Smoothness ("Smoothness", Range(0, 1)) = 0.2
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        [HDR] _AmbientColor ("Ambient Color", Color) = (0.4,0.4,0.4,1)
        [HDR] _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimAmount ("Rim Amount", Range(0, 1)) = 0.716
        _RimThreshold ("Rim Threshold", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ToonShaderPass"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            //define
            #define _SPECULAR_COLOR

            //include
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/surfaceInput.hlsl"         
            
            //pragma
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag

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
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            v2f vert (appData input)
            {
                v2f output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;

                output.shadowCoord = GetShadowCoord(posInputs);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;

                output.uv = TRANSFORM_TEX(input.uv, _MainTex);

                return output;
            }

            float4 _Color;
            float4 _Specular;
            float _Smoothness;
            float _Metallic;
            float4 _AmbientColor;
            float4 _RimColor;
            float _RimAmount;
            float _RimThreshold;

            float4 frag (v2f input) : SV_TARGET
            {
                half4 albedoAlpha = SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedoAlpha.rgb * _Color.rgb;
                surfaceData.specular = _Specular;
                surfaceData.smoothness = _Smoothness;

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.normalWS = NormalizeNormalPerPixel(input.normalWS);
                inputData.shadowCoord = input.shadowCoord;

                Light light = GetMainLight(inputData.shadowCoord);
                half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);

                //calculate diffuse              
                half NdotL = dot(inputData.normalWS, light.direction);
                half lightIntensity = smoothstep(0, 0.01, NdotL * light.shadowAttenuation);
                half3 lightDiffuseColor = (lightIntensity + _AmbientColor.rgb) * light.color;  //add ambient color for dark side

                //calculate specular
                #if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                    half smoothness = exp2(10 * surfaceData.smoothness + 1);
                half3 halfVec = SafeNormalize(light.direction + inputData.viewDirectionWS);
                half NdotH = dot(inputData.normalWS, halfVec);
                half modifier = pow(NdotH * lightIntensity, smoothness);
                half specularIntensity = smoothstep(0, 0.01, modifier);
                half3 lightSpecularColor = specularIntensity * surfaceData.specular.rgb * attenuatedLightColor;
                #endif

                //calculate rim color
                half NdotV = dot(inputData.viewDirectionWS, inputData.normalWS);
                float4 rimModifer = (1 - NdotV) * pow(NdotL, _RimThreshold);
                float rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimModifer);
                float3 LightRimColor = _RimColor * rimIntensity * attenuatedLightColor;

                half4 color = half4(lightDiffuseColor * surfaceData.albedo + lightSpecularColor * surfaceData.albedo + LightRimColor * surfaceData.albedo, 1.0);
                return color;
            }
            ENDHLSL
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
