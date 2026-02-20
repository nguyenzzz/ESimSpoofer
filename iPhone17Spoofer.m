//
//  iPhone17Spoofer.m
//  Spoofs the device model to iPhone 17 (iPhone18,3) only.
//  No UUID spoofing included.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>

#define SPOOF_LOG(fmt, ...) NSLog(@"[iPhone17Spoofer] " fmt, ##__VA_ARGS__)

// -------------------------------------------------------------------------
// 1. C-Function Hooking (Low-level Hardware Identifiers)
// -------------------------------------------------------------------------

// Macro to hook C functions using the Dynamic Linker
#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
    __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

// Hook `uname`
int hooked_uname(struct utsname *name) {
    int ret = uname(name); 
    if (ret == 0) {
        // Overwrite the machine string to the base iPhone 17
        strcpy(name->machine, "iPhone18,3");
    }
    return ret;
}
DYLD_INTERPOSE(hooked_uname, uname);

// Hook `sysctlbyname`
int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (strcmp(name, "hw.machine") == 0) {
        if (oldp && oldlenp) {
            const char *spoofed = "iPhone18,3";
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
// 2. Objective-C Hooking (High-level UIDevice Name)
// -------------------------------------------------------------------------

// Fake High-Level Device Name
NSString *hooked_name(id self, SEL _cmd) {
    return @"iPhone 17";
}

// The Constructor that applies our Objective-C hooks
__attribute__((constructor))
static void DeviceSpooferInit(void) {
    SPOOF_LOG(@"Loaded! Hooking C-Level hardware checks for iPhone 17...");

    Class targetClass = objc_getClass("UIDevice");
    if (targetClass) {
        // Hook Device Name only (No UUID hook)
        Method nameMethod = class_getInstanceMethod(targetClass, @selector(name));
        if (nameMethod) {
            method_setImplementation(nameMethod, (IMP)hooked_name);
            SPOOF_LOG(@"UIDevice name hooked successfully.");
        }
    }
}