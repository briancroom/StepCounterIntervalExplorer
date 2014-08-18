@import CoreMotion;
#import "ViewController.h"
#import "DateRange.h"

typedef NS_ENUM(NSInteger, DateRangeOption) {
    DateRangeOptionToday,
    DateRangeOptionYesterday,
    DateRangeOptionPastWeek,
};

typedef NS_ENUM(NSInteger, TimeIntervalOption) {
    TimeIntervalOptionWholeRange,
    TimeIntervalOptionOneHour,
    TimeIntervalOptionFifteenMinutes,
    TimeIntervalOptionFiveMinutes,
    TimeIntervalOptionOneMinute,
    TimeIntervalOptionCount
};

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *dateRangeControl;
@property (nonatomic) CMStepCounter *stepCounter;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (![CMStepCounter isStepCountingAvailable]) {
        [[[UIAlertView alloc] initWithTitle:@"Sorry" message:@"This demo only works on devices with an M7 chip" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil] show];
    }

    self.stepCounter = [[CMStepCounter alloc] init];

    self.dateRangeControl.selectedSegmentIndex = 0;
    [self performTestsWithDateRangeOption:self.dateRangeControl.selectedSegmentIndex];
}

- (void)performTestsWithDateRangeOption:(DateRangeOption)dateRangeOption {
    self.dateRangeControl.enabled = NO;
    [self resetLog];
    [self logLine:[NSString stringWithFormat:@"Running tests with time period: %@", [self dateRangeStringForOption:dateRangeOption]]];
    [self performTestWithDateRange:[self dateRangeForOption:dateRangeOption] timeIntervalOption:TimeIntervalOptionWholeRange highestStepCount:0];
}

- (void)performTestWithDateRange:(DateRange *)dateRange timeIntervalOption:(TimeIntervalOption)timeIntervalOption highestStepCount:(NSUInteger)highestStepCount {
    NSTimeInterval interval = [self timeIntervalForOption:timeIntervalOption];
    [self countStepsFromDate:dateRange.start toDate:dateRange.end interval:interval handler:^(NSUInteger stepCount) {
        NSString *lostStepsString = stepCount < highestStepCount ? [NSString stringWithFormat:@" (lost %lu)", (unsigned long)(highestStepCount-stepCount)] : @"";
        [self logLine:[NSString stringWithFormat:@"Interval: %@. Steps: %lu%@", [self timeIntervalStringForOption:timeIntervalOption], (unsigned long)stepCount, lostStepsString]];

        if (timeIntervalOption+1 < TimeIntervalOptionCount) {
            [self performTestWithDateRange:dateRange timeIntervalOption:timeIntervalOption+1 highestStepCount:MAX(highestStepCount, stepCount)];
        }
        else {
            [self logLine:@"Done!"];
            self.dateRangeControl.enabled = YES;
        }
    }];
}

#pragma mark - Log Management

- (void)resetLog {
    NSLog(@"\n-------------------------\n");
    self.logTextView.text = nil;
}

- (void)logLine:(NSString *)line {
    NSLog(@"%@", line);
    self.logTextView.text = [self.logTextView.text stringByAppendingFormat:@"%@\n", line];
}

#pragma mark - Step Counting
// Algorithm inspired by the MapMyFitness MMDK: https://www.mapmyapi.com/sdk
- (void)countStepsFromDate:(NSDate *)startDate toDate:(NSDate *)endDate interval:(NSTimeInterval)interval handler:(void (^)(NSUInteger stepCount))handler {
    NSMutableArray *steps = [[NSMutableArray alloc] init];

    dispatch_group_t group = dispatch_group_create();
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:1];

    NSDate *segmentStartDate = startDate, *segmentEndDate;
    do {
        segmentEndDate = [[segmentStartDate dateByAddingTimeInterval:interval] earlierDate:endDate];

        dispatch_group_enter(group);
        [self.stepCounter queryStepCountStartingFrom:segmentStartDate to:segmentEndDate toQueue:queue withHandler:^(NSInteger numberOfSteps, NSError *error) {
            if (error) {
                NSLog(@"Error: %@", error);
            }

            [steps addObject:@(numberOfSteps)];
            dispatch_group_leave(group);
        }];

        segmentStartDate = segmentEndDate;
    } while ([endDate compare:segmentEndDate] == NSOrderedDescending);

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSUInteger totalStepCount = [[steps valueForKeyPath:@"@sum.self"] unsignedIntegerValue];
        handler(totalStepCount);
    });
}

#pragma mark - Actions

- (IBAction)dateRangeChanged:(id)sender {
    [self performTestsWithDateRangeOption:self.dateRangeControl.selectedSegmentIndex];
}

#pragma mark - Helpers

- (NSTimeInterval)timeIntervalForOption:(TimeIntervalOption)option {
    switch (option) {
        case TimeIntervalOptionOneHour:
            return 60*60;
        case TimeIntervalOptionFifteenMinutes:
            return 60*15;
        case TimeIntervalOptionFiveMinutes:
            return 60*5;
        case TimeIntervalOptionOneMinute:
            return 60;
        default:
            return 60*60*24*8;
    }
}

- (NSString *)timeIntervalStringForOption:(TimeIntervalOption)option {
    switch (option) {
        case TimeIntervalOptionOneHour:
            return @"One hour";
        case TimeIntervalOptionFifteenMinutes:
        case TimeIntervalOptionFiveMinutes:
        case TimeIntervalOptionOneMinute: {
            NSInteger minutes = (NSInteger)([self timeIntervalForOption:option]/60);
            return [NSString stringWithFormat:@"%ld minute%@", minutes, minutes==1 ? @"" : @"s"];
        }
        default:
            return @"Entire range";
    }
}

- (NSString *)dateRangeStringForOption:(DateRangeOption)option {
    switch (option) {
        case DateRangeOptionToday:
            return @"Today";
        case DateRangeOptionYesterday:
            return @"Yesterday";
        default:
            return @"Last Week";
    }
}

- (DateRange *)dateRangeForOption:(DateRangeOption)option {
    switch (option) {
        case DateRangeOptionToday:
            return [DateRange dateRangeWithStart:[self beginningOfDaysAgo:0] end:[NSDate date]];
        case DateRangeOptionYesterday:
            return [DateRange dateRangeWithStart:[self beginningOfDaysAgo:1] end:[self endOfDaysAgo:1]];
        default:
            return [DateRange dateRangeWithStart:[NSDate dateWithTimeIntervalSinceNow:-60*60*24*7] end:[NSDate date]];
    }
}

- (NSDate *)beginningOfDaysAgo:(NSInteger)daysAgo {
    NSDateComponents *daysAgoComponents = [[NSDateComponents alloc] init];
    daysAgoComponents.day = -daysAgo;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [calendar dateByAddingComponents:daysAgoComponents toDate:[NSDate date] options:0];

    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    return [calendar dateFromComponents:components];
}

- (NSDate *)endOfDaysAgo:(NSInteger)daysAgo {
    NSDateComponents *daysAgoComponents = [[NSDateComponents alloc] init];
    daysAgoComponents.day = -daysAgo;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *date = [calendar dateByAddingComponents:daysAgoComponents toDate:[NSDate date] options:0];

    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    components.hour = 23;
    components.minute = 59;
    components.second = 59;
    return [calendar dateFromComponents:components];
}

@end
