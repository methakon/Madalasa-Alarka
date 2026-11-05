package org.madalasa.alarka.service

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Test

class UnavailableAlarkaEnrollmentServiceTest {
    @Test fun productionFallbackNeverPairsOrInventsGuardian() = runBlocking {
        val service = UnavailableAlarkaEnrollmentService()
        assertTrue(service.generatePairingChallenge().isFailure)
        assertTrue(service.completeEnrollment("482-901").isFailure)
        assertTrue(service.unpairDevice().isFailure)
    }
}
