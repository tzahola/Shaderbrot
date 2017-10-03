//
//  ViewController.m
//  MandelbrotShader
//
//  Created by Tamás Zahola on 01/01/14.
//  Copyright (c) 2014 Tamás Zahola. All rights reserved.
//

#import "ViewController.h"
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

@interface ViewController ()
@property (nonatomic, readonly) GLKView* glView;
@property (nonatomic) BOOL settingsPanelHidden;
@end

@implementation ViewController {
    int _mandelbrotUniforms[NUM_UNIFORMS];
    GLuint _mandelbrotProgram;
    
    int _juliaUniforms[NUM_UNIFORMS];
    GLuint _juliaProgram;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    EAGLContext * _context;
    
    GLKMatrix4 _viewTransform;
    GLKVector2 _juliaSeed;
    
    CGPoint _previousTranslation;
    UIPanGestureRecognizer * _panGestureRecognizer;
    
    CGFloat _previousScale;
    UIPinchGestureRecognizer * _pinchGestureRecognizer;
    
    CGFloat _previousRotation;
    UIRotationGestureRecognizer * _rotationGestureRecognizer;
    
    UITapGestureRecognizer * _doubleTapGestureRecognizer;
    
    uint _limit;
    float _time;
    
    __weak IBOutlet UILabel *_maxIterationsLabel;
    __weak IBOutlet UISlider *_maxIterationsSlider;
    __weak IBOutlet UISegmentedControl *_modeSegmentedControl;
    __weak IBOutlet UISegmentedControl *_interactionSegmentedControl;
    
    __weak IBOutlet UIView* _gestureAreaView;
    __weak IBOutlet UIView* _settingsPanelView;
    __weak IBOutlet NSLayoutConstraint* _settingsPanelHiddenConstraint;
    __weak IBOutlet NSLayoutConstraint* _settingsPanelVisibleConstraint;
}

- (GLKView*)glView { return (GLKView*)self.view; }

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _settingsPanelHidden = YES;
    
    self.delegate = self;
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    NSAssert(_context != nil, @"Failed to create ES context");
    
    self.glView.context = _context;
    self.glView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    self.glView.contentScaleFactor = UIScreen.mainScreen.nativeScale;
    
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
    [self setSettingsPanelHidden:!self.settingsPanelHidden animated:YES];
}

- (void)setSettingsPanelHidden:(BOOL)settingsPanelHidden {
    [self setSettingsPanelHidden:settingsPanelHidden animated:NO];
}

- (void)setSettingsPanelHidden:(BOOL)settingsPanelHidden animated:(BOOL)animated {
    if (_settingsPanelHidden == settingsPanelHidden) return;
    
    _settingsPanelHidden = settingsPanelHidden;
    [self.view setNeedsUpdateConstraints];
    
    if (animated) {
        if (!_settingsPanelHidden) {
            _settingsPanelView.hidden = NO;
        }
        [UIView animateWithDuration:0.3 animations:^{
            [self.view updateConstraintsIfNeeded];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            if (!finished) return;
            
            if (_settingsPanelHidden) {
                _settingsPanelView.hidden = YES;
            }
        }];
    }
}

- (void)updateViewConstraints {
    [super updateViewConstraints];
    _settingsPanelHiddenConstraint.active = _settingsPanelHidden;
    _settingsPanelVisibleConstraint.active = !_settingsPanelHidden;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self.view setNeedsUpdateConstraints];
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
        
        GLKVector4 windowLocation = GLKVector4Make(rotationCenter.x * self.glView.contentScaleFactor,
                                                   self.glView.drawableHeight - rotationCenter.y * self.glView.contentScaleFactor, 0, 1);
        GLKVector4 complexPlaneLocation = GLKMatrix4MultiplyVector4(GLKMatrix4Invert([self complexPlaneToWindowTransform], NULL), windowLocation);
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(complexPlaneLocation.x, complexPlaneLocation.y, complexPlaneLocation.z));
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeRotation(deltaRotation, 0, 0, -1));
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(-complexPlaneLocation.x, -complexPlaneLocation.y, -complexPlaneLocation.z));
        
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
            } break;
                
            default:{
                deltaScale = scale / _previousScale;
            } break;
        }
        
        GLKVector4 windowLocation = GLKVector4Make(scaleCenter.x * self.glView.contentScaleFactor,
                                                   self.glView.drawableHeight - scaleCenter.y * self.glView.contentScaleFactor, 0, 1);
        GLKVector4 complexPlaneLocation = GLKMatrix4MultiplyVector4(GLKMatrix4Invert([self complexPlaneToWindowTransform], NULL), windowLocation);
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(complexPlaneLocation.x, complexPlaneLocation.y, complexPlaneLocation.z));
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeScale(deltaScale, deltaScale, 1));
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(-complexPlaneLocation.x, -complexPlaneLocation.y, -complexPlaneLocation.z));
        
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
    
    GLKVector4 windowTranslation = GLKVector4Make(delta.x * self.glView.contentScaleFactor, -delta.y * self.glView.contentScaleFactor, 0, 0);
    GLKVector4 complexPlaneTranslation = GLKMatrix4MultiplyVector4(GLKMatrix4Invert([self complexPlaneToWindowTransform], NULL), windowTranslation);
    if ([self isNavigatingFreely]) {
        _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(complexPlaneTranslation.x,
                                                                                      complexPlaneTranslation.y,
                                                                                      complexPlaneTranslation.z));
    } else {
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
    
    _viewTransform = GLKMatrix4MakeScale(0.5, 0.5, 1);
    _viewTransform = GLKMatrix4Multiply(_viewTransform, GLKMatrix4MakeTranslation(0.5, 0, 0));
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
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram([self isDrawingMandelbrotSet] ? _mandelbrotProgram : _juliaProgram);
    
    int const* uniforms = [self isDrawingMandelbrotSet] ? _mandelbrotUniforms : _juliaUniforms;
    
    glUniform1i(uniforms[UNIFORM_LIMIT], _limit);
    
    glUniformMatrix4fv(uniforms[UNIFORM_SCREEN_TO_COMPLEX_PLANE_TRANSFORM], 1, GL_FALSE, GLKMatrix4Invert([self complexPlaneToWindowTransform], NULL).m);
    glUniform1f(uniforms[UNIFORM_TIME], _time);
    if(![self isDrawingMandelbrotSet]) {
        glUniform2f(uniforms[UNIFORM_JULIA_SEED], _juliaSeed.x, _juliaSeed.y);
    }
    
    CGRect viewport = [self viewport];
    glViewport((int)viewport.origin.x, (int)viewport.origin.y, (int)viewport.size.width, (int)viewport.size.height);
    glBindVertexArray(_vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

- (GLKMatrix4)complexPlaneToWindowTransform {
    CGRect viewport = [self viewport];
    
    GLKMatrix4 viewportTransform = GLKMatrix4Identity;
    viewportTransform = GLKMatrix4Multiply(GLKMatrix4MakeTranslation(1, 1, 0), viewportTransform);
    viewportTransform = GLKMatrix4Multiply(GLKMatrix4MakeScale(viewport.size.width / 2.0, viewport.size.height / 2.0, 1), viewportTransform);
    viewportTransform = GLKMatrix4Multiply(GLKMatrix4MakeTranslation(viewport.origin.x, viewport.origin.y, 0), viewportTransform);
    
    CGFloat aspect = viewport.size.width / viewport.size.height;
    CGFloat top = 1;
    CGFloat bottom = -1;
    CGFloat left = -1 * aspect;
    CGFloat right = 1 * aspect;
    
    GLKMatrix4 projectionTransform = GLKMatrix4Identity;
    projectionTransform = GLKMatrix4Multiply(GLKMatrix4MakeTranslation(-left, -bottom, 0), projectionTransform);
    projectionTransform = GLKMatrix4Multiply(GLKMatrix4MakeScale(2.0 / (right - left), 2.0 / (top - bottom), 1), projectionTransform);
    projectionTransform = GLKMatrix4Multiply(GLKMatrix4MakeTranslation(-1, -1, 0), projectionTransform);
    
    GLKMatrix4 eyeToWindowTransform = GLKMatrix4Multiply(viewportTransform, projectionTransform);
    GLKMatrix4 complexPlaneToWindowTransform = GLKMatrix4Multiply(eyeToWindowTransform, _viewTransform);
    
    return complexPlaneToWindowTransform;
}

- (CGRect)viewport {
    CGSize presentationSize = (self.glView.layer.presentationLayer ?: self.glView.layer).bounds.size;
    CGFloat presentationScale = fmin(self.glView.drawableWidth / presentationSize.width,
                                     self.glView.drawableHeight / presentationSize.height);
    CGSize viewportSize = CGSizeMake(presentationSize.width * presentationScale, presentationSize.height * presentationScale);
    return CGRectMake((self.glView.drawableWidth - viewportSize.width) / 2, (self.glView.drawableHeight - viewportSize.height) / 2,
                      viewportSize.width, viewportSize.height);
}

- (void)glkViewControllerUpdate:(GLKViewController *)controller {
#if TARGET_OS_SIMULATOR
    return;
#endif
    _time = controller.timeSinceFirstResume;
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
