@import Foundation;

@interface DateRange : NSObject
@property (nonatomic, strong) NSDate *start;
@property (nonatomic, strong) NSDate *end;

+ (instancetype)dateRangeWithStart:(NSDate *)start end:(NSDate *)end;
@end
