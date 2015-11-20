//
//  GLKHelper.h
//  MandelbrotShader
//
//  Created by Tamás Zahola on 02/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import <GLKit/GLKit.h>

void NSLogGLKMatrix4(const GLKMatrix4 matrix);
void NSLogGLKMatrix3(const GLKMatrix3 matrix);

GLKMatrix3 GLKMatrix3MakeTranslation(float dx, float dy);
GLKMatrix3 GLKMatrix3Translate(GLKMatrix3 m, float dx, float dy);