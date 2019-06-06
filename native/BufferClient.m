#include "BufferClient.h"
#include "SyphonDispatcher.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <OpenGL/gl.h>
#define NUM_PBOS 3
#define MAX_FILENAME 24
#define MAX_WIDTH 2048
#define MAX_SIZE (MAX_WIDTH * MAX_WIDTH * 4)

void _logError(NSString *str) {
    GLenum err;
    while ((err = glGetError()) != 0) {
        NSLog(@"err %4x: %@", err, str);
    }
}

#define logError(v)

@implementation BufferClient {
    SyphonClient* syClient;
    GLuint tex;
    GLuint fbo;
    GLuint pbos[NUM_PBOS];

    uint8_t *pixels;

    BOOL initialized;
    int currentFrame;
    NSTimeInterval fpsStart;
    NSUInteger fpsCount;
    SyphonDispatcher *dispatcher;
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
    if (buffer == NULL) {
        return;
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
        0.0, 0.0,
        width, 0.0,
        width, height,
        0.0, height,
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

-(void)cleanup {
    if (syClient != nil) {
        [syClient stop];
    }
    if (pixels != NULL) {
        munmap(pixels, MAX_SIZE);
        pixels = NULL;
    }

    if (initialized) {
        glDeleteTextures(1, &tex);
        glDeleteFramebuffers(1, &fbo);
        glDeleteBuffers(NUM_PBOS, pbos);
    }

}

-(id)initWithServer:(NSDictionary *)serverDescription context:(NSOpenGLContext *)context andDispatcher:(SyphonDispatcher *)d {
    id instance = [super init];
    if (instance == nil) {
        return nil;
    }
    currentFrame = 0;

    dispatcher = d;

    [context makeCurrentContext];
    fpsStart = [NSDate timeIntervalSinceReferenceDate];
    fpsCount = 0;

    NSArray *parts = [serverDescription[SyphonServerDescriptionUUIDKey] componentsSeparatedByString:@"."];

    NSString *last = [parts lastObject];

    NSString *uuid = [last stringByReplacingOccurrencesOfString:@"-" withString:@""];

    NSString *truncated = [uuid substringFromIndex:([uuid length]-MAX_FILENAME)];

    const char *uuidStr = [truncated UTF8String];

    int fd = shm_open(uuidStr, O_RDWR, 0600);

    if (fd < 0) {
        return nil;
    }

    pixels = mmap(NULL, MAX_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

    shm_unlink(uuidStr);

    syClient = [[SyphonClient alloc]
                initWithServerDescription:serverDescription
                context:[context CGLContextObj]
                options:nil newFrameHandler:^(SyphonClient *client)
    {
        SyphonImage *image = [client newFrameImage];
        [context makeCurrentContext];
        if (!initialized) {
            [self initBuffersForSize:image.textureSize];
        }
        size_t size = 4 * image.textureSize.width * image.textureSize.height;
        [self copyImage:image toByteBuffer:pixels];

        NSDictionary *data = @{
            @"server": [dispatcher jsonForServer:serverDescription],
             @"width": [NSNumber numberWithInt:image.textureSize.width],
            @"height": [NSNumber numberWithInt:image.textureSize.height],
        };
        [dispatcher sendCommand:@"frame" withData:data];
    }];

    return instance;
}
@end
