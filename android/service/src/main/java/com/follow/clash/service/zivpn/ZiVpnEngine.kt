package com.follow.clash.service.zivpn

import android.content.Context
import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.os.ParcelFileDescriptor
import com.follow.clash.service.State
import com.follow.clash.service.models.VpnOptions
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import kotlin.math.max
import kotlin.math.min

class ZiVpnEngine(private val context: Context) {
    private val processes = mutableListOf<Process>()
    private var tunFd: ParcelFileDescriptor? = null
    private var stopping = false

    fun start(fd: ParcelFileDescriptor, mtu: Int, options: VpnOptions) {
        stopping = false
        tunFd = fd
        validateOptions(options)

        val server = options.zivpnServer.trim()
        val portRange = options.zivpnPortRange.trim()
        val password = options.zivpnPassword.trim()
        val obfs = options.zivpnObfs.trim().ifEmpty { DEFAULT_OBFS }
        val coreCount = options.zivpnCoreCount.coerceIn(1, 8)
        val udpgwPort = options.zivpnUdpGwPort.coerceIn(1, 65535)

        log("ZiVPN start: server=$server range=$portRange cores=$coreCount udpgw=${options.zivpnEnableUdpGw} udpgwPort=$udpgwPort")
        val nativeDir = context.applicationInfo.nativeLibraryDir
        startZiVpnCores(nativeDir, server, portRange, password, obfs, coreCount)
        startPdnsd()
        startTun2Socks(nativeDir, mtu, options.zivpnEnableUdpGw, udpgwPort)

        if (!sendTunFdWithRetry(fd)) {
            error("ZiVPN TUN fd handoff failed after retries")
            throw IllegalStateException("Failed to hand TUN fd to ZiVPN tun2socks")
        }
        log("ZiVPN backend running via SOCKS5 127.0.0.1:$LOCAL_SOCKS_PORT")
    }

    fun stop() {
        log("ZiVPN stop requested")
        stopping = true
        processes.reversed().forEach { process ->
            runCatching { process.destroy() }
            runCatching { process.destroyForcibly() }
        }
        processes.clear()
        runCatching { tunFd?.close() }
        tunFd = null
        log("ZiVPN stopped")
    }

    private fun validateOptions(options: VpnOptions) {
        require(options.zivpnServer.isNotBlank()) { "ZiVPN server is empty" }
        require(options.zivpnPortRange.isNotBlank()) { "ZiVPN port/range is empty" }
        require(options.zivpnPassword.isNotBlank()) { "ZiVPN password/auth is empty" }
        // Obfs is optional in the UI; empty values fall back to MiniZiVPN's default.
        require(!options.zivpnServer.contains("://")) { "ZiVPN server must be a host/IP, not a URL" }
    }

    private fun startZiVpnCores(
        nativeDir: String,
        server: String,
        portRange: String,
        password: String,
        obfs: String,
        coreCount: Int,
    ) {
        val libUz = requireExecutable(File(nativeDir, "libuz.so"), "ZiVPN core")
        val libLoad = requireExecutable(File(nativeDir, "libload.so"), "ZiVPN load balancer")
        val targets = mutableListOf<String>()

        for (index in 0 until coreCount) {
            val port = FIRST_CORE_PORT + index
            val config = buildCoreConfig(server, portRange, password, obfs, port)
            val command = listOf(libUz.absolutePath, "-s", obfs, "--config", config.absolutePath)
            log("Starting ZiVPN core #${index + 1}/$coreCount on SOCKS5 127.0.0.1:$port")
            val process = startProcess("ZiVPN-Core-$port", command, nativeDir)
            targets.add("127.0.0.1:$port")
            if (!waitForLocalPort(port, CORE_READY_TIMEOUT_MS)) {
                error("ZiVPN core on port $port did not become ready")
                throw IllegalStateException("ZiVPN core on port $port did not become ready")
            }
            log("ZiVPN core ready on 127.0.0.1:$port")
            monitor(process, "ZiVPN-Core-$port")
        }

        val lbCommand = mutableListOf(libLoad.absolutePath, "-lport", LOCAL_SOCKS_PORT.toString(), "-tunnel")
        lbCommand.addAll(targets)
        log("Starting ZiVPN load balancer on 127.0.0.1:$LOCAL_SOCKS_PORT -> ${targets.joinToString()}")
        val lbProcess = startProcess("ZiVPN-LoadBalancer", lbCommand, nativeDir)
        if (!waitForLocalPort(LOCAL_SOCKS_PORT, LOAD_BALANCER_READY_TIMEOUT_MS)) {
            error("ZiVPN load balancer did not open 127.0.0.1:$LOCAL_SOCKS_PORT")
            throw IllegalStateException("ZiVPN load balancer did not open 127.0.0.1:$LOCAL_SOCKS_PORT")
        }
        log("ZiVPN load balancer ready on 127.0.0.1:$LOCAL_SOCKS_PORT")
        monitor(lbProcess, "ZiVPN-LoadBalancer")
    }

    private fun buildCoreConfig(
        server: String,
        portRange: String,
        password: String,
        obfs: String,
        socksPort: Int,
    ): File {
        val file = File(context.filesDir, "zivpn_core_$socksPort.json")
        val json = """
            {
              "server": "$server:$portRange",
              "obfs": "$obfs",
              "auth": "$password",
              "loglevel": "warning",
              "socks5": { "listen": "127.0.0.1:$socksPort" },
              "insecure": true,
              "recvwindowconn": 131072,
              "recvwindow": 327680
            }
        """.trimIndent()
        file.writeText(json)
        return file
    }

    private fun startPdnsd() {
        val pdnsdBin = requireExecutable(File(Pdnsd.getExecutable(context)), "pdnsd")
        val pdnsdConf = Pdnsd.writeConfig(context, listenPort = PDNSD_PORT)
        log("Starting ZiVPN DNS gateway pdnsd on 127.0.0.1:$PDNSD_PORT")
        val process = ProcessBuilder(listOf(pdnsdBin.absolutePath, "-g", "-c", pdnsdConf))
            .directory(context.filesDir)
            .redirectErrorStream(true)
            .start()
        processes.add(process)
        captureLog(process, "ZiVPN-Pdnsd")
        monitor(process, "ZiVPN-Pdnsd")
        log("ZiVPN DNS gateway launched")
    }

    private fun startTun2Socks(nativeDir: String, mtu: Int, enableUdpGw: Boolean, udpgwPort: Int) {
        val tun2socks = requireExecutable(File(nativeDir, "libtun2socks.so"), "tun2socks")
        val command = arrayListOf(
            tun2socks.absolutePath,
            "--netif-ipaddr", "169.254.1.2",
            "--netif-netmask", "255.255.255.0",
            "--socks-server-addr", "127.0.0.1:$LOCAL_SOCKS_PORT",
            "--tunmtu", mtu.toString(),
            "--loglevel", "info",
            "--dnsgw", "169.254.1.1:$PDNSD_PORT",
            "--fake-proc",
            "--tcp-snd-buf", "131072",
            "--tcp-wnd", "131072",
            "--socks-buf", "262144",
        )
        if (enableUdpGw) {
            log("ZiVPN UDPGW enabled: 127.0.0.1:$udpgwPort")
            command.add("--udpgw-remote-server-addr")
            command.add("127.0.0.1:$udpgwPort")
            command.add("--udpgw-max-connections")
            command.add("512")
            command.add("--udpgw-connection-buffer-size")
            command.add("32")
            command.add("--udpgw-transparent-dns")
        } else {
            log("ZiVPN UDPGW disabled")
        }
        log("Starting ZiVPN tun2socks: mtu=$mtu socks=127.0.0.1:$LOCAL_SOCKS_PORT dns=169.254.1.1:$PDNSD_PORT")
        val process = startProcess("ZiVPN-Tun2Socks", command, nativeDir)
        monitor(process, "ZiVPN-Tun2Socks")
    }

    private fun sendTunFdWithRetry(fd: ParcelFileDescriptor): Boolean {
        repeat(5) { attempt ->
            Thread.sleep(if (attempt == 0) 1000 else 300)
            if (sendTunFd(fd)) {
                log("ZiVPN TUN fd handoff success")
                return true
            }
            warn("ZiVPN TUN fd handoff retry ${attempt + 1}/5 failed")
        }
        return false
    }

    private fun sendTunFd(fd: ParcelFileDescriptor): Boolean {
        return runCatching {
            LocalSocket().use { socket ->
                socket.connect(
                    LocalSocketAddress(
                        "/data/data/${context.packageName}/sock_path",
                        LocalSocketAddress.Namespace.FILESYSTEM,
                    ),
                )
                socket.setFileDescriptorsForSend(arrayOf(fd.fileDescriptor))
                socket.outputStream.write(42)
                socket.outputStream.flush()
                socket.setFileDescriptorsForSend(null)
            }
        }.isSuccess
    }

    private fun startProcess(name: String, command: List<String>, nativeDir: String): Process {
        val process = ProcessBuilder(command)
            .directory(context.filesDir)
            .redirectErrorStream(true)
            .apply { environment()["LD_LIBRARY_PATH"] = nativeDir }
            .start()
        processes.add(process)
        captureLog(process, name)
        log("$name started")
        return process
    }

    private fun captureLog(process: Process, name: String) {
        Thread {
            runCatching {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.take(120).forEach { line ->
                        if (line.isNotBlank()) log("$name: $line")
                    }
                }
            }
        }.apply { isDaemon = true }.start()
    }

    private fun monitor(process: Process, name: String) {
        Thread {
            val exit = runCatching { process.waitFor() }.getOrDefault(-1)
            if (!stopping) {
                val level = if (exit == 0) "info" else "warning"
                State.emitLog("$name exited: $exit", level)
            }
        }.apply { isDaemon = true }.start()
    }

    private fun log(message: String) {
        State.emitLog(message, "info")
    }

    private fun warn(message: String) {
        State.emitLog(message, "warning")
    }

    private fun error(message: String) {
        State.emitLog(message, "error")
    }

    private fun waitForLocalPort(port: Int, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline && !stopping) {
            try {
                Socket().use { socket ->
                    socket.connect(InetSocketAddress("127.0.0.1", port), 250)
                    return true
                }
            } catch (_: SocketTimeoutException) {
                Thread.sleep(100)
            } catch (_: Exception) {
                Thread.sleep(100)
            }
        }
        return false
    }

    private fun requireExecutable(file: File, label: String): File {
        if (!file.exists() || file.length() <= 0L) throw IllegalStateException("$label missing: ${file.absolutePath}")
        if (!file.canExecute()) file.setExecutable(true, true)
        if (!file.canExecute()) throw IllegalStateException("$label is not executable: ${file.absolutePath}")
        return file
    }

    companion object {
        private const val LOCAL_SOCKS_PORT = 7777
        private const val FIRST_CORE_PORT = 7781
        private const val PDNSD_PORT = 8091
        private const val CORE_READY_TIMEOUT_MS = 8000L
        private const val LOAD_BALANCER_READY_TIMEOUT_MS = 5000L
        private const val DEFAULT_OBFS = "hu``hqb`c"
    }
}
