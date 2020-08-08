Shader "MTE_Packed_Test"
{
	Properties
	{
		_Control ("Control (RGBA)", 2D) = "red" {}
		_Splat ("Packed Layers", 2D) = "white" {}
		_Splat0_Rect("Layer 1 UV Rect", Vector) = (0,0,1,1)
		_Splat1_Rect("Layer 2 UV Rect", Vector) = (0,0,1,1)
		_Splat2_Rect("Layer 3 UV Rect", Vector) = (0,0,1,1)
		_Splat3_Rect("Layer 4 UV Rect", Vector) = (0,0,1,1)
	}

	CGINCLUDE
		#pragma surface surf Lambert vertex:MTE_SplatmapVert finalcolor:MTE_SplatmapFinalColor finalprepass:MTE_SplatmapFinalPrepass finalgbuffer:MTE_SplatmapFinalGBuffer
		#pragma multi_compile_fog

		struct Input
		{
			float4 tc;
			UNITY_FOG_COORDS(0)
		};

		sampler2D _Control;
		float4 _Control_ST;
		sampler2D _Splat;
		float4 _Splat_ST;
		float4 _Splat0_Rect, _Splat1_Rect, _Splat2_Rect, _Splat3_Rect;

		#include "../MTE Common.cginc"

		void MTE_SplatmapVert(inout appdata_full v, out Input data)
		{
			UNITY_INITIALIZE_OUTPUT(Input, data);
			data.tc = v.texcoord;
			float4 pos = UnityObjectToClipPos(v.vertex);
			UNITY_TRANSFER_FOG(data, pos);

			v.tangent.xyz = cross(v.normal, float3(0,0,1));
			v.tangent.w = -1;
		}

		//rect: x, y, width, height
		float2 TransformPacked(float2 tc, float4 rect, float2 splatTilling, float2 splatOffset)
		{
			float2 inputUV = tc;
			float2 llCorner = rect.xy;
			float2 urCorner = rect.xy + rect.zw;
			float xDim = splatTilling.x;
			float yDim = splatTilling.y;

			float2 newUV = inputUV;// (inputUV - llCorner) / (urCorner - llCorner); //converts from input uv to values between (0.0, 0.0) and (1.0, 1.0)
			newUV.x = newUV.x * xDim % 1; //makes the newUV coordinates repeat xDim times on the x axis
			newUV.y = newUV.y * yDim % 1; //makes the newUV coordinates repeat yDim times on the y axis
			newUV = newUV * (urCorner - llCorner) + llCorner; //converts values between (0.0, 0.0) and (1.0, 1.0) to values between the lower left corner and the upper right corner

			tc = newUV;
			return tc;
		}

		void MTE_SplatmapMix(Input IN, out half weight, out fixed4 mixedDiffuse)
		{
			float2 uvControl = TRANSFORM_TEX(IN.tc.xy, _Control);
			float2 uvSplat0 = TransformPacked(IN.tc.xy, _Splat0_Rect, _Splat_ST.xy, _Splat_ST.zw);
			float2 uvSplat1 = TransformPacked(IN.tc.xy, _Splat1_Rect, _Splat_ST.xy, _Splat_ST.zw);
			float2 uvSplat2 = TransformPacked(IN.tc.xy, _Splat2_Rect, _Splat_ST.xy, _Splat_ST.zw);
			float2 uvSplat3 = TransformPacked(IN.tc.xy, _Splat3_Rect, _Splat_ST.xy, _Splat_ST.zw);

			half4 splat_control = tex2D(_Control, uvControl);
			weight = dot(splat_control, half4(1, 1, 1, 1));
			splat_control /= (weight + 1e-3f);

			float2 uv_ddx = ddx(IN.tc.xy);
			float2 uv_ddy = ddy(IN.tc.xy);
			mixedDiffuse = 0;
			mixedDiffuse += splat_control.r * tex2Dgrad(_Splat, uvSplat0, uv_ddx, uv_ddy);
			mixedDiffuse += splat_control.g * tex2Dgrad(_Splat, uvSplat1, uv_ddx, uv_ddy);
			mixedDiffuse += splat_control.b * tex2Dgrad(_Splat, uvSplat2, uv_ddx, uv_ddy);
			mixedDiffuse += splat_control.a * tex2Dgrad(_Splat, uvSplat3, uv_ddx, uv_ddy);
		}

		void surf(Input IN, inout SurfaceOutput o)
		{
			fixed4 mixedDiffuse;
			half weight;
			MTE_SplatmapMix(IN, weight, mixedDiffuse);
			o.Albedo = mixedDiffuse.rgb;
			o.Alpha = weight;
		}
	ENDCG
	
	Category
	{
		Tags
		{
			"Queue" = "Geometry-99"
			"RenderType" = "Opaque"
		}
		SubShader//for target 3.0+
		{
			CGPROGRAM
				#pragma target 3.0
			ENDCG
		}
	}
}