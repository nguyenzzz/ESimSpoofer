//
//  DeviceSpoofer.m
//  Fakes UUID and spoofs the device model to iPhone 17 Pro
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>

#define SPOOF_LOG(fmt, ...) NSLog(@"[DeviceSpoofer] " fmt, ##__VA_ARGS__)

// -------------------------------------------------------------------------
// 1. C-Function Hooking (Hardware Identifiers)
// -------------------------------------------------------------------------
// We use DYLD_INTERPOSE, a built-in macOS/iOS linker macro, to swap C functions.

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// Hook `uname` (Very common way apps check the raw hardware string)
int hooked_uname(struct utsname *name) {
    int ret = uname(name); // Call original to populate standard data
    if (ret == 0) {
        // Overwrite the machine string to iPhone 17 Pro
        strcpy(name->machine, "iPhone18,1");
    }
    return ret;
}
DYLD_INTERPOSE(hooked_uname, uname);

// Hook `sysctlbyname` (Another common way apps check hardware specs)
int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (strcmp(name, "hw.machine") == 0) {
        if (oldp && oldlenp) {
            const char *spoofed = "iPhone18,1";
            size_t len = strlen(spoofed) + 1;
            if (*oldlenp >= len) {
                strcpy(oldp, spoofed);
                *oldlenp = len;
                return 0; // Return success without calling original
            }
        }
    }
    // For all other queries, pass it to the original function
    return sysctlbyname(name, oldp, oldlenp, newp, newlen);
}
DYLD_INTERPOSE(hooked_sysctlbyname, sysctlbyname);

// -------------------------------------------------------------------------
// 2. Objective-C Hooking (UUID and High-Level names)
// -------------------------------------------------------------------------

static NSUUID *spoofedIDFV = nil;

// Fake UUID logic
NSUUID *hooked_identifierForVendor(id self, SEL _cmd) {
    if (!spoofedIDFV) {
        spoofedIDFV = [NSUUID UUID]; 
        SPOOF_LOG(@"Generated new random IDFV: %@", spoofedIDFV.UUIDString);
    }
    return spoofedIDFV;
}

// Fake High-Level Device Name
NSString *hooked_name(id self, SEL _cmd) {
    return @"iPhone 17 Pro";
}

// The Constructor that applies our Objective-C hooks
__attribute__((constructor))
static void DeviceSpooferInit(void) {
    SPOOF_LOG(@"Loaded! Hooking UIDevice and C-Level hardware checks...");

    Class targetClass = objc_getClass("UIDevice");
    if (targetClass) {
        // Hook UUID
        Method uuidMethod = class_getInstanceMethod(targetClass, @selector(identifierForVendor));
        if (uuidMethod) method_setImplementation(uuidMethod, (IMP)hooked_identifierForVendor);
        
        // Hook Device Name
        Method nameMethod = class_getInstanceMethod(targetClass, @selector(name));
        if (nameMethod) method_setImplementation(nameMethod, (IMP)hooked_name);
        
        SPOOF_LOG(@"UIDevice hooks applied successfully.");
    }
}