#ifndef _SYPHON_BUFFER_H_
#define _SYPHON_BUFFER_H_
#import <Syphon/Syphon.h>

@class LineReader;

@interface SyphonBufferController : NSObject <NSStreamDelegate>
@property (retain) LineReader *commandReader;
-(id)init;
-(void)onServerNotification:(NSNotification *)aNotification;
-(void)run;
-(void)createClientForServer:(NSDictionary *)serverDescription;
@end
#endif

