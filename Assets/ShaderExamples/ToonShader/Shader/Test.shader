Shader "NedMakesGames/MyLit" {
    // Properties are options set per material, exposed by the material inspector
    Properties{
        [Header(Surface options)] // Creates a text header
        // [MainTexture] and [MainColor] allow Material.mainTexture and Material.color to use the correct properties
        [MainTexture] _ColorMap("Color", 2D) = "white" {}
        [MainColor] _ColorTint("Tint", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Float) = 0
    }
    // Subshaders allow for different behaviour and options for different pipelines and platforms
    SubShader {
        // These tags are shared by all passes in this sub shader
        Tags {"RenderPipeline" = "UniversalPipeline"}

        // Shaders can have several passes which are used to render different data about the material
        // Each pass has it's own vertex and fragment function and shader variant keywords
        Pass {
            Name "ForwardLit" // For debugging
            Tags{"LightMode" = "UniversalForward"} // Pass specific tags. 
            // "UniversalForward" tells Unity this is the main lighting pass of this shader

            HLSLPROGRAM // Begin HLSL code

            #define _SPECULAR_COLOR

            // Shader variant keywords
            // Unity automatically discards unused variants created using "shader_feature" from your final game build,
            // however it keeps all variants created using "multi_compile"
            // For this reason, multi_compile is good for global keywords or keywords that can change at runtime
            // while shader_feature is good for keywords set per material which will not change at runtime

            // Global URP keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE

            // Register our programmable stage functions
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Include our code file
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Textures
            TEXTURE2D(_ColorMap); SAMPLER(sampler_ColorMap); // RGB = albedo, A = alpha

            float4 _ColorMap_ST; // This is automatically set by Unity. Used in TRANSFORM_TEX to apply UV tiling
            float4 _ColorTint;
            float _Smoothness;

            // This attributes struct receives data about the mesh we're currently rendering
            // Data is automatically placed in fields according to their semantic
            struct Attributes {
                float3 positionOS : POSITION; // Position in object space
                float3 normalOS : NORMAL; // Normal in object space
                float2 uv : TEXCOORD0; // Material texture UVs
            };

            // This struct is output by the vertex function and input to the fragment function.
            // Note that fields will be transformed by the intermediary rasterization stage
            struct Interpolators {
                // This value should contain the position in clip space (which is similar to a position on screen)
                // when output from the vertex function. It will be transformed into pixel position of the current
                // fragment on the screen when read from the fragment function
                float4 positionCS : SV_POSITION;

                // The following variables will retain their values from the vertex stage, except the
                // rasterizer will interpolate them between vertices
                float2 uv : TEXCOORD0; // Material texture UVs
                float3 positionWS : TEXCOORD1; // Position in world space
                float3 normalWS : TEXCOORD2; // Normal in world space
            };

            // The vertex function. This runs for each vertex on the mesh.
            // It must output the position on the screen each vertex should appear at,
            // as well as any data the fragment function will need
            Interpolators Vertex(Attributes input) {
                Interpolators output;

                // These helper functions, found in URP/ShaderLib/ShaderVariablesFunctions.hlsl
                // transform object space values into world and clip space
                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
                VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS);

                // Pass position and orientation data to the fragment function
                output.positionCS = posnInputs.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _ColorMap);
                output.normalWS = normInputs.normalWS;
                output.positionWS = posnInputs.positionWS;

                return output;
            }

            // The fragment function. This runs once per fragment, which you can think of as a pixel on the screen
            // It must output the final color of this pixel
            float4 Fragment(Interpolators input) : SV_TARGET{
                float2 uv = input.uv;
                // Sample the color map
                float4 colorSample = SAMPLE_TEXTURE2D(_ColorMap, sampler_ColorMap, uv);

                // For lighting, create the InputData struct, which contains position and orientation data
                InputData lightingInput = (InputData)0; // Found in URP/ShaderLib/Input.hlsl
                lightingInput.positionWS = input.positionWS;
                lightingInput.normalWS = normalize(input.normalWS);
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS); // In ShaderVariablesFunctions.hlsl
                lightingInput.shadowCoord = TransformWorldToShadowCoord(input.positionWS); // In Shadows.hlsl
                
                // Calculate the surface data struct, which contains data from the material textures
                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = colorSample.rgb * _ColorTint.rgb;
                surfaceInput.alpha = colorSample.a * _ColorTint.a;
                surfaceInput.specular = 1;
                surfaceInput.smoothness = _Smoothness;

            #if UNITY_VERSION >= 202120
                return UniversalFragmentBlinnPhong(lightingInput, surfaceInput);
            #else
                return UniversalFragmentBlinnPhong(lightingInput, surfaceInput.albedo, float4(surfaceInput.specular, 1), surfaceInput.smoothness, surfaceInput.emission, surfaceInput.alpha);
            #endif
            }
            ENDHLSL
        }
    }
}