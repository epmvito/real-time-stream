#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 textureCoordinate;
} TextureMappingVertex;

float4x4 defaultRenderedCoordinates() {
    return float4x4(float4( -1.0, -1.0, 0.0, 1.0 ),      /// (x, y, depth, W)
                    float4(  1.0, -1.0, 0.0, 1.0 ),
                    float4( -1.0,  1.0, 0.0, 1.0 ),
                    float4(  1.0,  1.0, 0.0, 1.0 ));
}

float4x2 defaultTextureCoordinates() {
    return float4x2(float2( 0.0, 1.0 ), /// (x, y)
                    float2( 1.0, 1.0 ),
                    float2( 0.0, 0.0 ),
                    float2( 1.0, 0.0 ));
}

enum ScalingMode {
    scaleToFill = 0,
    aspectfill = 1,
    aspectfit = 2,
};
    
vertex TextureMappingVertex scalingVertex(unsigned int vertex_id [[ vertex_id ]],
                                          constant float2* aspectRatioData [[ buffer(0) ]],
                                          constant ScalingMode& mode [[ buffer(1) ]]) {
    float4x4 renderedCoordinates = defaultRenderedCoordinates();
    float4x2 textureCoordinates = defaultTextureCoordinates();
    
    float contentAspect = aspectRatioData[0].x / aspectRatioData[0].y;
    float targetAspect = aspectRatioData[1].x / aspectRatioData[1].y;
    float scale = 1.0;
    
    switch(mode) {
        case ScalingMode::scaleToFill:
            break;
        case ScalingMode::aspectfill:
            if (contentAspect > targetAspect) {
                scale = contentAspect / targetAspect;
                renderedCoordinates[0].x *= scale;
                renderedCoordinates[1].x *= scale;
                renderedCoordinates[2].x *= scale;
                renderedCoordinates[3].x *= scale;
            } else {
                scale = targetAspect / contentAspect;
                renderedCoordinates[0].y *= scale;
                renderedCoordinates[1].y *= scale;
                renderedCoordinates[2].y *= scale;
                renderedCoordinates[3].y *= scale;
            }
            break;
        case ScalingMode::aspectfit:
            if (contentAspect > targetAspect) {
                scale = targetAspect / contentAspect;
                renderedCoordinates[0].y *= scale;
                renderedCoordinates[1].y *= scale;
                renderedCoordinates[2].y *= scale;
                renderedCoordinates[3].y *= scale;
            } else {
                scale = contentAspect / targetAspect;
                renderedCoordinates[0].x *= scale;
                renderedCoordinates[1].x *= scale;
                renderedCoordinates[2].x *= scale;
                renderedCoordinates[3].x *= scale;
            }
            break;
    }
    
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.textureCoordinate = textureCoordinates[vertex_id];
    
    return outVertex;
}

fragment half4 displayBackTexture(TextureMappingVertex mappingVertex [[ stage_in ]],
                                  texture2d<float, access::sample> luminanceTexture [[ texture(0) ]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    
    float4 luminance = luminanceTexture.sample(s, mappingVertex.textureCoordinate);
    
    
    return half4(luminance);
}

// VHS Effect

float4 hash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(443.8975, 397.2973, 491.1871, 470.7827));
    p4 += dot(p4.wzxy, p4 + 19.19);
    return fract(float4(p4.x * p4.y, p4.x * p4.z, p4.y * p4.w, p4.x * p4.w));
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(float3 x) {
    float3 p = floor(x);
    float3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    float res = mix(mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
                        mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                    mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                        mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
    return res;
}

float tapeNoise(float2 p, float t) {
    float y = p.y;
    float s = t * 2.0;
    
    float v = (noise(float3(y * 0.01 + s, 1.0, 1.0)) + 0.0)
    * (noise(float3(y * 0.011 + 1000.0 + s, 1.0, 1.0)) + 0.0)
    * (noise(float3(y * 0.51 + 421.0 + s, 1.0, 1.0)) + 0.0);
    
    v *= hash42(float2(p.x + t * 0.01, y)).x + 0.3;
    
    v = pow(v + 0.3, 1.0);
    if (v < 0.7) v = 0.0;
    return v;
}

fragment float4 vhs2(TextureMappingVertex mappingVertex [[ stage_in ]],
                    texture2d<float, access::sample> luminanceTexture [[ texture(0) ]],
                    constant float2 &iResolution [[ buffer(0) ]],
                    constant float &iTime [[ buffer(1) ]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float2 uv = mappingVertex.textureCoordinate;
    
    float linesN = 240.0; // fields per second
    float one_y = iResolution.y / linesN; // field line
    uv = floor(uv * iResolution / one_y) * one_y;
    
    float noiseValue = tapeNoise(uv, iTime);
    
    float4 originalColor = luminanceTexture.sample(s, mappingVertex.textureCoordinate);
    
    // Blend the noise with the original texture color
    float blendFactor = 0.3;
    float4 blendedColor = mix(originalColor, float4(noiseValue, noiseValue, noiseValue, 1.0), blendFactor);
    
    return float4(blendedColor);
}
    
