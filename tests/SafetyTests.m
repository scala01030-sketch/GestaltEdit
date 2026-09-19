// Host-only tests. The real BadQueryBridge.m is deliberately NOT linked.
#import "../GestaltEdit/GestaltAccess.m"

static NSUInteger bridgeCalls, invalidations, acquisitions, checks;
static NSString *testBuild;
static NSString *fixturePath;

@implementation BadQueryLease
+ (instancetype)leaseForPath:(NSString *)path error:(NSString **)error {
    bridgeCalls++;
    return nil;
}
- (NSString *)targetPath { return @"fixture"; }
- (BOOL)isActive { return YES; }
- (void)invalidate { invalidations++; }
@end
BOOL BadQueryBridgeAvailable(void) { bridgeCalls++; return NO; }

@interface TestAccess : GestaltAccess @end
@implementation TestAccess
// The host is macOS; exercise build policy independently of host OS major.
+ (BOOL)isRunningSupportedOS { return YES; }
+ (NSString *)currentOSBuild { return testBuild; }
@end

#if GESTALT_READ_ONLY_PROBE
@interface FixtureAccess : TestAccess @end
@implementation FixtureAccess
- (BOOL)connectWithError:(NSError **)error {
    acquisitions++;
    [self setValue:fixturePath forKey:@"plistPath"];
    [self setValue:[BadQueryLease new] forKey:@"_activeBadQueryLease"];
    if (error) *error = nil;
    return YES;
}
@end
#endif

static void Check(BOOL passed, const char *name) {
    checks++;
    if (!passed) { fprintf(stderr, "FAIL: %s\n", name); exit(1); }
    printf("PASS: %s\n", name);
}

int main(void) {
    @autoreleasepool {
        NSError *error = nil;
        Check([GestaltAccess isBuildConfigurationSafe], "valid build configuration");
        for (NSString *build in @[@"24A435", @"24A437", @"", @"24A999", @"24A5390f-extra"]) {
            testBuild = build;
            TestAccess *access = [TestAccess new];
            Check(![TestAccess isSystemAccessAllowed], "unvalidated build denied");
            Check(![TestAccess areWritesEnabled], "unvalidated build cannot enable writes");
            Check(![access connectWithError:&error] && error != nil, "connect denied before bridge");
            Check(![access readGestaltDataWithError:&error] && error != nil, "read denied before bridge");
            Check(![access saveGestalt:@{} error:&error] && error != nil, "save denied before bridge");
        }
        Check(bridgeCalls == 0, "blocked builds make zero bridge calls");
        for (NSString *build in @[@"24A5355q", @"24A5370h", @"24A5380h", @"24A5380i", @"24A5380l", @"24A5390f"]) {
            testBuild = build;
            Check([TestAccess isSystemAccessAllowed], "original beta policy retained");
        }
#if GESTALT_READ_ONLY_PROBE
        TestAccess *access = [TestAccess new];
        Check(![access connectWithError:&error], "direct lease acquisition disabled");
        Check(bridgeCalls == 0, "direct connection has no side effect");
        Check(![access saveGestalt:@{} error:&error] && error.code == 12, "save denied in read-only mode");
        Check(bridgeCalls == 0, "save has no bridge side effect");
        Check(![access readGestaltDataWithError:&error], "missing bridge fails closed");
        Check(bridgeCalls == 1, "one acquisition attempt");
        Check(![access readGestaltDataWithError:&error], "failed read stays failed");
        Check(bridgeCalls == 1, "failed read does not retry");

        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        Check([NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:&error], "create isolated fixtures");
        fixturePath = [directory stringByAppendingPathComponent:@"fixture.plist"];
        NSData *valid = [NSPropertyListSerialization dataWithPropertyList:@{@"CacheExtra":@{@"test":@1}} format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        Check([valid writeToFile:fixturePath options:0 error:&error], "write synthetic fixture");
        FixtureAccess *fixture = [FixtureAccess new];
        Check([[fixture readGestaltDataWithError:&error] isEqual:valid], "snapshot preserves original bytes");
        Check(invalidations == 1, "successful read releases lease");
        Check([fixture valueForKey:@"plistPath"] == nil, "successful read clears live path");
        Check([[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:fixturePath options:0 error:&error], "replace synthetic fixture");
        Check([[fixture readGestaltDataWithError:&error] isEqual:valid], "later read uses immutable cached snapshot");
        Check(acquisitions == 1 && invalidations == 1, "cached read reacquires no lease");
        FixtureAccess *failed = [FixtureAccess new];
        Check([failed readGestaltDataWithError:&error] == nil && error != nil, "invalid plist rejected");
        Check(invalidations == 2, "failed read releases lease");
        Check([valid writeToFile:fixturePath options:0 error:&error], "repair fixture only");
        Check([failed readGestaltDataWithError:&error] == nil && acquisitions == 2, "failure remains latched after file changes");
        for (id value in @[@{}, @{@"CacheExtra":@[]}, @[], @{@"CacheExtra":@"bad"}]) {
            NSData *invalid = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
            Check([invalid writeToFile:fixturePath options:0 error:&error], "write invalid shape fixture");
            Check(GestaltReadSnapshot(fixturePath, &error) == nil, "invalid CacheExtra shape rejected");
        }
        NSString *link = [directory stringByAppendingPathComponent:@"link"];
        Check(symlink(fixturePath.fileSystemRepresentation, link.fileSystemRepresentation) == 0, "create symlink fixture");
        Check(GestaltReadSnapshot(link, &error) == nil, "final-path symlink rejected");
        Check(GestaltReadSnapshot(directory, &error) == nil, "directory rejected");
        NSString *fifo = [directory stringByAppendingPathComponent:@"fifo"];
        Check(mkfifo(fifo.fileSystemRepresentation, 0600) == 0, "create FIFO fixture");
        Check(GestaltReadSnapshot(fifo, &error) == nil, "FIFO rejected without blocking");
        int fd = open(fixturePath.fileSystemRepresentation, O_WRONLY | O_TRUNC);
        Check(fd >= 0 && ftruncate(fd, 16 * 1024 * 1024 + 1) == 0, "create oversized sparse fixture");
        close(fd);
        Check(GestaltReadSnapshot(fixturePath, &error) == nil, "oversized file rejected");
        Check([NSFileManager.defaultManager removeItemAtPath:directory error:&error], "remove only isolated fixtures");
#endif
        printf("PASS: %lu checks; real private API was not linked.\n", (unsigned long)checks);
    }
    return 0;
}
