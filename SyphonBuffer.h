#ifndef _SYPHON_BUFFER_H_
#define _SYPHON_BUFFER_H_
#import <Syphon/Syphon.h>
@interface SyphonBufferController : NSObject
-(id)init;
-(void)onServerNotification:(NSNotification *)aNotification;
-(void)run;
-(void)createClientForServer:(NSDictionary *)serverDescription;
@end
#endif

