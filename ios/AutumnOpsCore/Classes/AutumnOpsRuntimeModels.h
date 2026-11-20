#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutumnOpsRuntimeMemory : NSObject
@property (nonatomic) NSInteger used;
@property (nonatomic) NSInteger committed;
@property (nonatomic) NSInteger max;
@property (nonatomic) NSInteger initBytes;
@property (nonatomic, readonly) double usedRatio;
+ (nullable instancetype)tryParse:(nullable id)raw;
@end

@interface AutumnOpsRuntimeSystem : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, copy) NSString *hostname;
@property (nonatomic, copy) NSString *osName;
@property (nonatomic, copy) NSString *osArch;
@property (nonatomic, copy) NSString *osVersion;
@property (nonatomic) NSInteger availableProcessors;
@property (nonatomic, strong, nullable) NSNumber *systemLoadAverage;
@property (nonatomic, strong, nullable) NSNumber *processCpuLoad;
@property (nonatomic, strong, nullable) NSNumber *systemCpuLoad;
@property (nonatomic, strong, nullable) NSNumber *physicalTotalBytes;
@property (nonatomic, strong, nullable) NSNumber *physicalUsedBytes;
@property (nonatomic, strong, nullable) NSNumber *physicalFreeBytes;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeJvm : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic) NSInteger uptimeMs;
@property (nonatomic, copy) NSString *javaVersion;
@property (nonatomic, copy) NSString *vmName;
@property (nonatomic, strong, nullable) AutumnOpsRuntimeMemory *heap;
@property (nonatomic, strong, nullable) AutumnOpsRuntimeMemory *nonHeap;
@property (nonatomic) NSInteger threadLive;
@property (nonatomic) NSInteger threadDaemon;
@property (nonatomic) NSInteger threadPeak;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeDiskVolume : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic) NSInteger totalBytes;
@property (nonatomic) NSInteger usableBytes;
@property (nonatomic) NSInteger usedBytes;
@property (nonatomic, readonly) double usedRatio;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeDisk : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, copy) NSArray<AutumnOpsRuntimeDiskVolume *> *volumes;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeDatabase : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, copy) NSString *poolType;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy) NSString *productVersion;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong, nullable) NSNumber *activeCount;
@property (nonatomic, strong, nullable) NSNumber *poolingCount;
@property (nonatomic, strong, nullable) NSNumber *waitThreadCount;
@property (nonatomic, strong, nullable) NSNumber *maxActive;
@property (nonatomic, strong, nullable) NSNumber *minIdle;
@property (nonatomic, strong, nullable) NSNumber *tableCount;
@property (nonatomic, copy, nullable) NSString *tableCountError;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeBlackHit : NSObject
@property (nonatomic, copy) NSString *ip;
@property (nonatomic) NSInteger today;
@property (nonatomic) NSInteger count;
@property (nonatomic, copy, nullable) NSString *tag;
@property (nonatomic, strong, nullable) NSNumber *available;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeFirewall : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic) BOOL adminIpEnable;
@property (nonatomic) NSInteger adminIpCount;
@property (nonatomic) NSInteger ipWhiteCount;
@property (nonatomic) NSInteger ipBlackCount;
@property (nonatomic) NSInteger firewallCount;
@property (nonatomic) BOOL shieldAttack;
@property (nonatomic) BOOL shieldPrint;
@property (nonatomic) BOOL shieldEnabled;
@property (nonatomic) NSInteger shieldAllowedIpCount;
@property (nonatomic, copy) NSArray<NSString *> *shieldAllowedIpSample;
@property (nonatomic, copy) NSArray<AutumnOpsRuntimeBlackHit *> *blackTopToday;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeTraffic : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic) NSInteger requestTotal;
@property (nonatomic) double approxQps;
@property (nonatomic, copy, nullable) NSString *visitLogDay;
@property (nonatomic, strong, nullable) NSNumber *pageViewToday;
@property (nonatomic, strong, nullable) NSNumber *uniqueVisitorToday;
@property (nonatomic, strong, nullable) NSNumber *visitLogRowsToday;
@property (nonatomic, copy, nullable) NSString *visitLogError;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeRedis : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, copy, nullable) NSString *version;
@property (nonatomic, copy, nullable) NSString *connectedClients;
@property (nonatomic, copy, nullable) NSString *usedMemory;
@property (nonatomic, strong, nullable) NSNumber *keyCount;
@property (nonatomic, strong, nullable) NSNumber *usedMemoryBytes;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimePathItem : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *path;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimePaths : NSObject
@property (nonatomic) BOOL available;
@property (nonatomic, copy, nullable) NSString *error;
@property (nonatomic, copy) NSArray<AutumnOpsRuntimePathItem *> *items;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

@interface AutumnOpsRuntimeSnapshot : NSObject
@property (nonatomic) NSInteger collectedAt;
@property (nonatomic, strong) AutumnOpsRuntimeSystem *system;
@property (nonatomic, strong) AutumnOpsRuntimeJvm *jvm;
@property (nonatomic, strong) AutumnOpsRuntimeDisk *disk;
@property (nonatomic, strong) AutumnOpsRuntimeDatabase *database;
@property (nonatomic, strong) AutumnOpsRuntimeFirewall *firewall;
@property (nonatomic, strong) AutumnOpsRuntimeTraffic *traffic;
@property (nonatomic, strong) AutumnOpsRuntimeRedis *redis;
@property (nonatomic, strong) AutumnOpsRuntimePaths *paths;
@property (nonatomic) BOOL exceptionsSupported;
+ (instancetype)fromJSON:(NSDictionary *)json;
@end

NS_ASSUME_NONNULL_END
