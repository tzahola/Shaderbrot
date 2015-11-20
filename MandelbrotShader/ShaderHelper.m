//
//  ShaderHelper.m
//  MandelbrotShader
//
//  Created by Tamás Zahola on 02/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import "ShaderHelper.h"
#import <GLKit/GLKit.h>

@implementation ShaderHelper

+(instancetype)shaderHelper{
    static dispatch_once_t onceToken;
    static ShaderHelper * shaderHelper;
    dispatch_once(&onceToken, ^{
        shaderHelper = [ShaderHelper new];
    });
    return shaderHelper;
}

-(GLuint)compileShaderFromFile:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    NSAssert(source != NULL, @"Failed to load shader '%@'", file);
    
    GLuint shader = glCreateShader([self determineShaderTypeFromFileName:file]);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    NSAssert(status == GL_TRUE, @"Failed to compile shader '%s'", source);
    
    return shader;
}

-(GLenum)determineShaderTypeFromFileName:(NSString*)fileName {
    
    NSString * fileExtension = [fileName pathExtension];
    if([fileExtension isEqualToString:@"fsh"]){
        return GL_FRAGMENT_SHADER;
    }else if([fileExtension isEqualToString:@"vsh"]){
        return GL_VERTEX_SHADER;
    }else{
        NSAssert(NO, @"Invalid shader file type: '%@'", fileExtension);
        return 0;
    }
}

- (void)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    NSAssert(status == GL_TRUE, @"Failed to link shader program!");
}

- (void)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    NSAssert(status == GL_TRUE, @"Failed to validate shader program!");
}

@end
