#include "../../src/release_profile.h"
#include <cassert>
int main() {
 using namespace ma;
 assert(parse_release_profile(nullptr)==ReleaseProfile::FreeOnly);
 assert(parse_release_profile("")==ReleaseProfile::FreeOnly);
 assert(parse_release_profile("FREE_ONLY")==ReleaseProfile::FreeOnly);
 assert(!parse_release_profile("enabled"));
 assert(!parse_release_profile("PAID_VERIFIED_NOW"));
 auto free=free_release_capabilities();
 assert(free.freeHistoryHours==6 && !free.paidEnabled && !free.trialEnabled &&
        !free.premiumMediaEnabled);
 assert(free.movingLocationMinutesMin==10 && free.movingLocationMinutesMax==15);
 assert(!paid_release_authorized(ReleaseProfile::PaidVerified,nullptr,nullptr,nullptr));
 assert(!paid_release_authorized(ReleaseProfile::PaidVerified,"CONFIRMED",nullptr,"CONFIRMED"));
 assert(!paid_release_authorized(ReleaseProfile::FreeOnly,"CONFIRMED","CONFIRMED","CONFIRMED"));
 assert(paid_release_authorized(ReleaseProfile::PaidVerified,
                                "CONFIRMED","CONFIRMED","CONFIRMED"));
 assert(!paid_release_capabilities().premiumMediaEnabled);
 return 0;
}
