#import <Foundation/Foundation.h>

@interface LineReader : NSObject

-(void)readLinesFromPath:(NSString *)path withEncoding:(NSStringEncoding)fileEncoding usingBlock:(void (^)(NSString *line, NSError *error))block;

@end
