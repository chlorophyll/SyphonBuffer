#import <Cocoa/Cocoa.h>
#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl.h>
#include "SyphonBuffer.h"
#include "LineReader.h"

#define NUM_PBOS 3

void _logError(NSString *str) {
    GLenum err;
    while ((err = glGetError()) != 0) {
        NSLog(@"err %4x: %@", err, str);
    }
}

#define logError(v)


@implementation SyphonBufferController
SyphonClient* syClient;
GLuint tex;
GLuint fbo;
GLuint pbos[NUM_PBOS];
BOOL initialized = NO;
int currentFrame = 0;
NSTimeInterval fpsStart;
NSUInteger fpsCount;
NSOutputStream *outStream;


-(id)init {
    id instance = [super init];
    if (instance) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onServerNotification:) name:nil object:[SyphonServerDirectory sharedDirectory]];
    }
    return instance;
}

- (void)initBuffersForSize:(NSSize)size {
    if (initialized) {
        glDeleteTextures(1, &tex);
        glDeleteFramebuffers(1, &fbo);
        glDeleteBuffers(NUM_PBOS, pbos);
    }
    GLint prevFBO, prevReadFBO, prevDrawFBO;
    // Store previous state
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);
    logError(@"GL_FRAMEBUFFER_BINDING");

    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prevReadFBO);
    logError(@"GL_READ_FRAMEBUFFER_BINDING");

    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &prevDrawFBO);
    logError(@"GL_DRAW_FRAMEBUFFER_BINDING");
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    logError(@"glPushAttrib");



    GLsizei width = size.width;
    GLsizei height = size.height;
    NSLog(@"size: %lu", (size_t)(width*height*4));

    // gen texture
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
    logError(@"glEnable");


    glGenTextures(1, &tex);
    logError(@"glGenTextures");
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);
    logError(@"glBindTexture");

    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA8, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, NULL);

    // gen fbo
    glGenFramebuffers(1, &fbo);
    logError(@"glGenFramebuffers");

    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    logError(@"glBindFramebuffer");

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
    logError(@"glFramebufferTexture2D");

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"fbo error");
        return;
        // Deal with this error - you won't be able to draw into the FBO
    }

    // restore fbo state
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);

    logError(@"restore glBindTexture");


    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
    logError(@"restore glBindFramebuffer");

    glBindFramebuffer(GL_READ_FRAMEBUFFER, prevReadFBO);
    logError(@"restore glBindFramebuffer READ");

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prevDrawFBO);
    logError(@"restore glBindFramebuffer DRAW");




    // gen pbos
    // Save PBO state
    GLint prevPBO;
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &prevPBO);
    logError(@"glGetIntegerv PIXEL_PACK_BUFFER");

    glGenBuffers(NUM_PBOS, pbos);
    logError(@"glGenBuffers");


    for (int i = 0; i < NUM_PBOS; i++) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pbos[i]);
        logError(@"glBindBUffer");

        glBufferData(GL_PIXEL_PACK_BUFFER, width * height * 4, NULL, GL_DYNAMIC_READ);
        logError(@"glBufferData");

    }
    glBindBuffer(GL_PIXEL_PACK_BUFFER, prevPBO);
    glPopAttrib();

    currentFrame = 0;
    initialized = YES;
}

-(void)copyImage:(SyphonImage *)image toByteBuffer:(uint8_t *)buffer {
    GLint prevFBO, prevReadFBO, prevDrawFBO;

    // Store previous state
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFBO);
    logError(@"GL_FRAMEBUFFER_BINDING");

    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prevReadFBO);
    logError(@"GL_READ_FRAMEBUFFER_BINDING");

    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &prevDrawFBO);
    logError(@"GL_DRAW_FRAMEBUFFER_BINDING");
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    logError(@"glPushAttrib");

    GLuint copyPbo = pbos[currentFrame % NUM_PBOS];
    GLuint readPbo = pbos[(currentFrame + 1) % NUM_PBOS];

    GLsizei width = image.textureSize.width;
    GLsizei height = image.textureSize.height;
    GLsizei size = 4*width*height;

    if (currentFrame != 0) {
        glBindBuffer(GL_PIXEL_PACK_BUFFER, copyPbo);
        logError(@"bind copyPbo");
        uint8_t *src = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY);
        logError(@"mapBuffer");
        memcpy(buffer, src, size);
        glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        logError(@"unmapBuffer");
    }

    // Attach the FBO
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    logError(@"glBindFramebuffer");
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_ARB, tex, 0);
    logError(@"glFramebufferTexture2D");

    // Set up required state
    glViewport(0, 0,  width, height);
    logError(@"glViewport");
    glMatrixMode(GL_PROJECTION);
    logError(@"glMatrixMode");

    glPushMatrix();
    logError(@"glPushMatrix glProjection");

    glLoadIdentity();
    logError(@"glLoadIdentity");


    glOrtho(0.0, width,  0.0,  height, -1, 1);
    logError(@"glOrtho");

    glMatrixMode(GL_MODELVIEW);
    logError(@"GL_MODELVIEW");
    glPushMatrix();
    logError(@"glPushMatrix gl_modelview");

    glLoadIdentity();
    logError(@"glLoadIdentity");

    // Clear
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    // Bind the texture
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
    logError(@"glEnable");
    glActiveTexture(GL_TEXTURE0);
    logError(@"glActiveTexture");

    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, image.textureName);
    // Configure texturing as we want it
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

    glColor4f(1.0, 1.0, 1.0, 1.0);

    // Draw it
    // These coords flip the texture vertically because often you'll want to do that
    GLfloat texCoords[] =
    {
        0.0, height,
        width, height,
        width, 0.0,
        0.0, 0.0
    };

    GLfloat verts[] =
    {
        0.0, 0.0,
        width, 0.0,
        width, height,
        0.0, height
    };

    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords );
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts);
    glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );

    glBindBuffer(GL_PIXEL_PACK_BUFFER, readPbo);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, tex);

    // This is a minimal setup of pixel storage - if anything else might have touched it
    // be more explicit
    glPixelStorei(GL_PACK_ROW_LENGTH, width);

    // Start the download to PBO
    glGetTexImage(GL_TEXTURE_RECTANGLE_ARB, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, (GLvoid *)0);

    // restore state
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, prevFBO);
    logError(@"restore glBindFramebuffer");

    glBindFramebuffer(GL_READ_FRAMEBUFFER, prevReadFBO);
    logError(@"restore glBindFramebuffer READ");

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prevDrawFBO);
    logError(@"restore glBindFramebuffer DRAW");
    glPopAttrib();
    logError(@"glPopAttrib");

    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();

    glMatrixMode(GL_PROJECTION);
    glPopMatrix();


    currentFrame++;
}

-(void)createClientForServer:(NSDictionary *)serverDescription {
    NSOpenGLPixelFormatAttribute  attributes[] = {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADepthSize, 24,
        (NSOpenGLPixelFormatAttribute) 0
    };
    NSOpenGLPixelFormat *pixFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:pixFormat shareContext:nil];
    [context makeCurrentContext];
    fpsStart = [NSDate timeIntervalSinceReferenceDate];
    fpsCount = 0;

    syClient = [[SyphonClient alloc]
                initWithServerDescription:serverDescription
                context:[context CGLContextObj]
                options:nil newFrameHandler:^(SyphonClient *client)
    {
        fpsCount++;
        float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
        if (elapsed > 1.0)
        {
            float FPS = ceilf(fpsCount / elapsed);
            NSLog(@"FPS: %0.1f", FPS);
            fpsStart = [NSDate timeIntervalSinceReferenceDate];
            fpsCount = 0;
        }
        SyphonImage *image = [client newFrameImage];
        if (!initialized) {
            [self initBuffersForSize:image.textureSize];
        }
        size_t size = 4 * image.textureSize.width * image.textureSize.height;
        uint8_t pixels[size];
        [self copyImage:image toByteBuffer:pixels];
        if (elapsed > 1.0) {
            NSLog(@"first three bytes: %u %u %u", pixels[0], pixels[1], pixels[2]);
        }
    }];
}

-(void)onServerNotification:(NSNotification *)aNotification {
    NSLog(@"server notification %@", aNotification.name);

    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
    NSMutableArray *serverData = [NSMutableArray array];

    for (NSDictionary *serverDescription in servers) {
        //NSImage *icon = serverDescription[SyphonServerDescriptionIconKey];

        //NSString *iconEncoded = nil;

        //if (icon) {
        //    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:[icon TIFFRepresentation]];
        //    NSData *data = [imageRep representationUsingType:NSPNGFileType properties:@{
        //                         @"NSImageCompressionFactor": @"1.0"
        //    }];
        //    iconEncoded = [data base64EncodedStringWithOptions:0];
        //}


        [serverData addObject:@{
            @"uuid": serverDescription[SyphonServerDescriptionUUIDKey],
            @"name": serverDescription[SyphonServerDescriptionNameKey],
         @"appName": serverDescription[SyphonServerDescriptionAppNameKey],
        }];
    }

    [self sendCommand:@"updateServers" withData:serverData];
    //if ([servers count] == 1) {
    //    NSDictionary *serverDescription = [servers objectAtIndex:0];
    //    [self createClientForServer:serverDescription];
    //}
}

-(void)sendCommand:(NSString *)command withData:(id)data
{
    NSDictionary *dict = @{
        @"command": command,
        @"data": data,
    };

    uint8_t b = '\n';

    [NSJSONSerialization writeJSONObject:dict toStream:outStream options:0 error:nil];
    [outStream write:&b maxLength:1];
}

-(void)onCommand:(NSDictionary *)command
{
}

-(void)onLine:(NSString *)line orError:(NSError *)error
{
}

-(void)run {
    outStream = [NSOutputStream  outputStreamToFileAtPath:@"/dev/stdout" append:YES];
    [outStream setDelegate:self];
    [outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outStream open];

    self.commandReader = [[LineReader alloc] init];
    [self.commandReader readLinesFromPath:@"/dev/stdin" withEncoding:NSUTF8StringEncoding usingBlock:^(NSString *line, NSError *error) {
        [self onLine:line orError:error];
    }];
    [[NSRunLoop currentRunLoop] run];
}
@end


int main(int argc, char *argv[])
{
    @autoreleasepool {
        SyphonBufferController *obj = [[SyphonBufferController alloc] init];
        [obj run];
    }
    return 0;
}
