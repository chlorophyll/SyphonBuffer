#import "LineReader.h"
#define MAX_READ 512

@interface LineReader() <NSStreamDelegate>
@property (nonatomic) NSStringEncoding encoding;
@property (strong, nonatomic) NSString *data;
@property (strong, nonatomic) void (^callback)(NSString *line, NSError *error);
@end

@implementation LineReader
@synthesize encoding = _encoding;
@synthesize data = _data;
@synthesize callback = _callback;

uint8_t buf[MAX_READ];

-(void)process:(NSString *)path
{
    if (!path) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        self.callback(nil, error);
        return;
    }

    NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath:path];
    if (!stream) {
        self.callback(nil, [stream streamError]);
        return;
    }




    [stream setDelegate:self];
    [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [stream open];

    if ([stream streamStatus] == NSStreamStatusError) {
        self.callback(nil, [stream streamError]);
        return;
    }
}

- (void)readDataFromStream:(NSInputStream *)stream
{
    size_t len = [stream read:buf maxLength:MAX_READ];

    if (!len) {
        return;
    }

    NSString *str = [[NSString alloc] initWithBytes:buf length:len encoding:self.encoding];

    if (self.data) {
        self.data = [self.data stringByAppendingString:str];
    } else {
         self.data = str;
    }

    NSArray *lines = [self.data componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];

    NSString *prevLine = nil;

    for (NSString *line in lines) {
        if (prevLine) {
            self.callback(prevLine, nil);
        }
        prevLine = line;
    }

    self.data = prevLine;
}

- (void)closeStream:(NSStream *)theStream
{
    [theStream close];
    [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}


- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    if (streamEvent & NSStreamEventErrorOccurred) {
        self.callback(nil, [theStream streamError]);
        return;
    }
    if (streamEvent & NSStreamEventHasBytesAvailable) {
        [self readDataFromStream:((NSInputStream *)theStream)];
    }
    if (streamEvent & NSStreamEventEndEncountered) {
        [self closeStream:theStream];
        // Treat anything left in stringBuffer as the remaining line.
        if (self.data) {
            self.callback(self.data, nil);
            self.data = nil;
        }
        self.callback = nil;
    }
}

-(void)readLinesFromPath:(NSString *)path withEncoding:(NSStringEncoding)fileEncoding usingBlock:(void (^)(NSString *line, NSError *error))block
{
    self.encoding = fileEncoding;
    self.callback = block;
    [self process:path];
}
@end
