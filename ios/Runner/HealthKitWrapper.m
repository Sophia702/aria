#import "HealthKitWrapper.h"

@implementation HealthKitWrapper

+ (void)requestAuthorizationWithStore:(HKHealthStore *)store
                            readTypes:(NSSet<HKObjectType *> *)readTypes
                           completion:(void (^)(BOOL success))completion {
    @try {
        [store requestAuthorizationToShareTypes:nil
                                      readTypes:readTypes
                                     completion:^(BOOL success, NSError *error) {
            completion(success);
        }];
    } @catch (NSException *exception) {
        NSLog(@"[aria] HealthKit requestAuthorization exception: %@", exception.reason);
        completion(NO);
    }
}

+ (void)executeQuery:(HKQuery *)query
           withStore:(HKHealthStore *)store
          onComplete:(void (^)(NSArray<HKSample *> * _Nullable samples))completion {
    @try {
        [store executeQuery:query];
    } @catch (NSException *exception) {
        NSLog(@"[aria] HealthKit executeQuery exception: %@", exception.reason);
        completion(nil);
    }
}

@end
