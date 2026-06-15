#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HealthKitWrapper : NSObject

+ (void)requestAuthorizationWithStore:(HKHealthStore *)store
                            readTypes:(NSSet<HKObjectType *> *)readTypes
                           completion:(void (^)(BOOL success))completion;

+ (void)executeQuery:(HKQuery *)query
           withStore:(HKHealthStore *)store
          onComplete:(void (^)(NSArray<HKSample *> * _Nullable samples))completion;

@end

NS_ASSUME_NONNULL_END
