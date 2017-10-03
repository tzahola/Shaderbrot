//
//  ViewController.m
//  MandelbrotShader
//
//  Created by Tamás Zahola on 01/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import "ViewController.h"
#import "GLKHelper.h"
#import "ShaderHelper.h"
#import <OpenGLES/ES3/gl.h>

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

enum
{
    ATTRIB_VERTEX,
    NUM_ATTRIBUTES
};

enum {
    UNIFORM_SCREEN_TO_COMPLEX_PLANE_TRANSFORM,
    UNIFORM_TIME,
    UNIFORM_JULIA_SEED,
    UNIFORM_LIMIT,
    NUM_UNIFORMS
};

typedef enum {
    kMandelbrotState,
    kJuliaState
} State;

GLfloat vertexData[] =
{
    -1,  1, 0, 1,
    1,  1, 0, 1,
    1, -1, 0, 1,
    
    1, -1, 0, 1,
    -1, -1, 0, 1,
    -1,  1, 0, 1,
};

@implementation ViewController {
    int _mandelbrotUniforms[NUM_UNIFORMS];
    GLuint _mandelbrotProgram;
    
    int _juliaUniforms[NUM_UNIFORMS];
    GLuint _juliaProgram;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    EAGLContext * _context;
    
    GLKMatrix3 _viewToComplexPlaneTransform;
    GLKVector2 _juliaSeed;
    
    CGPoint _previousTranslation;
    UIPanGestureRecognizer * _panGestureRecognizer;
    
    CGFloat _previousScale;
    UIPinchGestureRecognizer * _pinchGestureRecognizer;
    
    CGFloat _previousRotation;
    UIRotationGestureRecognizer * _rotationGestureRecognizer;
    
    UITapGestureRecognizer * _doubleTapGestureRecognizer;
    
    uint _limit;
    
    __weak IBOutlet UILabel *_maxIterationsLabel;
    __weak IBOutlet UISlider *_maxIterationsSlider;
    __weak IBOutlet UISegmentedControl *_modeSegmentedControl;
    __weak IBOutlet UISegmentedControl *_interactionSegmentedControl;
    
    __weak IBOutlet UIView* _gestureAreaView;
    IBOutlet NSLayoutConstraint* _settingsPanelHiddenConstraint;
    IBOutlet NSLayoutConstraint* _settingsPanelVisibleConstraint;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.delegate = self;
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    NSAssert(_context != nil, @"Failed to create ES context");
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.contentScaleFactor = UIScreen.mainScreen.nativeScale;
    
    self.preferredFramesPerSecond = 60;
    _limit = 128;
    
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    _panGestureRecognizer.delegate = self;
    [_gestureAreaView addGestureRecognizer:_panGestureRecognizer];
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didPinch:)];
    _pinchGestureRecognizer.delegate = self;
    [_gestureAreaView addGestureRecognizer:_pinchGestureRecognizer];
    
    _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(didRotate:)];
    _rotationGestureRecognizer.delegate = self;
    [_gestureAreaView addGestureRecognizer:_rotationGestureRecognizer];
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    _doubleTapGestureRecognizer.delegate = self;
    [_gestureAreaView addGestureRecognizer:_doubleTapGestureRecognizer];
    
    [self setupGL];
    
    [self refreshSettingsPanel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshMaxIterations];
}

- (void)refreshMaxIterations {
    _maxIterationsLabel.text = [NSString stringWithFormat:@"%d", (int)_limit];
    _maxIterationsSlider.value = _limit;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)didDoubleTap:(id)sender {
    [UIView animateWithDuration:0.3 animations:^{
        [self toggleSettingsPanel];
        [self.view layoutIfNeeded];
    }];
}

- (BOOL)isNavigatingFreely {
    return _interactionSegmentedControl.selectedSegmentIndex == 0;
}

- (BOOL)isDrawingMandelbrotSet {
    return _modeSegmentedControl.selectedSegmentIndex == 0;
}

- (void)didRotate:(id)sender {
    if ([self isNavigatingFreely]) {
        CGPoint rotationCenter = [_rotationGestureRecognizer locationInView:self.view];
        CGFloat rotation = _rotationGestureRecognizer.rotation;
        CGFloat deltaRotation;
        switch (_rotationGestureRecognizer.state) {
            case UIGestureRecognizerStateBegan:{
                deltaRotation = 0;
            } break;
                
            default:{
                deltaRotation = rotation - _previousRotation;
            } break;
        }
        
        _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, rotationCenter.x * self.view.contentScaleFactor, (self.view.bounds.size.height - rotationCenter.y) * self.view.contentScaleFactor);
        _viewToComplexPlaneTransform = GLKMatrix3RotateZ(_viewToComplexPlaneTransform, deltaRotation);
        _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, -rotationCenter.x * self.view.contentScaleFactor, -(self.view.bounds.size.height - rotationCenter.y) * self.view.contentScaleFactor);
        
        _previousRotation = rotation;
    }
}

- (void)didPinch:(id)sender {
    if ([self isNavigatingFreely]) {
        CGPoint scaleCenter = [_pinchGestureRecognizer locationInView:self.view];
        CGFloat scale = _pinchGestureRecognizer.scale;
        
        CGFloat deltaScale;
        switch (_pinchGestureRecognizer.state) {
            case UIGestureRecognizerStateBegan:{
                deltaScale = 1;
            }
                break;
                
            default:{
                deltaScale = _previousScale / scale;
            }
                break;
        }
        
        _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, scaleCenter.x * self.view.contentScaleFactor, (self.view.bounds.size.height - scaleCenter.y) * self.view.contentScaleFactor);
        _viewToComplexPlaneTransform = GLKMatrix3Scale(_viewToComplexPlaneTransform, deltaScale, deltaScale, 1);
        _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, -scaleCenter.x * self.view.contentScaleFactor, -(self.view.bounds.size.height - scaleCenter.y) * self.view.contentScaleFactor);
        
        _previousScale = scale;
    }
}

- (void)didPan:(id)sender {
    CGPoint translation = [_panGestureRecognizer translationInView:self.view];
    
    CGPoint delta;
    switch(_panGestureRecognizer.state){
        case UIGestureRecognizerStateBegan:{
            delta = CGPointMake(0, 0);
        } break;
        default:{
            delta = CGPointMake(translation.x - _previousTranslation.x, translation.y - _previousTranslation.y);
        } break;
    }
    _previousTranslation = translation;
    
    if ([self isNavigatingFreely]) {
        _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, -delta.x * self.view.contentScaleFactor, delta.y * self.view.contentScaleFactor);
    } else {
        GLKVector3 complexPlaneTranslation = GLKMatrix3MultiplyVector3(_viewToComplexPlaneTransform, GLKVector3Make(delta.x, -delta.y, 0));
        _juliaSeed = GLKVector2Add(_juliaSeed, GLKVector2Make(complexPlaneTranslation.x, complexPlaneTranslation.y));
    }
}

- (void)dealloc {
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setupGL {
    [EAGLContext setCurrentContext:_context];
    
    [self loadShaders];
    
    glDisable(GL_DEPTH_TEST);
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexData), vertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 4, GL_FLOAT, GL_FALSE, 0, BUFFER_OFFSET(0));
    
    glBindVertexArray(0);
    
    [self resetTransformation];
}

- (void)resetTransformation {
    _viewToComplexPlaneTransform = GLKMatrix3Identity;
    _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, -2, 0);
    _viewToComplexPlaneTransform = GLKMatrix3Translate(_viewToComplexPlaneTransform, 0, -1);
    
    float scale = 2 / (self.view.bounds.size.height * self.view.contentScaleFactor);
    _viewToComplexPlaneTransform = GLKMatrix3Scale(_viewToComplexPlaneTransform, scale, scale, 1);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:_context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArrays(1, &_vertexArray);
    
    glDeleteProgram(_juliaProgram);
    _juliaProgram = 0;
    
    glDeleteProgram(_mandelbrotProgram);
    _mandelbrotProgram = 0;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
#if TARGET_OS_SIMULATOR
    return;
#endif
    
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram([self isDrawingMandelbrotSet] ? _mandelbrotProgram : _juliaProgram);
    glBindVertexArray(_vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

- (void)glkViewControllerUpdate:(GLKViewController *)controller {
#if TARGET_OS_SIMULATOR
    return;
#endif
    
    int const* uniforms = [self isDrawingMandelbrotSet] ? _mandelbrotUniforms : _juliaUniforms;
    
    glUniform1i(uniforms[UNIFORM_LIMIT], _limit);
    glUniformMatrix3fv(uniforms[UNIFORM_SCREEN_TO_COMPLEX_PLANE_TRANSFORM], 1, GL_FALSE, _viewToComplexPlaneTransform.m);
    glUniform1f(uniforms[UNIFORM_TIME], (float)controller.timeSinceFirstResume);
    if(![self isDrawingMandelbrotSet]) {
        glUniform2f(uniforms[UNIFORM_JULIA_SEED], _juliaSeed.x, _juliaSeed.y);
    }
}

- (void)loadShaders {
    _mandelbrotProgram = glCreateProgram();
    _juliaProgram = glCreateProgram();
    
    GLuint vertShader = [[ShaderHelper shaderHelper] compileShaderFromFile:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]];
    GLuint mandelbrotFragShader = [[ShaderHelper shaderHelper] compileShaderFromFile:[[NSBundle mainBundle] pathForResource:@"MandelbrotShader" ofType:@"fsh"]];
    GLuint juliaFragShader = [[ShaderHelper shaderHelper] compileShaderFromFile:[[NSBundle mainBundle] pathForResource:@"JuliaShader" ofType:@"fsh"]];
    
    glAttachShader(_mandelbrotProgram, vertShader);
    glAttachShader(_mandelbrotProgram, mandelbrotFragShader);
    
    glAttachShader(_juliaProgram, vertShader);
    glAttachShader(_juliaProgram, juliaFragShader);
    
    glBindAttribLocation(_mandelbrotProgram, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_juliaProgram, GLKVertexAttribPosition, "position");
    
    [[ShaderHelper shaderHelper] linkProgram:_mandelbrotProgram];
    [[ShaderHelper shaderHelper] linkProgram:_juliaProgram];
    
    _mandelbrotUniforms[UNIFORM_SCREEN_TO_COMPLEX_PLANE_TRANSFORM] = glGetUniformLocation(_mandelbrotProgram, "screenToComplexPlaneTransform");
    _mandelbrotUniforms[UNIFORM_TIME] = glGetUniformLocation(_mandelbrotProgram, "time");
    _mandelbrotUniforms[UNIFORM_LIMIT] = glGetUniformLocation(_mandelbrotProgram, "limit");
    
    _juliaUniforms[UNIFORM_SCREEN_TO_COMPLEX_PLANE_TRANSFORM] = glGetUniformLocation(_juliaProgram, "screenToComplexPlaneTransform");
    _juliaUniforms[UNIFORM_TIME] = glGetUniformLocation(_juliaProgram, "time");
    _juliaUniforms[UNIFORM_JULIA_SEED] = glGetUniformLocation(_juliaProgram, "juliaSeed");
    _juliaUniforms[UNIFORM_LIMIT] = glGetUniformLocation(_juliaProgram, "limit");
}


- (IBAction)maxIterationsSliderValueChanged:(UISlider*)slider {
    _limit = (int)slider.value;
    [self refreshMaxIterations];
}

- (void)toggleSettingsPanel {
    if (_settingsPanelHiddenConstraint.active) {
        _settingsPanelHiddenConstraint.active = NO;
        _settingsPanelVisibleConstraint.active = YES;
    } else {
        _settingsPanelVisibleConstraint.active = NO;
        _settingsPanelHiddenConstraint.active = YES;
    }
}

- (IBAction)modeSegmentedControlValueChanged:(id)sender {
    [self refreshSettingsPanel];
}

- (IBAction)interactionSegmentedControlValueChanged:(id)sender {
    [self refreshSettingsPanel];
}

- (void)refreshSettingsPanel {
    _interactionSegmentedControl.enabled = ![self isDrawingMandelbrotSet];
}

@end
