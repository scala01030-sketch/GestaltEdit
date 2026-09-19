//
//  GestaltAccess.m
//  GestaltEdit
//
//  bad_query path traversal (iOS 26 / 27):
//       class 13, MobileGestalt SystemGroup, part 3, target absolute path,
//       flags 0x8000000000; directly consumes the sandbox token

#import "GestaltAccess.h"
#import "BadQueryBridge.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <unistd.h>

#ifndef GESTALT_ENABLE_WRITES
#define GESTALT_ENABLE_WRITES 0
#endif

#ifndef GESTALT_READ_ONLY_PROBE
#define GESTALT_READ_ONLY_PROBE 1
#endif

#if GESTALT_READ_ONLY_PROBE && GESTALT_ENABLE_WRITES
#error "A read-only probe must not be built with MobileGestalt writes enabled."
#endif

#if (GESTALT_ENABLE_WRITES != 0 && GESTALT_ENABLE_WRITES != 1) || \
    (GESTALT_READ_ONLY_PROBE != 0 && GESTALT_READ_ONLY_PROBE != 1) || \
    (GESTALT_ENABLE_WRITES + GESTALT_READ_ONLY_PROBE != 1)
#error "Select exactly one mode using Boolean configuration values."
#endif

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

static NSString * const kMobileGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";
static NSString * const kBadQueryMobileGestaltCacheDirectory =
    @"/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestaltedit.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

static BOOL GestaltCanOpen(NSString *path, BOOL requireWriteAccess)
{
    int fd = open(path.fileSystemRepresentation,
                  (requireWriteAccess ? O_RDWR : O_RDONLY) |
                  O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

#if GESTALT_ENABLE_WRITES
static BOOL GestaltWriteAll(int fd, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}
#endif

#if GESTALT_READ_ONLY_PROBE
// One descriptor, no memory mapping, no symlink following, bounded allocation.
// This does not make the private API itself risk-free or its lease read-only.
static NSData *GestaltReadSnapshot(NSString *path, NSError **error)
{
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) {
        if (error) *error = GestaltError(4, @"Cannot open a read-only snapshot.");
        return nil;
    }
    struct stat before, after;
    NSMutableData *data = nil;
    BOOL valid = NO;
    if (fstat(fd, &before) == 0 && S_ISREG(before.st_mode) &&
        before.st_size > 0 && before.st_size <= 16 * 1024 * 1024) {
        data = [NSMutableData dataWithLength:(NSUInteger)before.st_size];
        NSUInteger offset = 0;
        while (offset < data.length) {
            ssize_t count = read(fd, (uint8_t *)data.mutableBytes + offset, data.length - offset);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) break;
            offset += (NSUInteger)count;
        }
        valid = offset == data.length && fstat(fd, &after) == 0 &&
            before.st_size == after.st_size &&
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec &&
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec &&
            before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec &&
            before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec;
    }
    close(fd);
    id plist = valid ? [NSPropertyListSerialization propertyListWithData:data
        options:0 format:NULL error:NULL] : nil;
    if (![plist isKindOfClass:NSDictionary.class] ||
        ![plist[@"CacheExtra"] isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(5, @"Snapshot is missing, changed during reading, oversized, or has an invalid CacheExtra dictionary.");
        return nil;
    }
    if (error) *error = nil;
    return [data copy];
}
#endif

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess
{
    BadQueryLease *_activeBadQueryLease;
#if GESTALT_READ_ONLY_PROBE
    BOOL _probeAttempted;
    BOOL _probeReadInProgress;
    NSData *_probeSnapshot;
    NSError *_probeError;
#endif
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

+ (NSString *)currentOSBuild
{
    size_t length = 0;
    if (sysctlbyname("kern.osversion", NULL, &length, NULL, 0) != 0 ||
        length == 0) {
        return @"";
    }

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("kern.osversion", data.mutableBytes, &length, NULL, 0) != 0)
        return @"";

    return [NSString stringWithUTF8String:data.bytes] ?: @"";
}

+ (BOOL)isRunningSupportedOS
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *build = self.currentOSBuild;

    return version.majorVersion == 27 && (
        [build isEqualToString:@"24A5355q"] || // iOS / iPadOS 27 beta 1
        [build isEqualToString:@"24A5370h"] || // iOS / iPadOS 27 beta 2
        [build isEqualToString:@"24A5380h"] || // iOS / iPadOS 27 beta 3
        [build isEqualToString:@"24A5380i"] || // iPadOS 27 beta 3 v2
        [build isEqualToString:@"24A5380l"] || // iOS / iPadOS 27 Public Beta 1 (revised beta 3, see issue #51)
        [build isEqualToString:@"24A5390f"] || // iOS / iPadOS 27 beta 4
        [build isEqualToString:@"24A435"] ||   // iOS / iPadOS 27.0 RC
        [build isEqualToString:@"24A437"]      // iOS / iPadOS 27.0 release
    );
}

+ (BOOL)areWritesEnabled
{
    return GESTALT_ENABLE_WRITES == 1 && [self isBuildConfigurationSafe] &&
        [self isSystemAccessAllowed];
}

+ (BOOL)isSystemAccessAllowed
{
    // The upstream access primitive only claims support through beta 4.
    // Do not probe RC/release or enable their writes by changing build flags.
    NSString *build = self.currentOSBuild;
    return [self isRunningSupportedOS] &&
        [@[@"24A5355q", @"24A5370h", @"24A5380h", @"24A5380i", @"24A5380l", @"24A5390f"] containsObject:build];
}

+ (BOOL)isReadOnlyProbeBuild
{
    return GESTALT_READ_ONLY_PROBE == 1;
}

+ (BOOL)isBuildConfigurationSafe
{
    return !(GESTALT_READ_ONLY_PROBE == 1 && GESTALT_ENABLE_WRITES == 1);
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    @synchronized (self) {
    if (![[self class] isSystemAccessAllowed]) {
        if (error) *error = GestaltError(0, NSLocalizedString(
            @"System access is blocked: this build has no validated MobileGestalt access path.", nil));
        return NO;
    }
#if GESTALT_READ_ONLY_PROBE
    if (!_probeReadInProgress) {
        if (error) *error = GestaltError(13, @"Direct connection is disabled. Use the single read-only snapshot operation.");
        return NO;
    }
#endif

    if (self.isConnected && _activeBadQueryLease.isActive &&
        self.plistPath.length > 0) {
        if (error) *error = nil;
        return YES;
    }

    if (!BadQueryBridgeAvailable()) {
        if (error) *error = GestaltError(1, NSLocalizedString(
            @"bad_query is unavailable (required ContainerManager or sandbox extension APIs are missing).", nil));
        return NO;
    }

    [_activeBadQueryLease invalidate];
    _activeBadQueryLease = nil;
    self.isConnected = NO;
    self.plistPath = nil;

    NSString *badQueryTarget = [kBadQueryMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryPlist = [kMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryDetail = nil;
    BadQueryLease *badQueryLease = [BadQueryLease leaseForPath:badQueryTarget
                                                        error:&badQueryDetail];
    if (!badQueryLease) {
        if (error) *error = GestaltError(2,
            badQueryDetail ?: NSLocalizedString(@"bad_query failed.", nil));
        return NO;
    }
    BOOL requireWriteAccess = GestaltAccess.areWritesEnabled;
    if (!GestaltCanOpen(badQueryPlist, requireWriteAccess)) {
        [badQueryLease invalidate];
        NSString *message = requireWriteAccess
            ? NSLocalizedString(@"bad_query acquired a sandbox extension, but the MobileGestalt plist is not writable.", nil)
            : NSLocalizedString(@"bad_query acquired a sandbox extension, but the MobileGestalt plist is not readable.", nil);
        if (error) *error = GestaltError(3, message);
        return NO;
    }

    _activeBadQueryLease = badQueryLease;
    self.isConnected = YES;
    self.plistPath = badQueryPlist;
    if (error) *error = nil;
    return YES;
    }
}

#pragma mark - Read / Write

- (NSData *)readGestaltDataWithError:(NSError **)error
{
#if GESTALT_READ_ONLY_PROBE
    @synchronized (self) {
        if (!_probeAttempted) {
            _probeAttempted = YES;
            _probeReadInProgress = YES;
            NSError *readError = nil;
            @try {
                if ([self connectWithError:&readError]) {
                    _probeSnapshot = GestaltReadSnapshot(self.plistPath, &readError);
                }
                _probeError = readError;
            } @finally {
                [_activeBadQueryLease invalidate];
                _activeBadQueryLease = nil;
                self.isConnected = NO;
                self.plistPath = nil;
                _probeReadInProgress = NO;
            }
        }
        if (error) *error = _probeError;
        return _probeSnapshot;
    }
#else
    if (![self connectWithError:error]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
        if (error) *error = GestaltError(3,
            [NSString stringWithFormat:NSLocalizedString(@"The plist does not exist: %@", nil), self.plistPath]);
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(4, NSLocalizedString(@"Failed to read the plist.", nil));
        return nil;
    }
    if (error) *error = nil;
    return data;
#endif
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(5,
            NSLocalizedString(@"The plist top level is not a dictionary.", nil));
        return nil;
    }
    self.lastReadFormat = format;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    if (![[self class] areWritesEnabled]) {
        if (error) *error = GestaltError(12, NSLocalizedString(
            @"This is a read-only compatibility probe. MobileGestalt writes are disabled.", nil));
        return NO;
    }
#if !GESTALT_ENABLE_WRITES
    return NO;
#else
    if (![self connectWithError:error]) return NO;
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(6, NSLocalizedString(@"The content to save is not a dictionary.", nil));
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 &&
        format != NSPropertyListBinaryFormat_v1_0)
        format = NSPropertyListBinaryFormat_v1_0;

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:format
                                                             options:0
                                                               error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(7, NSLocalizedString(@"Failed to serialize the plist.", nil));
        return NO;
    }

    NSString *targetPath = self.plistPath;
    NSError *readError = nil;
    NSData *original = [NSData dataWithContentsOfFile:targetPath
                                              options:0
                                                error:&readError];
    if (!original) {
        if (error) *error = readError ?: GestaltError(8, NSLocalizedString(@"Failed to read the original plist.", nil));
        return NO;
    }

    int fd = open(targetPath.fileSystemRepresentation,
                  O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        if (error) *error = GestaltError(9,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to open the plist (errno=%d).", nil), errno]);
        return NO;
    }

    BOOL wrote = ftruncate(fd, 0) == 0 &&
        lseek(fd, 0, SEEK_SET) == 0 &&
        GestaltWriteAll(fd, data) &&
        fsync(fd) == 0;
    int writeErrno = errno;

    if (!wrote) {
        ftruncate(fd, 0);
        lseek(fd, 0, SEEK_SET);
        GestaltWriteAll(fd, original);
        fsync(fd);
        close(fd);
        if (error) *error = GestaltError(10,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to write the plist (errno=%d).", nil), writeErrno]);
        return NO;
    }
    close(fd);

    NSData *verification = [NSData dataWithContentsOfFile:targetPath];
    if (![verification isEqualToData:data]) {
        if (error) *error = GestaltError(11, NSLocalizedString(@"Post-write verification failed.", nil));
        return NO;
    }

    if (error) *error = nil;
    return YES;
#endif
}

@end
