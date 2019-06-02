#import <Foundation/Foundation.h>
#import <Syphon/Syphon.h>

@class SyphonDispatcher;

@interface BufferClient : NSObject
- (void)cleanup;
- (void)initBuffersForSize:(NSSize)size;
- (void)copyImage:(SyphonImage *)image toByteBuffer:(uint8_t *)buffer;
- (id)initWithServer:(NSDictionary *)serverDescription context:(NSOpenGLContext *)context andDispatcher:(SyphonDispatcher *)dispatcher;
@end
