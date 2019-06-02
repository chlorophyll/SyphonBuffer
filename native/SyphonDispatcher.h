#ifndef _SYPHON_BUFFER_H_
#define _SYPHON_BUFFER_H_
#import <Syphon/Syphon.h>

@class LineReader;

@interface SyphonDispatcher : NSObject <NSStreamDelegate>
@property (retain) LineReader *commandReader;
-(id)init;
-(void)onServerNotification:(NSNotification *)aNotification;
-(void)run;
-(void)createClientForServer:(NSDictionary *)serverDescription;
-(void)onCommand:(NSString *)command withData:(id)data;
-(NSDictionary *)jsonForServer:(NSDictionary *)serverDescription;
-(void)sendCommand:(NSString *)command withData:(id)data;
@end
#endif

