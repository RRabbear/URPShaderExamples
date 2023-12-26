//include
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
};

float3 _LightDirection;

float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS)
{
    float3 lightDir = _LightDirection;

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDir));
    
    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    return positionCS;
}

v2f vert (appData input)
{
    v2f output;

    VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS);
    float3 posWS = posInputs.positionWS;

    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
    float3 normalWS = normalInputs.normalWS;

    output.positionCS = GetShadowCasterPositionCS(posWS, normalWS);

    return output;
}

float4 frag (v2f input) : SV_TARGET
{
    return 0;
}