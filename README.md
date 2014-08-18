## Step Counter Interval Explorer

On iOS 7 devices with an M7 chip, Apple provides the CMStepCounter class for retrieving the number of steps that the device has recorded over a given period of time. While working with this API, I began to see clues that it may provide slightly inconsistent results depending on the size of the time interval used when querying step counts. In particular, the number of steps returned when querying over a long time period is a little bit higher than when repeatedly querying the same period but with intervals of 1 minute per query.

This utility app assists in understanding the extent of this inconsistency by making it easy to compare the number steps returned by CMStepCounter when querying over different date ranges with varying intervals.

NOTE: This app can only be used on devices with an M7 chip running iOS 7.0+!