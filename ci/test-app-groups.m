#import "../AdguardExtension/SharedComponents/AEAppGroupResolver.h"
#include <stdlib.h>

static void Check(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static void WriteProfile(NSURL *app, id groups) {
    NSDictionary *plist = @{@"Entitlements": @{@"com.apple.security.application-groups": groups}};
    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:plist
        format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    // Exercise XML extraction from a binary envelope, including trailing data.
    NSMutableData *data = [NSMutableData dataWithBytes:"\060\202\000\000" length:4];
    [data appendData:xml];
    [data appendBytes:"\000\377\000" length:3];
    Check([data writeToURL:[app URLByAppendingPathComponent:@"embedded.mobileprovision"] atomically:YES], @"write fixture");
}

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
                                isDirectory:YES];
        NSURL *app = [root URLByAppendingPathComponent:@"AdguardPro.app" isDirectory:YES];
        NSURL *extension = [app URLByAppendingPathComponent:@"PlugIns/ProTunnel.appex" isDirectory:YES];
        Check([fm createDirectoryAtURL:extension withIntermediateDirectories:YES attributes:nil error:nil], @"create fixture");
        NSString *configured = @"group.com.adguard.AdguardPro";
        NSString *first = @"group.test.resigned.1";
        NSString *second = @"group.test.resigned.2";
        NSURL *shared = [root URLByAppendingPathComponent:@"shared" isDirectory:YES];
        NSURL *(^authorized)(NSString *) = ^NSURL *(NSString *group) {
            return [group isEqualToString:first] ? shared : nil;
        };
        NSString *selected = nil;

        // Regression: the requested upstream group is unavailable, but the
        // signer's group exists in both the host and extension's entitlements.
        WriteProfile(app, @[second, first, first, @42, @"invalid"]);
        Check([AEProvisionedAppGroups(app) isEqualToArray:@[first, second]], @"sort, validate and deduplicate candidates");
        Check([AEResolveAppGroup(configured, app, authorized, &selected) isEqual:shared]
              && [selected isEqual:first], @"resolve re-signed host");
        selected = nil;
        Check([AEResolveAppGroup(configured, extension, authorized, &selected) isEqual:shared]
              && [selected isEqual:first], @"extension uses host profile without its own profile");

        // Extension-specific profile ordering cannot change the shared choice.
        WriteProfile(extension, @[@"group.unrelated.extension"]);
        Check([AEResolveAppGroup(configured, extension, authorized, &selected) isEqual:shared], @"ignore separate extension profile");

        NSURL *original = [root URLByAppendingPathComponent:@"original"];
        NSURL *result = AEResolveAppGroup(configured, app, ^NSURL *(NSString *group) {
            return [group isEqual:configured] ? original : shared;
        }, &selected);
        Check([result isEqual:original] && [selected isEqual:configured], @"preserve original installation storage");

        NSURL *profile = [app URLByAppendingPathComponent:@"embedded.mobileprovision"];
        for (NSString *malformed in @[@"", @"<?xml incomplete", @"<?xml broken</plist>"]) {
            [malformed writeToURL:profile atomically:YES encoding:NSUTF8StringEncoding error:nil];
            Check(AEProvisionedAppGroups(app).count == 0, @"malformed profile is ignored");
        }
        WriteProfile(app, @"not an array");
        Check(AEProvisionedAppGroups(app).count == 0, @"invalid entitlement type is ignored");
        [fm removeItemAtURL:profile error:nil];
        Check(AEProvisionedAppGroups(app).count == 0, @"missing profile is ignored");
        selected = @"stale";
        result = AEResolveAppGroup(configured, app, ^NSURL *(NSString *group) { return nil; }, &selected);
        Check(result == nil && selected == nil, @"never claim access to an unauthorized container");
        [fm removeItemAtURL:root error:nil];
        NSLog(@"PASS: App Group selection regression checks");
    }
    return 0;
}
