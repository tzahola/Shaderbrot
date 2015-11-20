//
//  GLKHelper.m
//  MandelbrotShader
//
//  Created by Tamás Zahola on 02/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import "GLKHelper.h"

void NSLogGLKMatrix3(const GLKMatrix3 matrix){
    NSLog(@"\n%g %g %g\n%g %g %g\n%g %g %g\n", matrix.m00, matrix.m01, matrix.m02, matrix.m10, matrix.m11, matrix.m12, matrix.m20, matrix.m21, matrix.m22);
}

void NSLogGLKMatrix4(const GLKMatrix4 matrix){
    NSLog(@"\n%g %g %g %g\n%g %g %g %g\n%g %g %g %g\n%g %g %g %g\n",
          matrix.m00, matrix.m01, matrix.m02, matrix.m03,
          matrix.m10, matrix.m11, matrix.m12, matrix.m13,
          matrix.m20, matrix.m21, matrix.m22, matrix.m23,
          matrix.m30, matrix.m31, matrix.m32, matrix.m33);
}

GLKMatrix3 GLKMatrix3MakeTranslation(float dx, float dy) {
    GLKMatrix3 m = {
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
          dx,   dy, 1.0f };
    
    return m;
}

GLKMatrix3 GLKMatrix3Translate(GLKMatrix3 m, float dx, float dy){
    GLKMatrix3 translation = GLKMatrix3MakeTranslation(dx, dy);
    return GLKMatrix3Multiply(m, translation);
}
