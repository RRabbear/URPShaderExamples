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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
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

            half3 CalToonBlinnPhong(Light light, SurfaceData surfaceData, InputData inputData)
            {
                //calculate diffuse
                //diffuse color = (NormalWS * LightDirection + AmbientColor) * LightColor
                //why need plus AmbientColor, becuase the dark side need some color for it
                //why do smoothstep, because we want it looks like anime        
                half NdotL = dot(inputData.normalWS, light.direction);
                half lightIntensity = smoothstep(0, 0.01, NdotL * light.shadowAttenuation * light.distanceAttenuation);
                half3 lightDiffuseColor = (lightIntensity + _AmbientColor.rgb) * light.color;  //add ambient color for dark side

                //calculate specular
                //specular color = pow(normalWS * (LightDirection + ViewDirectionWS)), smoothness)
                //to make specular scale easier to adjust, we do exp2
                //avoid specular area appearing in dark side, we multiply lightIntensity when do pow
                //also, we do smoothstep to get anime effect
                #if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                    half smoothness = exp2(10 * surfaceData.smoothness + 1);
                half3 halfVec = SafeNormalize(light.direction + inputData.viewDirectionWS);
                half NdotH = dot(inputData.normalWS, halfVec);
                half modifier = pow(NdotH * lightIntensity, smoothness);
                half specularIntensity = smoothstep(0, 0.01, modifier);
                half3 lightSpecularColor = _Specular.rgb * specularIntensity;
                #endif

                //calculate rim color
                //rim is the outline of the light side
                half NdotV = dot(inputData.viewDirectionWS, inputData.normalWS);
                half4 rimModifer = (1 - NdotV) * pow(NdotL, _RimThreshold);
                half rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimModifer);
                half3 LightRimColor = _RimColor * rimIntensity;

                return lightDiffuseColor + lightSpecularColor + LightRimColor;
            }

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
                half3 color = CalToonBlinnPhong(light, surfaceData, inputData);

                LightingData lightingData = CreateLightingData(inputData, surfaceData);
                int pixelLightCount = GetAdditionalLightsCount();
                for(int i = 0; i < pixelLightCount; i++)
                {
                    Light additionalLight = GetAdditionalLight(i, input.positionWS);
                    color += CalToonBlinnPhong(additionalLight, surfaceData, inputData);
                }

                return half4(color * surfaceData.albedo, 1.0);
            }
            ENDHLSL
        }
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
