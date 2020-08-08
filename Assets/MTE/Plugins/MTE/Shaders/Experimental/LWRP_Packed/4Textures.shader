// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "MTE/Experimental/LWRP_Packed/4Textures"
{
    Properties
    {
		_PackedSplat0("PackedSplat0", 2D) = "white" {}
		_PackedSplat1("PackedSplat1", 2D) = "white" {}
		_PackedSplat2("PackedSplat2", 2D) = "white" {}
		_PackedHeightMap("PackedHeightMap", 2D) = "white" {}
		_Control("Control", 2D) = "white" {}
		[HideInInspector] _texcoord( "", 2D ) = "white" {}

    }


    SubShader
    {
		LOD 0

		
        Tags { "RenderPipeline"="LightweightPipeline" "RenderType"="Opaque" "Queue"="Geometry-100" }

		Cull Back
		HLSLINCLUDE
		#pragma target 3.0
		ENDHLSL
		
        Pass
        {
			
        	Tags { "LightMode"="LightweightForward" }

        	Name "Base"
			Blend One Zero
			ZWrite On
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA
            
        	HLSLPROGRAM
            #define ASE_SRP_VERSION 41000
            #define _NORMALMAP 1

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            

        	// -------------------------------------
            // Lightweight Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            
        	// -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
        	#pragma fragment frag

        	

        	#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
        	#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
        	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
        	#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"

			sampler2D _Control;
			sampler2D _PackedHeightMap;
			sampler2D _PackedSplat0;
			sampler2D _PackedSplat1;
			sampler2D _PackedSplat2;
			uniform float4 _PackedHeightMap_TexelSize;
			CBUFFER_START( UnityPerMaterial )
			float4 _Control_ST;
			float4 _PackedHeightMap_ST;
			CBUFFER_END


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_tangent : TANGENT;
                float4 texcoord1 : TEXCOORD1;
				float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

        	struct GraphVertexOutput
            {
                float4 clipPos                : SV_POSITION;
                float4 lightmapUVOrVertexSH	  : TEXCOORD0;
        		half4 fogFactorAndVertexLight : TEXCOORD1; // x: fogFactor, yzw: vertex light
            	float4 shadowCoord            : TEXCOORD2;
				float4 tSpace0					: TEXCOORD3;
				float4 tSpace1					: TEXCOORD4;
				float4 tSpace2					: TEXCOORD5;
				float4 ase_texcoord7 : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            	UNITY_VERTEX_OUTPUT_STEREO
            };

			
            GraphVertexOutput vert (GraphVertexInput v  )
        	{
        		GraphVertexOutput o = (GraphVertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
            	UNITY_TRANSFER_INSTANCE_ID(v, o);
        		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.ase_texcoord7.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord7.zw = 0;
				float3 vertexValue =  float3( 0, 0, 0 ) ;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif
				v.ase_normal =  v.ase_normal ;

        		// Vertex shader outputs defined by graph
                float3 lwWNormal = TransformObjectToWorldNormal(v.ase_normal);
				float3 lwWorldPos = TransformObjectToWorld(v.vertex.xyz);
				float3 lwWTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				float3 lwWBinormal = normalize(cross(lwWNormal, lwWTangent) * v.ase_tangent.w);
				o.tSpace0 = float4(lwWTangent.x, lwWBinormal.x, lwWNormal.x, lwWorldPos.x);
				o.tSpace1 = float4(lwWTangent.y, lwWBinormal.y, lwWNormal.y, lwWorldPos.y);
				o.tSpace2 = float4(lwWTangent.z, lwWBinormal.z, lwWNormal.z, lwWorldPos.z);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                
         		// We either sample GI from lightmap or SH.
        	    // Lightmap UV and vertex SH coefficients use the same interpolator ("float2 lightmapUV" for lightmap or "half3 vertexSH" for SH)
                // see DECLARE_LIGHTMAP_OR_SH macro.
        	    // The following funcions initialize the correct variable with correct data
        	    OUTPUT_LIGHTMAP_UV(v.texcoord1, unity_LightmapST, o.lightmapUVOrVertexSH.xy);
        	    OUTPUT_SH(lwWNormal, o.lightmapUVOrVertexSH.xyz);

        	    half3 vertexLight = VertexLighting(vertexInput.positionWS, lwWNormal);
        	    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
        	    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
        	    o.clipPos = vertexInput.positionCS;

        	#ifdef _MAIN_LIGHT_SHADOWS
        		o.shadowCoord = GetShadowCoord(vertexInput);
        	#endif
        		return o;
        	}

        	half4 frag (GraphVertexOutput IN  ) : SV_Target
            {
            	UNITY_SETUP_INSTANCE_ID(IN);

        		float3 WorldSpaceNormal = normalize(float3(IN.tSpace0.z,IN.tSpace1.z,IN.tSpace2.z));
				float3 WorldSpaceTangent = float3(IN.tSpace0.x,IN.tSpace1.x,IN.tSpace2.x);
				float3 WorldSpaceBiTangent = float3(IN.tSpace0.y,IN.tSpace1.y,IN.tSpace2.y);
				float3 WorldSpacePosition = float3(IN.tSpace0.w,IN.tSpace1.w,IN.tSpace2.w);
				float3 WorldSpaceViewDirection = SafeNormalize( _WorldSpaceCameraPos.xyz  - WorldSpacePosition );
    
				float2 uv_Control = IN.ase_texcoord7.xy * _Control_ST.xy + _Control_ST.zw;
				float4 tex2DNode6 = tex2D( _Control, uv_Control );
				float2 uv0_PackedHeightMap = IN.ase_texcoord7.xy * _PackedHeightMap_ST.xy + _PackedHeightMap_ST.zw;
				float4 temp_output_74_0 = ( tex2DNode6 * tex2D( _PackedHeightMap, uv0_PackedHeightMap ) );
				float4 break75 = temp_output_74_0;
				float temp_output_73_0 = max( max( max( break75.r , break75.g ) , break75.b ) , break75.a );
				float4 appendResult78 = (float4(temp_output_73_0 , temp_output_73_0 , temp_output_73_0 , temp_output_73_0));
				float4 tex2DNode5 = tex2D( _PackedSplat0, uv0_PackedHeightMap );
				float3 appendResult125 = (float3(tex2DNode5.r , tex2DNode5.g , tex2DNode5.b));
				float4 tex2DNode67 = tex2D( _PackedSplat1, uv0_PackedHeightMap );
				float3 appendResult126 = (float3(tex2DNode67.r , tex2DNode67.g , tex2DNode67.b));
				float4 tex2DNode68 = tex2D( _PackedSplat2, uv0_PackedHeightMap );
				float3 appendResult127 = (float3(tex2DNode68.r , tex2DNode68.g , tex2DNode68.b));
				float3 appendResult128 = (float3(tex2DNode5.a , tex2DNode67.a , tex2DNode68.a));
				float4 weightedBlendVar70 = ( ( tex2DNode6 * max( ( ( temp_output_74_0 - appendResult78 ) + float4(0.3,0.3,0.3,0.3) ) , float4( 0,0,0,0 ) ) ) / max( ( break75.r + break75.g + break75.b + break75.a ) , 0.001 ) );
				float3 weightedAvg70 = ( ( weightedBlendVar70.x*appendResult125 + weightedBlendVar70.y*appendResult126 + weightedBlendVar70.z*appendResult127 + weightedBlendVar70.w*appendResult128 )/( weightedBlendVar70.x + weightedBlendVar70.y + weightedBlendVar70.z + weightedBlendVar70.w ) );
				
				float2 temp_output_94_0_g82 = uv0_PackedHeightMap;
				float2 appendResult99_g82 = (float2(_PackedHeightMap_TexelSize.x , 0.0));
				float4 tex2DNode97_g82 = tex2D( _PackedHeightMap, ( temp_output_94_0_g82 + appendResult99_g82 ) );
				float4 tex2DNode100_g82 = tex2D( _PackedHeightMap, temp_output_94_0_g82 );
				float temp_output_21_0_g84 = tex2DNode100_g82.r;
				float temp_output_128_0_g82 = 3.0;
				float temp_output_22_0_g84 = temp_output_128_0_g82;
				float3 appendResult11_g84 = (float3(1.0 , 0.0 , ( ( tex2DNode97_g82.r - temp_output_21_0_g84 ) * temp_output_22_0_g84 )));
				float2 appendResult101_g82 = (float2(0.0 , _PackedHeightMap_TexelSize.y));
				float4 tex2DNode98_g82 = tex2D( _PackedHeightMap, ( temp_output_94_0_g82 + appendResult101_g82 ) );
				float3 appendResult19_g84 = (float3(0.0 , 0.5 , ( ( tex2DNode98_g82.r - temp_output_21_0_g84 ) * temp_output_22_0_g84 )));
				float3 normalizeResult15_g84 = normalize( cross( appendResult11_g84 , appendResult19_g84 ) );
				float temp_output_21_0_g85 = tex2DNode100_g82.g;
				float temp_output_22_0_g85 = temp_output_128_0_g82;
				float3 appendResult11_g85 = (float3(1.0 , 0.0 , ( ( tex2DNode97_g82.g - temp_output_21_0_g85 ) * temp_output_22_0_g85 )));
				float3 appendResult19_g85 = (float3(0.0 , 0.5 , ( ( tex2DNode98_g82.g - temp_output_21_0_g85 ) * temp_output_22_0_g85 )));
				float3 normalizeResult15_g85 = normalize( cross( appendResult11_g85 , appendResult19_g85 ) );
				float temp_output_21_0_g83 = tex2DNode100_g82.b;
				float temp_output_22_0_g83 = temp_output_128_0_g82;
				float3 appendResult11_g83 = (float3(1.0 , 0.0 , ( ( tex2DNode97_g82.b - temp_output_21_0_g83 ) * temp_output_22_0_g83 )));
				float3 appendResult19_g83 = (float3(0.0 , 0.5 , ( ( tex2DNode98_g82.b - temp_output_21_0_g83 ) * temp_output_22_0_g83 )));
				float3 normalizeResult15_g83 = normalize( cross( appendResult11_g83 , appendResult19_g83 ) );
				float temp_output_21_0_g86 = tex2DNode100_g82.a;
				float temp_output_22_0_g86 = temp_output_128_0_g82;
				float3 appendResult11_g86 = (float3(1.0 , 0.0 , ( ( tex2DNode97_g82.a - temp_output_21_0_g86 ) * temp_output_22_0_g86 )));
				float3 appendResult19_g86 = (float3(0.0 , 0.5 , ( ( tex2DNode98_g82.a - temp_output_21_0_g86 ) * temp_output_22_0_g86 )));
				float3 normalizeResult15_g86 = normalize( cross( appendResult11_g86 , appendResult19_g86 ) );
				float4 weightedBlendVar92 = tex2DNode6;
				float3 weightedAvg92 = ( ( weightedBlendVar92.x*( ( normalizeResult15_g84 * 0.5 ) + float3( 0.5,0.5,0.5 ) ) + weightedBlendVar92.y*( ( normalizeResult15_g85 * 0.5 ) + float3( 0.5,0.5,0.5 ) ) + weightedBlendVar92.z*( ( normalizeResult15_g83 * 0.5 ) + float3( 0.5,0.5,0.5 ) ) + weightedBlendVar92.w*( ( normalizeResult15_g86 * 0.5 ) + float3( 0.5,0.5,0.5 ) ) )/( weightedBlendVar92.x + weightedBlendVar92.y + weightedBlendVar92.z + weightedBlendVar92.w ) );
				
				
		        float3 Albedo = weightedAvg70;
				float3 Normal = weightedAvg92;
				float3 Emission = 0;
				float3 Specular = float3(0.5, 0.5, 0.5);
				float Metallic = 0;
				float Smoothness = 0.5;
				float Occlusion = 1;
				float Alpha = 1;
				float AlphaClipThreshold = 0;

        		InputData inputData;
        		inputData.positionWS = WorldSpacePosition;

        #ifdef _NORMALMAP
        	    inputData.normalWS = normalize(TransformTangentToWorld(Normal, half3x3(WorldSpaceTangent, WorldSpaceBiTangent, WorldSpaceNormal)));
        #else
            #if !SHADER_HINT_NICE_QUALITY
                inputData.normalWS = WorldSpaceNormal;
            #else
        	    inputData.normalWS = normalize(WorldSpaceNormal);
            #endif
        #endif

        #if !SHADER_HINT_NICE_QUALITY
        	    // viewDirection should be normalized here, but we avoid doing it as it's close enough and we save some ALU.
        	    inputData.viewDirectionWS = WorldSpaceViewDirection;
        #else
        	    inputData.viewDirectionWS = normalize(WorldSpaceViewDirection);
        #endif

        	    inputData.shadowCoord = IN.shadowCoord;

        	    inputData.fogCoord = IN.fogFactorAndVertexLight.x;
        	    inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
        	    inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, IN.lightmapUVOrVertexSH.xyz, inputData.normalWS);

        		half4 color = LightweightFragmentPBR(
        			inputData, 
        			Albedo, 
        			Metallic, 
        			Specular, 
        			Smoothness, 
        			Occlusion, 
        			Emission, 
        			Alpha);

			#ifdef TERRAIN_SPLAT_ADDPASS
				color.rgb = MixFogColor(color.rgb, half3( 0, 0, 0 ), IN.fogFactorAndVertexLight.x );
			#else
				color.rgb = MixFog(color.rgb, IN.fogFactorAndVertexLight.x);
			#endif

        #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif

		#if ASE_LW_FINAL_COLOR_ALPHA_MULTIPLY
				color.rgb *= color.a;
		#endif
        		return color;
            }

        	ENDHLSL
        }

		
        Pass
        {
			
        	Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual

            HLSLPROGRAM
            #define ASE_SRP_VERSION 41000

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            

            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            struct GraphVertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
				
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

			CBUFFER_START( UnityPerMaterial )
			float4 _Control_ST;
			float4 _PackedHeightMap_ST;
			CBUFFER_END


        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
        	};

			
            // x: global clip space bias, y: normal world space bias
            float4 _ShadowBias;
            float3 _LightDirection;

            VertexOutput ShadowPassVertex(GraphVertexInput v )
        	{
        	    VertexOutput o;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

				
				float3 vertexValue =  float3(0,0,0) ;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal =  v.ase_normal ;

        	    float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 normalWS = TransformObjectToWorldDir(v.ase_normal);

                float invNdotL = 1.0 - saturate(dot(_LightDirection, normalWS));
                float scale = invNdotL * _ShadowBias.y;

                // normal bias is negative since we want to apply an inset normal offset
                positionWS = _LightDirection * _ShadowBias.xxx + positionWS;
				positionWS = normalWS * scale.xxx + positionWS;
                float4 clipPos = TransformWorldToHClip(positionWS);

                // _ShadowBias.x sign depens on if platform has reversed z buffer
                //clipPos.z += _ShadowBias.x;

        	#if UNITY_REVERSED_Z
        	    clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
        	#else
        	    clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
        	#endif
                o.clipPos = clipPos;

        	    return o;
        	}

            half4 ShadowPassFragment(VertexOutput IN  ) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

               

				float Alpha = 1;
				float AlphaClipThreshold = AlphaClipThreshold;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif
                return 0;
            }

            ENDHLSL
        }

		
        Pass
        {
			
        	Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }

            ZWrite On
			ColorMask 0

            HLSLPROGRAM
            #define ASE_SRP_VERSION 41000

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            

            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			CBUFFER_START( UnityPerMaterial )
			float4 _Control_ST;
			float4 _PackedHeightMap_ST;
			CBUFFER_END


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
        	};

			           

            VertexOutput vert(GraphVertexInput v  )
            {
                VertexOutput o = (VertexOutput)0;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				
				float3 vertexValue =  float3(0,0,0) ;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal =  v.ase_normal ;

        	    o.clipPos = TransformObjectToHClip(v.vertex.xyz);
        	    return o;
            }

            half4 frag(VertexOutput IN  ) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

				

				float Alpha = 1;
				float AlphaClipThreshold = AlphaClipThreshold;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif
                return 0;
            }
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
		
        Pass
        {
			
        	Name "Meta"
            Tags { "LightMode"="Meta" }

            Cull Off

            HLSLPROGRAM
            #define ASE_SRP_VERSION 41000

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex vert
            #pragma fragment frag

            

			uniform float4 _MainTex_ST;
			
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/MetaInput.hlsl"
            #include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			sampler2D _Control;
			sampler2D _PackedHeightMap;
			sampler2D _PackedSplat0;
			sampler2D _PackedSplat1;
			sampler2D _PackedSplat2;
			CBUFFER_START( UnityPerMaterial )
			float4 _Control_ST;
			float4 _PackedHeightMap_ST;
			CBUFFER_END


            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature EDITOR_VISUALIZATION


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
        	};

			
            VertexOutput vert(GraphVertexInput v  )
            {
                VertexOutput o = (VertexOutput)0;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.ase_texcoord.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord.zw = 0;

				float3 vertexValue =  float3(0,0,0) ;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif

				v.ase_normal =  v.ase_normal ;
				
                o.clipPos = MetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord2.xy, unity_LightmapST);
        	    return o;
            }

            half4 frag(VertexOutput IN  ) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

           		float2 uv_Control = IN.ase_texcoord.xy * _Control_ST.xy + _Control_ST.zw;
           		float4 tex2DNode6 = tex2D( _Control, uv_Control );
           		float2 uv0_PackedHeightMap = IN.ase_texcoord.xy * _PackedHeightMap_ST.xy + _PackedHeightMap_ST.zw;
           		float4 temp_output_74_0 = ( tex2DNode6 * tex2D( _PackedHeightMap, uv0_PackedHeightMap ) );
           		float4 break75 = temp_output_74_0;
           		float temp_output_73_0 = max( max( max( break75.r , break75.g ) , break75.b ) , break75.a );
           		float4 appendResult78 = (float4(temp_output_73_0 , temp_output_73_0 , temp_output_73_0 , temp_output_73_0));
           		float4 tex2DNode5 = tex2D( _PackedSplat0, uv0_PackedHeightMap );
           		float3 appendResult125 = (float3(tex2DNode5.r , tex2DNode5.g , tex2DNode5.b));
           		float4 tex2DNode67 = tex2D( _PackedSplat1, uv0_PackedHeightMap );
           		float3 appendResult126 = (float3(tex2DNode67.r , tex2DNode67.g , tex2DNode67.b));
           		float4 tex2DNode68 = tex2D( _PackedSplat2, uv0_PackedHeightMap );
           		float3 appendResult127 = (float3(tex2DNode68.r , tex2DNode68.g , tex2DNode68.b));
           		float3 appendResult128 = (float3(tex2DNode5.a , tex2DNode67.a , tex2DNode68.a));
           		float4 weightedBlendVar70 = ( ( tex2DNode6 * max( ( ( temp_output_74_0 - appendResult78 ) + float4(0.3,0.3,0.3,0.3) ) , float4( 0,0,0,0 ) ) ) / max( ( break75.r + break75.g + break75.b + break75.a ) , 0.001 ) );
           		float3 weightedAvg70 = ( ( weightedBlendVar70.x*appendResult125 + weightedBlendVar70.y*appendResult126 + weightedBlendVar70.z*appendResult127 + weightedBlendVar70.w*appendResult128 )/( weightedBlendVar70.x + weightedBlendVar70.y + weightedBlendVar70.z + weightedBlendVar70.w ) );
           		
				
		        float3 Albedo = weightedAvg70;
				float3 Emission = 0;
				float Alpha = 1;
				float AlphaClipThreshold = 0;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif

                MetaInput metaInput = (MetaInput)0;
                metaInput.Albedo = Albedo;
                metaInput.Emission = Emission;
                
                return MetaFragment(metaInput);
            }
            ENDHLSL
        }
		
    }
    Fallback "Hidden/InternalErrorShader"
	CustomEditor "MTE.MTEPackedShaderGUI"
	
}
/*ASEBEGIN
Version=17300
260;125;1054;676;1683.29;782.7677;2.543549;True;True
Node;AmplifyShaderEditor.TexturePropertyNode;83;-2600.47,-233.8694;Inherit;True;Property;_PackedHeightMap;PackedHeightMap;3;0;Create;True;0;0;False;0;None;d58a2f579c05d784882e2cdff83cbf37;False;white;Auto;Texture2D;-1;0;1;SAMPLER2D;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;85;-2241.29,-274.3926;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;16;-1973.355,-479.3829;Inherit;True;Property;_Normal0;Packed Heightmap;5;0;Create;False;0;0;False;0;-1;None;None;True;0;True;black;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;6;-1970.636,-759.5891;Inherit;True;Property;_Control;Control;4;0;Create;True;0;0;False;0;-1;None;a9f346189f6413747abece87dc4bd4ca;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;74;-1548.736,-364.4974;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.BreakToComponentsNode;75;-1362.836,-277.3963;Inherit;False;COLOR;1;0;COLOR;0,0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.SimpleMaxOpNode;71;-1130.137,-278.6974;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;72;-1019.637,-235.7977;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;73;-903.937,-178.8971;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;78;-741.1321,-299.8961;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.Vector4Node;90;-614.363,-527.2513;Inherit;False;Constant;_Vector0;Vector 0;6;0;Create;True;0;0;False;0;0.3,0.3,0.3,0.3;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleSubtractOpNode;77;-567.7352,-364.7966;Inherit;False;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;89;-394.363,-354.2513;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;76;-277,-356;Inherit;False;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;79;-205.4299,-269.8973;Inherit;False;4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;5;-680.9175,-84.2321;Inherit;True;Property;_PackedSplat0;PackedSplat0;0;0;Create;True;0;0;False;0;67;None;a77f3cc63b3644746bcd162f6f32fe82;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMaxOpNode;120;-46.91589,-270.6599;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.001;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;67;-679.8618,109.4893;Inherit;True;Property;_PackedSplat1;PackedSplat1;1;0;Create;True;0;0;False;0;67;None;ca7e0d9648f1aff41b440ec24489fa98;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;80;-148.3296,-520.5414;Inherit;True;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;68;-679.5864,303.4979;Inherit;True;Property;_PackedSplat2;PackedSplat2;2;0;Create;True;0;0;False;0;68;None;ca7e0d9648f1aff41b440ec24489fa98;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleDivideOpNode;81;98.87268,-457.2578;Inherit;True;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.DynamicAppendNode;128;-262.6384,332.5527;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;125;-260.0866,-57.8117;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;126;-262.5788,77.52241;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;127;-253.5769,208.6139;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WeightedBlendNode;70;303.0092,-136.3746;Inherit;True;5;0;COLOR;0,0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.WeightedBlendNode;92;300.2196,193.3223;Inherit;True;5;0;COLOR;0,0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.FunctionNode;115;-306.1477,571.3917;Inherit;True;GetNormalsFromPackedHeight;-1;;82;e838e220bfb1a834390a94fca7b1804b;0;3;128;FLOAT;3;False;102;SAMPLER2D;0;False;94;FLOAT2;0,0;False;4;FLOAT3;124;FLOAT3;50;FLOAT3;109;FLOAT3;110
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;0,0;Float;False;False;-1;2;ASEMaterialInspector;0;2;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;True;ShadowCaster;0;1;ShadowCaster;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;False;False;False;True;1;False;-1;True;3;False;-1;False;True;1;LightMode=ShadowCaster;False;0;Hidden/InternalErrorShader;0;0;Standard;0;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;649.9399,-78.1642;Float;False;True;-1;2;MTE.MTEPackedShaderGUI;0;2;MTE/Experimental/LWRP_Packed/4Textures;1976390536c6c564abb90fe41f6ee334;True;Base;0;0;Base;11;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=-100;True;2;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;False;False;True;True;True;True;True;0;False;-1;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;1;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;1;LightMode=LightweightForward;False;0;Hidden/InternalErrorShader;0;0;Standard;2;Vertex Position,InvertActionOnDeselection;1;Receive Shadows;1;1;_FinalColorxAlpha;0;4;True;True;True;True;False;;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;2;0,0;Float;False;False;-1;2;ASEMaterialInspector;0;2;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;True;DepthOnly;0;2;DepthOnly;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;False;True;False;False;False;False;0;False;-1;False;True;1;False;-1;False;False;True;1;LightMode=DepthOnly;False;0;Hidden/InternalErrorShader;0;0;Standard;0;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;3;0,0;Float;False;False;-1;2;ASEMaterialInspector;0;2;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;True;Meta;0;3;Meta;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;True;2;False;-1;False;False;False;False;False;True;1;LightMode=Meta;False;0;Hidden/InternalErrorShader;0;0;Standard;0;0
WireConnection;85;2;83;0
WireConnection;16;0;83;0
WireConnection;16;1;85;0
WireConnection;74;0;6;0
WireConnection;74;1;16;0
WireConnection;75;0;74;0
WireConnection;71;0;75;0
WireConnection;71;1;75;1
WireConnection;72;0;71;0
WireConnection;72;1;75;2
WireConnection;73;0;72;0
WireConnection;73;1;75;3
WireConnection;78;0;73;0
WireConnection;78;1;73;0
WireConnection;78;2;73;0
WireConnection;78;3;73;0
WireConnection;77;0;74;0
WireConnection;77;1;78;0
WireConnection;89;0;77;0
WireConnection;89;1;90;0
WireConnection;76;0;89;0
WireConnection;79;0;75;0
WireConnection;79;1;75;1
WireConnection;79;2;75;2
WireConnection;79;3;75;3
WireConnection;5;1;85;0
WireConnection;120;0;79;0
WireConnection;67;1;85;0
WireConnection;80;0;6;0
WireConnection;80;1;76;0
WireConnection;68;1;85;0
WireConnection;81;0;80;0
WireConnection;81;1;120;0
WireConnection;128;0;5;4
WireConnection;128;1;67;4
WireConnection;128;2;68;4
WireConnection;125;0;5;1
WireConnection;125;1;5;2
WireConnection;125;2;5;3
WireConnection;126;0;67;1
WireConnection;126;1;67;2
WireConnection;126;2;67;3
WireConnection;127;0;68;1
WireConnection;127;1;68;2
WireConnection;127;2;68;3
WireConnection;70;0;81;0
WireConnection;70;1;125;0
WireConnection;70;2;126;0
WireConnection;70;3;127;0
WireConnection;70;4;128;0
WireConnection;92;0;6;0
WireConnection;92;1;115;124
WireConnection;92;2;115;50
WireConnection;92;3;115;109
WireConnection;92;4;115;110
WireConnection;115;102;83;0
WireConnection;115;94;85;0
WireConnection;0;0;70;0
WireConnection;0;1;92;0
ASEEND*/
//CHKSM=5B59E08FDD69236CC3DCA0DB6CFA7C6F4335CCA7