package org.madalasa.alarka.service

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.URI
import java.net.URL
import java.time.Instant
import java.util.UUID
import javax.net.ssl.HttpsURLConnection

interface ChildSosService {
    val sosState: StateFlow<ManualSosState?>
    val isSynthetic: Boolean
    suspend fun triggerSos(): Result<ManualSosState>
    suspend fun retryPendingSos(): Result<ManualSosState>
    suspend fun acknowledgeSimulatedSos()
    fun resetSos()
}

/**
 * Synthetic, demo-only SOS service used in unconfigured or preview debug builds.
 * Never connects to backend or issues real alerts.
 */
class SyntheticChildSosService : ChildSosService {
    private val _sosState = MutableStateFlow<ManualSosState?>(null)
    override val sosState: StateFlow<ManualSosState?> = _sosState.asStateFlow()
    override val isSynthetic: Boolean = true

    override suspend fun triggerSos(): Result<ManualSosState> {
        val eventId = "sos-${UUID.randomUUID()}"
        var state = ManualSosState(eventId = eventId, stage = ManualSosStage.LOCAL_QUEUED)
        _sosState.value = state
        state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.RETRY_ATTEMPT)
        _sosState.value = state
        delay(300)
        state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.SERVER_ACCEPTED, verifiedServerReceipt = true)
        _sosState.value = state
        delay(400)
        state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.NOTIFICATION_DELIVERED, verifiedServerReceipt = true)
        _sosState.value = state
        return Result.success(state)
    }

    override suspend fun retryPendingSos(): Result<ManualSosState> {
        val current = _sosState.value ?: return Result.failure(IllegalStateException("No pending SOS"))
        var state = ManualSosDeliveryPolicy.apply(current, current.eventId, ManualSosEvidence.RETRY_ATTEMPT)
        _sosState.value = state
        delay(300)
        state = ManualSosDeliveryPolicy.apply(state, current.eventId, ManualSosEvidence.SERVER_ACCEPTED, verifiedServerReceipt = true)
        _sosState.value = state
        return Result.success(state)
    }

    override suspend fun acknowledgeSimulatedSos() {
        val current = _sosState.value ?: return
        val state = ManualSosDeliveryPolicy.apply(current, current.eventId, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, verifiedServerReceipt = true)
        _sosState.value = state
    }

    override fun resetSos() {
        _sosState.value = null
    }
}

/**
 * Authenticated HTTPS device manual SOS service.
 * - Stores pending events in KeystorePersistentSosOutbox across reboots.
 * - Retries exact event UUID.
 * - Deletes from outbox ONLY upon verified guardian confirmation.
 * - Tracks separate stages: LOCAL_QUEUED, SENDING, SERVER_ACCEPTED, NOTIFICATION_DELIVERED, GUARDIAN_ACKNOWLEDGED, DELIVERY_FAILED, AUTHORIZATION_REVOKED.
 */
class HttpsChildSosService(
    origin: String,
    private val deviceIdProvider: () -> String?,
    private val credentialProvider: () -> String?,
    private val outbox: PersistentSosOutbox,
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.IO),
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) : ChildSosService {

    private val baseUrl: String
    override val isSynthetic: Boolean = false

    private val _sosState = MutableStateFlow<ManualSosState?>(null)
    override val sosState: StateFlow<ManualSosState?> = _sosState.asStateFlow()

    private var pollingJob: Job? = null

    init {
        val uri = URI(origin.trim())
        require(uri.scheme == "https" && !uri.host.isNullOrBlank()) {
            "Child SOS API origin must use HTTPS"
        }
        baseUrl = uri.toASCIIString().trimEnd('/')

        // Restore any pending SOS event on startup
        val pending = outbox.readPending()
        if (pending != null) {
            val state = pending.toManualSosState()
            _sosState.value = state
            if (state.stage == ManualSosStage.SERVER_ACCEPTED || state.stage == ManualSosStage.NOTIFICATION_DELIVERED) {
                startStatusPolling(pending.eventId)
            }
        }
    }

    private fun exactId(id: String): String {
        require(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(id)) {
            "Invalid UUID identifier"
        }
        return id.lowercase()
    }

    override suspend fun triggerSos(): Result<ManualSosState> = withContext(ioDispatcher) {
        val current = _sosState.value
        if (current != null && !current.guardianHasAcknowledged && !current.revoked) {
            // Already active event; retry sending
            return@withContext sendExisting(current)
        }

        val eventId = UUID.randomUUID().toString().lowercase()
        val observedAt = Instant.now().toString()
        val initialState = ManualSosState(eventId = eventId, stage = ManualSosStage.LOCAL_QUEUED)
        _sosState.value = initialState
        outbox.savePending(initialState, observedAt)

        sendExisting(initialState, observedAt)
    }

    override suspend fun retryPendingSos(): Result<ManualSosState> = withContext(ioDispatcher) {
        val current = _sosState.value ?: outbox.readPending()?.toManualSosState()
        ?: return@withContext Result.failure(IllegalStateException("No pending SOS to retry"))
        sendExisting(current)
    }

    private suspend fun sendExisting(
        current: ManualSosState,
        observedAtOverride: String? = null
    ): Result<ManualSosState> {
        val eventId = current.eventId
        val persisted = outbox.readPending()
        val observedAt = observedAtOverride ?: persisted?.observedAt ?: Instant.now().toString()

        val sendingState = ManualSosDeliveryPolicy.apply(current, eventId, ManualSosEvidence.RETRY_ATTEMPT)
        _sosState.value = sendingState

        val deviceId = deviceIdProvider()?.takeIf {
            Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(it)
        } ?: run {
            val failed = ManualSosDeliveryPolicy.apply(sendingState, eventId, ManualSosEvidence.TRANSIENT_FAILURE)
            _sosState.value = failed
            outbox.updateStage(failed)
            return Result.failure(IllegalStateException("Device not enrolled with backend"))
        }

        val bearer = credentialProvider()?.takeIf { it.isNotBlank() } ?: run {
            val revoked = ManualSosDeliveryPolicy.apply(sendingState, eventId, ManualSosEvidence.AUTHORIZATION_REVOKED)
            _sosState.value = revoked
            outbox.updateStage(revoked)
            return Result.failure(SecurityException("Device credentials missing or revoked"))
        }

        val payload = """{"event_id":"$eventId","kind":"SOS","observed_at":"$observedAt"}"""

        try {
            val conn = URL("$baseUrl/v1/devices/$deviceId/signals").openConnection() as HttpsURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 8_000
            conn.readTimeout = 8_000
            conn.instanceFollowRedirects = false
            conn.useCaches = false
            conn.setRequestProperty("Authorization", "Bearer $bearer")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Accept", "application/json")
            conn.doOutput = true
            conn.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }

            val status = conn.responseCode
            if (status == 401 || status == 403) {
                val revoked = ManualSosDeliveryPolicy.apply(sendingState, eventId, ManualSosEvidence.AUTHORIZATION_REVOKED)
                _sosState.value = revoked
                outbox.updateStage(revoked)
                return Result.failure(SecurityException("Device authorization revoked by server"))
            }

            if (status in 200..299) {
                val acceptedState = ManualSosDeliveryPolicy.apply(
                    sendingState, eventId, ManualSosEvidence.SERVER_ACCEPTED, verifiedServerReceipt = true
                )
                _sosState.value = acceptedState
                outbox.updateStage(acceptedState)
                startStatusPolling(eventId)
                return Result.success(acceptedState)
            } else {
                val failState = ManualSosDeliveryPolicy.apply(sendingState, eventId, ManualSosEvidence.TRANSIENT_FAILURE)
                _sosState.value = failState
                outbox.updateStage(failState)
                return Result.failure(IOException("Server error HTTP $status"))
            }
        } catch (e: Exception) {
            val failState = ManualSosDeliveryPolicy.apply(sendingState, eventId, ManualSosEvidence.TRANSIENT_FAILURE)
            _sosState.value = failState
            outbox.updateStage(failState)
            return Result.failure(e)
        }
    }

    private fun startStatusPolling(eventId: String) {
        pollingJob?.cancel()
        pollingJob = coroutineScope.launch {
            while (isActive) {
                delay(2500)
                val cur = _sosState.value
                if (cur == null || cur.guardianHasAcknowledged || cur.revoked || cur.eventId != eventId) {
                    break
                }
                pollSignalStatus(eventId)
            }
        }
    }

    suspend fun pollSignalStatus(eventId: String): Result<ManualSosState> = withContext(ioDispatcher) {
        val cur = _sosState.value ?: return@withContext Result.failure(IllegalStateException("No active SOS"))
        val deviceId = deviceIdProvider() ?: return@withContext Result.failure(IllegalStateException("No deviceId"))
        val bearer = credentialProvider() ?: return@withContext Result.failure(IllegalStateException("No credential"))

        try {
            val conn = URL("$baseUrl/v1/devices/$deviceId/signals/$eventId/status").openConnection() as HttpsURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 8_000
            conn.readTimeout = 8_000
            conn.useCaches = false
            conn.instanceFollowRedirects = false
            conn.setRequestProperty("Authorization", "Bearer $bearer")
            conn.setRequestProperty("Accept", "application/json")

            val status = conn.responseCode
            if (status == 401 || status == 403) {
                val revoked = ManualSosDeliveryPolicy.apply(cur, eventId, ManualSosEvidence.AUTHORIZATION_REVOKED)
                _sosState.value = revoked
                outbox.updateStage(revoked)
                return@withContext Result.failure(SecurityException("Authorization revoked"))
            }

            if (status == 200) {
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val serverStage = Regex("\"stage\"\\s*:\\s*\"([^\"]+)\"").find(body)?.groupValues?.get(1) ?: ""
                val guardianAck = Regex("\"guardian_acknowledged\"\\s*:\\s*(true|false)").find(body)?.groupValues?.get(1)?.toBoolean() ?: false || serverStage == "GUARDIAN_ACKNOWLEDGED"

                if (guardianAck) {
                    val ackedState = ManualSosDeliveryPolicy.apply(
                        cur, eventId, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, verifiedServerReceipt = true
                    )
                    _sosState.value = ackedState
                    // Confirmation-based deletion from outbox
                    outbox.clearPending(eventId)
                    pollingJob?.cancel()
                    return@withContext Result.success(ackedState)
                } else if (serverStage == "NOTIFICATION_DELIVERED") {
                    val notifDeliveredState = ManualSosDeliveryPolicy.apply(
                        cur, eventId, ManualSosEvidence.NOTIFICATION_DELIVERED, verifiedServerReceipt = true
                    )
                    _sosState.value = notifDeliveredState
                    outbox.updateStage(notifDeliveredState)
                    return@withContext Result.success(notifDeliveredState)
                }
                return@withContext Result.success(cur)
            }
            Result.failure(IOException("Status poll HTTP $status"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun acknowledgeSimulatedSos() {
        // Real HTTPS service never simulates guardian ACK. Guardian must call POST /ack.
    }

    override fun resetSos() {
        val current = _sosState.value
        if (current?.guardianHasAcknowledged == true || current?.stage == ManualSosStage.DELIVERY_FAILED) {
            current.let { outbox.clearPending(it.eventId) }
            _sosState.value = null
        }
    }
}
