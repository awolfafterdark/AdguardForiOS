// Shared by the app and extensions. Profiles supply candidates only; iOS decides
// which containers the running process may access through FileManager.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static inline NSURL *AEContainingAppURL(NSURL *bundleURL) {
    NSURL *url = bundleURL;
    while (url.path.length > 1) {
        if ([url.pathExtension isEqualToString:@"app"]) return url;
        url = url.URLByDeletingLastPathComponent;
    }
    return bundleURL;
}

static inline NSArray<NSString *> *AEProvisionedAppGroups(NSURL *appURL) {
    NSURL *profileURL = [appURL URLByAppendingPathComponent:@"embedded.mobileprovision"];
    NSNumber *size = nil;
    if (![profileURL getResourceValue:&size forKey:NSURLFileSizeKey error:nil]
        || size.unsignedLongLongValue > 16 * 1024 * 1024) return @[];
    NSData *profile = [NSData dataWithContentsOfURL:profileURL];
    if (!profile) return @[];
    NSData *open = [@"<?xml" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *close = [@"</plist>" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange start = [profile rangeOfData:open options:0 range:NSMakeRange(0, profile.length)];
    if (start.location == NSNotFound) return @[];
    NSRange end = [profile rangeOfData:close options:0
                               range:NSMakeRange(start.location, profile.length - start.location)];
    if (end.location == NSNotFound) return @[];
    NSData *xml = [profile subdataWithRange:NSMakeRange(start.location, NSMaxRange(end) - start.location)];
    id plist = [NSPropertyListSerialization propertyListWithData:xml options:NSPropertyListImmutable
                                                        format:NULL error:nil];
    if (![plist isKindOfClass:NSDictionary.class]) return @[];
    id entitlements = plist[@"Entitlements"];
    if (![entitlements isKindOfClass:NSDictionary.class]) return @[];
    id groups = entitlements[@"com.apple.security.application-groups"];
    if (![groups isKindOfClass:NSArray.class]) return @[];
    NSMutableSet<NSString *> *valid = [NSMutableSet set];
    for (id group in groups) {
        if ([group isKindOfClass:NSString.class] && [group hasPrefix:@"group."]
            && [group length] > 6 && [group length] <= 255) [valid addObject:group];
    }
    // Profile order is not stable between signing tools. Every process must
    // choose the same candidate from the containing app's profile.
    return [[valid allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

static inline NSURL * _Nullable AEResolveAppGroup(
    NSString *configuredGroup, NSURL *bundleURL,
    NSURL * _Nullable (^containerForGroup)(NSString *group),
    NSString * _Nullable __autoreleasing *selectedGroup) {
    if (selectedGroup) *selectedGroup = nil;
    NSMutableOrderedSet<NSString *> *groups = [NSMutableOrderedSet orderedSet];
    if (configuredGroup.length) [groups addObject:configuredGroup];
    [groups addObjectsFromArray:AEProvisionedAppGroups(AEContainingAppURL(bundleURL))];
    for (NSString *group in groups) {
        NSURL *url = containerForGroup(group);
        if (url) {
            if (selectedGroup) *selectedGroup = group;
            return url;
        }
    }
    return nil;
}

NS_ASSUME_NONNULL_END
