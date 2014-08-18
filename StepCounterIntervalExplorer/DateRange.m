#import "DateRange.h"

@implementation DateRange

+ (instancetype)dateRangeWithStart:(NSDate *)start end:(NSDate *)end {
    DateRange *range = [[DateRange alloc] init];
    range.start = start;
    range.end = end;
    return range;
}

@end
