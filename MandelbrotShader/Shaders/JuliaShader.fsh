//
//  JuliaShader.fsh
//  MandelbrotShader
//
//  Created by Tamás Zahola on 01/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#define M_PI 3.1415926535897932384626433832795
#define M_1_LOG_2 1.44269504089

uniform highp vec2 juliaSeed;
uniform highp mat3 screenToComplexPlaneTransform;
uniform highp float time;
uniform int limit;

void main()
{
    highp vec2 z = (screenToComplexPlaneTransform * vec3(gl_FragCoord.xy, 1.)).xy;
    
    int i = 0;
    for(;;){
        z = vec2(z.x * z.x - z.y * z.y, 2. * z.x * z.y) + juliaSeed;
        if(dot(z,z) > 4. || i == limit){
            break;
        }
        i++;
    }
    
    highp float color;
    if(i == limit) color = 1.;
    else color = ((float(i) + 1. - log(log(length(z))) * M_1_LOG_2)) / float(limit);
    
    gl_FragColor = vec4(color, color, color,1.);}
