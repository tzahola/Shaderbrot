//
//  ShaderHelper.h
//  MandelbrotShader
//
//  Created by Tamás Zahola on 02/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ShaderHelper : NSObject

+(instancetype)shaderHelper;

- (GLuint)compileShaderFromFile:(NSString *)file;
- (void)linkProgram:(GLuint)prog;

@end
