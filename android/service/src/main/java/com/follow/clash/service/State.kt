package com.follow.clash.service

import android.content.Intent
import com.follow.clash.common.GlobalState
import com.follow.clash.common.ServiceDelegate
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.sync.Mutex
import org.json.JSONObject
import java.util.UUID

object State {
    var options: VpnOptions? = null
    var notificationParamsFlow: MutableStateFlow<NotificationParams?> = MutableStateFlow(
        NotificationParams()
    )

    val runLock = Mutex()
    var runTime: Long = 0L

    var delegate: ServiceDelegate<IBaseService>? = null

    var eventListener: IEventInterface? = null

    var intent: Intent? = null

    fun emitLog(payload: String, level: String = "info") {
        GlobalState.log(payload)
        val listener = eventListener ?: return
        runCatching {
            val event = JSONObject().apply {
                put("type", "log")
                put(
                    "data",
                    JSONObject().apply {
                        put("LogLevel", level)
                        put("Payload", payload)
                    },
                )
            }.toString().toByteArray()
            listener.onEvent(
                UUID.randomUUID().toString(),
                event,
                true,
                object : IAckInterface.Stub() {
                    override fun onAck() = Unit
                },
            )
        }.onFailure {
            GlobalState.log("Failed to emit service log: ${it.message}")
        }
    }
}
