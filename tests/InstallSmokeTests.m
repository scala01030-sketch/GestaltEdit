#import "../GestaltEdit/GestaltAccess.h"
#include <stdio.h>
#include <stdlib.h>

static NSUInteger checks;
static void Check(BOOL value, const char *name) {
    checks++;
    if (!value) { fprintf(stderr, "FAIL: %s\n", name); exit(1); }
    printf("PASS: %s\n", name);
}
int main(void) {
    @autoreleasepool {
        // No bridge stub is linked: its implementation must be absent entirely.
        Check(NSClassFromString(@"BadQueryLease") == Nil, "private bridge class absent");
        Check([GestaltAccess isInstallSmokeTestBuild], "installation mode is explicit");
        Check([GestaltAccess isBuildConfigurationSafe], "safe flags accepted");
        Check([GestaltAccess isReadOnlyProbeBuild], "no-write policy retained");
        Check(![GestaltAccess areWritesEnabled], "writes disabled on every OS");
        Check(![GestaltAccess isSystemAccessAllowed], "system access disabled on every OS");
        Check(![GestaltAccess isRunningSupportedOS], "no compatibility claim");
        GestaltAccess *access = [GestaltAccess shared];
        Check(access == [GestaltAccess shared], "singleton is stable");
        Check([GestaltAccess currentOSBuild].length > 0, "public OS build available");
        for (int attempt = 0; attempt < 3; attempt++) {
            NSError *error = nil;
            Check(![access connectWithError:&error] && error.code == 100, "connect refuses");
            error = nil;
            Check([access readGestaltDataWithError:&error] == nil && error.code == 100, "raw read refuses");
            error = nil;
            Check([access readGestaltWithError:&error] == nil && error.code == 100, "parsed read refuses");
            error = nil;
            Check(![access saveGestalt:@{} error:&error] && error.code == 100, "save refuses");
        }
        Check(![access connectWithError:NULL], "null error pointer safe");
        Check([access readGestaltDataWithError:NULL] == nil, "null error raw read safe");
        Check([access readGestaltWithError:NULL] == nil, "null error parsed read safe");
        Check(![access saveGestalt:@{} error:NULL], "null error save safe");
        printf("PASS: %lu install-only checks; private bridge absent.\n", (unsigned long)checks);
    }
    return 0;
}
