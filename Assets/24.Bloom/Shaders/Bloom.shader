Shader "Custom/Bloom" 
{
	Properties 
	{
		_MainTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE
		#include "UnityCG.cginc"

		sampler2D _MainTex, _SourceTex;
		float4 _MainTex_TexelSize;
		half4 _Filter;
		half _Intensity;

		// Prefilter the input color
		half3 Prefilter (half3 c) {
			half brightness = max(c.r, max(c.g, c.b));
			half soft = brightness - _Filter.y;
			soft = clamp(soft, 0, _Filter.z);
			soft = soft * soft * _Filter.w;
			half contribution = max(soft, brightness - _Filter.x);
			contribution /= max(brightness, 0.00001);
			return c * contribution;
		}
		
		// Sample the input texture
		half3 Sample (float2 uv) 
		{
			return tex2D(_MainTex, uv).rgb;
		}

		// Sample the input texture in a box pattern
		half3 SampleBox (float2 uv, float delta) 
		{
			float4 o = _MainTex_TexelSize.xyxy * float2(-delta, delta).xxyy;
			half3 s =
				Sample(uv + o.xy) + Sample(uv + o.zy) +
				Sample(uv + o.xw) + Sample(uv + o.zw);
			return s * 0.25f;
		}

		// Structure to hold vertex data
		struct VertexData 
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		// Structure to hold interpolated data
		struct Interpolators 
		{
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

		// Vertex shader function
		Interpolators VertexProgram (VertexData v) 
		{
			Interpolators i;
			i.pos = UnityObjectToClipPos(v.vertex);
			i.uv = v.uv;
			return i;
		}
	ENDCG

	SubShader 
	{
		Cull Off
		ZTest Always
		ZWrite Off

		Pass 
		{ // Pass 0: Prefiltering
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target 
				{
					// Apply prefiltering
					return half4(Prefilter(SampleBox(i.uv, 1)), 1);
				}
			ENDCG
		}

		Pass
		{ // Pass 1: Regular sampling
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target 
				{
					// Sample input texture
					return half4(SampleBox(i.uv, 1), 1);
				}
			ENDCG
		}
		
		Pass 
		{ // Pass 2: Additional blurring
			Blend One One

			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target 
				{
					// Apply blurring
					return half4(SampleBox(i.uv, 0.5), 1);
				}
			ENDCG
		}

		Pass
		{ // Pass 3: Combine with source texture
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target 
				{
					// Sample source texture
					half4 c = tex2D(_SourceTex, i.uv);
					// Add bloom with intensity
					c.rgb += _Intensity * SampleBox(i.uv, 0.5);
					// Return combined color
					return c;
				}
			ENDCG
		}

		Pass { // Pass 4: Bloom only
			CGPROGRAM
				#pragma vertex VertexProgram
				#pragma fragment FragmentProgram

				half4 FragmentProgram (Interpolators i) : SV_Target 
				{
					// Apply bloom intensity
					return half4(_Intensity * SampleBox(i.uv, 0.5), 1);
				}
			ENDCG
		}
	}
}