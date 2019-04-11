//
//  BBMetalHalftoneFilter.metal
//  BBMetalImage
//
//  Created by Kaibo Lu on 4/10/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

#include <metal_stdlib>
#include "BBMetalShaderTypes.h"
using namespace metal;

kernel void halftoneKernel(texture2d<half, access::write> outputTexture [[texture(0)]],
                           texture2d<half, access::sample> inputTexture [[texture(1)]],
                           device float *fractionalWidth [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    
    if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) { return; }
    
    const float fractionalWidthOfPixel = float(*fractionalWidth);
    const float aspectRatio = float(inputTexture.get_height()) / float(inputTexture.get_width());
    const float2 sampleDivisor = float2(fractionalWidthOfPixel, fractionalWidthOfPixel / aspectRatio);
    
    const float2 textureCoordinate = float2(float(gid.x) / inputTexture.get_width(), float(gid.y) / inputTexture.get_height());
    const float2 samplePos = textureCoordinate - mod(textureCoordinate, sampleDivisor) + float2(0.5) * sampleDivisor;
    const float2 textureCoordinateToUse = float2(textureCoordinate.x, (textureCoordinate.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float2 adjustedSamplePos = float2(samplePos.x, (samplePos.y * aspectRatio + 0.5 - 0.5 * aspectRatio));
    const float distanceFromSamplePoint = distance(adjustedSamplePos, textureCoordinateToUse);
    
    constexpr sampler quadSampler;
    const float3 sampledColor = float3(inputTexture.sample(quadSampler, samplePos ).rgb);
    const float dotScaling = 1.0 - dot(sampledColor, float3(kLuminanceWeighting));
    
    const float checkForPresenceWithinDot = 1.0 - step(distanceFromSamplePoint, (fractionalWidthOfPixel * 0.5) * dotScaling);
    const half4 outColor(half3(checkForPresenceWithinDot), 1.0h);
    outputTexture.write(outColor, gid);
}
