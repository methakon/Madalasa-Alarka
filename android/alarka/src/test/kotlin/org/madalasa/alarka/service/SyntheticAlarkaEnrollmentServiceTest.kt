package org.madalasa.alarka.service

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyntheticAlarkaEnrollmentServiceTest {

    private val service = SyntheticAlarkaEnrollmentService()

    @Test
    fun generatePairingChallengeReturnsSyntheticCode() = runBlocking {
        val result = service.generatePairingChallenge()
        assertTrue(result.isSuccess)
        assertEquals("482-901", result.getOrNull())
    }

    @Test
    fun validChallengeCodeCompletesEnrollment() = runBlocking {
        val result = service.completeEnrollment("482-901")
        assertTrue(result.isSuccess)
        val enrollment = result.getOrNull()
        assertNotNull(enrollment)
        assertTrue(enrollment!!.success)
        assertEquals("Alarka Synthetic Alpha", enrollment.devicePseudonym)
    }

    @Test
    fun standardSyntheticTestCodeCompletesEnrollment() = runBlocking {
        val result = service.completeEnrollment("123456")
        assertTrue(result.isSuccess)
        assertTrue(result.getOrNull()!!.success)
    }

    @Test
    fun invalidChallengeCodeFailsEnrollment() = runBlocking {
        val result = service.completeEnrollment("000000")
        assertTrue(result.isFailure)
    }

    @Test
    fun unpairDeviceResetsState() = runBlocking {
        service.completeEnrollment("123456")
        val unpairResult = service.unpairDevice()
        assertTrue(unpairResult.isSuccess)
    }
}
