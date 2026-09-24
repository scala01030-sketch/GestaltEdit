//
//  GestaltAccess.h
//  GestaltEdit
//
//  High-level service that uses bad_query to acquire a read/write sandbox
//  extension, then reads, edits, saves and backs up
//  com.apple.MobileGestalt.plist.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GestaltAccess : NSObject

+ (instancetype)shared;

/// Returns whether this process is running on an iOS or iPadOS 27 build that
/// GestaltEdit currently recognizes (developer beta 1 through beta 4 and 27.0).
+ (BOOL)isRunningSupportedOS;

/// Returns whether the compile-time read-only probe configuration is active.
+ (BOOL)isReadOnlyProbeBuild;

/// Installation/launch check only: no system-cache access implementation exists.
+ (BOOL)isInstallSmokeTestBuild;

/// Returns whether the compile-time safety configuration is internally valid.
+ (BOOL)isBuildConfigurationSafe;

/// Access is permitted only on the original beta allowlist. Recognition of a
/// later build is not evidence that its private-API access path works safely.
+ (BOOL)isSystemAccessAllowed;

/// Returns whether this build and OS permit MobileGestalt writes.
+ (BOOL)areWritesEnabled;

/// The Darwin build identifier used by the supported-OS check, such as
/// "24A5390f". An empty string means the build identifier could not be read.
+ (NSString *)currentOSBuild;

/// Acquires a lease for a write build. Read-only callers must use readGestalt.
- (BOOL)connectWithError:(NSError **)error;

/// Reads and parses the plist. Read-only builds cache one validated snapshot.
- (nullable NSDictionary *)readGestaltWithError:(NSError **)error;
/// Returns original bytes. Read-only builds never retry a failed acquisition.
- (nullable NSData *)readGestaltDataWithError:(NSError **)error;
/// Rewrites the existing plist inode and preserves its ownership, flags and
/// extended attributes. Fails without touching the file when writes are disabled.
- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
