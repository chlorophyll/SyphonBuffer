#import <Cocoa/Cocoa.h>
#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl.h>
#include "SyphonDispatcher.h"
#include "BufferClient.h"
#include "LineReader.h"

@implementation SyphonDispatcher

NSOutputStream *outStream;
NSOpenGLContext *context;
NSMutableDictionary *clients;


-(id)init {
    id instance = [super init];
    if (instance) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onServerNotification:) name:nil object:[SyphonServerDirectory sharedDirectory]];
        NSOpenGLPixelFormatAttribute attributes[] = {
            NSOpenGLPFANoRecovery,
            NSOpenGLPFAAccelerated,
            NSOpenGLPFADepthSize, 24,
            (NSOpenGLPixelFormatAttribute) 0
        };
        NSOpenGLPixelFormat *pixFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
        context = [[NSOpenGLContext alloc] initWithFormat:pixFormat shareContext:nil];
        clients = [[NSMutableDictionary alloc] init];
    }
    return instance;
}

-(void)createClientForServer:(NSDictionary *)serverDescription {
    NSString *uuid = serverDescription[SyphonServerDescriptionUUIDKey];

    BufferClient *cl = [[BufferClient alloc] initWithServer:serverDescription context:context andDispatcher:self];

    if (cl == nil) {
        [self sendCommand:@"error" withData:@{}];
        return;
    }

    [clients setObject:cl forKey:uuid];
}

-(NSDictionary *)jsonForServer:(NSDictionary *)serverDescription {
    return @{
        @"uuid": serverDescription[SyphonServerDescriptionUUIDKey],
        @"name": serverDescription[SyphonServerDescriptionNameKey],
     @"appName": serverDescription[SyphonServerDescriptionAppNameKey],
    };
}

-(void)onServerNotification:(NSNotification *)aNotification {

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


        [serverData addObject:[self jsonForServer:serverDescription]];
    }

    [self sendCommand:@"updateServers" withData:serverData];
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

-(void)onCommand:(NSString *)command withData:(id)data
{
    if ([command isEqualToString:@"createClient"]) {
        NSDictionary *d = (NSDictionary *)data;
        NSString *serverUuid = d[@"uuid"];
        NSDictionary *serverDescription = nil;
        NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
        for (NSDictionary *server in servers) {
            if ([server[SyphonServerDescriptionUUIDKey] isEqualToString:serverUuid]) {
                serverDescription = server;
                break;
            }
        }

        if (serverDescription != nil) {
            [self createClientForServer:serverDescription];
            [self sendCommand:@"clientCreated" withData:[self jsonForServer:serverDescription]];
        }
    }
}

-(void)onLine:(NSString *)line orError:(NSError *)error
{
    NSData *d = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];

    NSString *command = dictionary[@"command"];
    id data = dictionary[@"data"];

    [self onCommand:command withData:data];
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
        SyphonDispatcher *obj = [[SyphonDispatcher alloc] init];
        [obj run];
    }
    return 0;
}
