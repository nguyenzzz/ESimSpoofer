//
//  ReferralBypass_iPhoneAir.m
//  Spoofs iPhone 17 Air (iPhone18,4), randomizes IDs, and blocks Keychain.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>

#define REF_LOG(fmt, ...) NSLog(@"[ReferralBypass_Air] " fmt, ##__VA_ARGS__)

// -------------------------------------------------------------------------
// 1. C-Function Hooks (Hardware Spoofing & Keychain Blocking)
// -------------------------------------------------------------------------

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// Spoof `uname` to iPhone 17 Air
int hooked_uname(struct utsname *name) {
    int ret = uname(name);
    if (ret == 0) strcpy(name->machine, "iPhone18,4");
    return ret;
}
DYLD_INTERPOSE(hooked_uname, uname);

// Spoof `sysctlbyname` to iPhone 17 Air
int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (strcmp(name, "hw.machine") == 0) {
        if (oldp && oldlenp) {
            const char *spoofed = "iPhone18,4";
            size_t len = strlen(spoofed) + 1;
            if (*oldlenp >= len) {
                strcpy(oldp, spoofed);
                *oldlenp = len;
                return 0;
            }
        }
    }
    return sysctlbyname(name, oldp, oldlenp, newp, newlen);
}
DYLD_INTERPOSE(hooked_sysctlbyname, sysctlbyname);

// Block Keychain Reads
OSStatus hooked_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    REF_LOG(@"App attempted to read Keychain. Blocking to simulate first launch.");
    return errSecItemNotFound; 
}
DYLD_INTERPOSE(hooked_SecItemCopyMatching, SecItemCopyMatching);


// -------------------------------------------------------------------------
// 2. Objective-C Hooks (Identifiers and Device Name)
// -------------------------------------------------------------------------

static NSUUID *randomIDFV = nil;
static NSUUID *randomIDFA = nil;

NSUUID *hooked_identifierForVendor(id self, SEL _cmd) {
    if (!randomIDFV) {
        randomIDFV = [NSUUID UUID];
        REF_LOG(@"Generated new random IDFV: %@", randomIDFV.UUIDString);
    }
    return randomIDFV;
}

NSUUID *hooked_advertisingIdentifier(id self, SEL _cmd) {
    if (!randomIDFA) {
        randomIDFA = [NSUUID UUID];
        REF_LOG(@"Generated new random IDFA: %@", randomIDFA.UUIDString);
    }
    return randomIDFA;
}

NSString *hooked_name(id self, SEL _cmd) {
    return @"iPhone Air";
}


// -------------------------------------------------------------------------
// 3. Constructor
// -------------------------------------------------------------------------

__attribute__((constructor))
static void ReferralBypassInit(void) {
    REF_LOG(@"Loaded! Spoofing iPhone 17 Air and randomizing identity...");

    // Hook UIDevice
    Class deviceClass = objc_getClass("UIDevice");
    if (deviceClass) {
        Method idfvMethod = class_getInstanceMethod(deviceClass, @selector(identifierForVendor));
        if (idfvMethod) method_setImplementation(idfvMethod, (IMP)hooked_identifierForVendor);
        
        Method nameMethod = class_getInstanceMethod(deviceClass, @selector(name));
        if (nameMethod) method_setImplementation(nameMethod, (IMP)hooked_name);
    }

    // Hook ASIdentifierManager
    Class asClass = objc_getClass("ASIdentifierManager");
    if (asClass) {
        Method idfaMethod = class_getInstanceMethod(asClass, @selector(advertisingIdentifier));
        if (idfaMethod) method_setImplementation(idfaMethod, (IMP)hooked_advertisingIdentifier);
    }
}