package com.follow.clash.service.zivpn

import android.content.Context
import java.io.File

data class PdnsdTuning(
    val permCache: Int = 2048,
    val timeout: Int = 8,
    val minTtl: String = "15m",
    val maxTtl: String = "1w",
    val queryMethod: String = "tcp_only",
    val verbosity: Int = 1,
)

object Pdnsd {
    private val dnsHostRegex = Regex("^[A-Za-z0-9.-]+$")
    private val ttlRegex = Regex("^\\d+[smhdw]?$")
    private val queryMethods = setOf("udp_only", "tcp_only", "udp_tcp", "tcp_udp")

    fun getExecutable(context: Context): String {
        return File(context.applicationInfo.nativeLibraryDir, "libpdnsd.so").absolutePath
    }

    private fun sanitizeDnsEndpoint(value: String): Pair<String, String> {
        if (value.count { it == ':' } > 1) return "208.67.222.222" to "443"
        val parts = value.trim().split(":", limit = 2)
        val host = parts.getOrNull(0)
            ?.takeIf { it.isNotBlank() && dnsHostRegex.matches(it) }
            ?: "208.67.222.222"
        val port = parts.getOrNull(1)
            ?.toIntOrNull()
            ?.takeIf { it in 1..65535 }
            ?.toString()
            ?: "443"
        return host to port
    }

    private fun sanitizeTtl(value: String, fallback: String): String {
        return value.trim().takeIf { ttlRegex.matches(it) } ?: fallback
    }

    private fun sanitizeQueryMethod(value: String): String {
        return value.trim().takeIf { it in queryMethods } ?: "tcp_only"
    }

    fun writeConfig(
        context: Context,
        listenPort: Int,
        upstreamDns: String = "208.67.222.222:443,208.67.220.220:443",
        tuning: PdnsdTuning = PdnsdTuning(),
    ): String {
        val cacheDir = File(context.filesDir, "zivpn_pdnsd_cache")
        if (!cacheDir.exists()) cacheDir.mkdirs()
        val configFile = File(context.filesDir, "zivpn_pdnsd.conf")
        val dnsList = upstreamDns
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .ifEmpty { listOf("208.67.222.222:443", "208.67.220.220:443") }

        val serverBlocks = StringBuilder()
        dnsList.forEachIndexed { index, dns ->
            val (ip, port) = sanitizeDnsEndpoint(dns)
            serverBlocks.append(
                """
                server {
                    label= "upstream_$index";
                    ip = $ip;
                    port = $port;
                    timeout = ${tuning.timeout};
                    uptest = none;
                    proxy_only=on;
                }
                """.trimIndent()
            ).append('\n')
        }

        val conf = """
            global {
                perm_cache=${tuning.permCache};
                cache_dir="${cacheDir.absolutePath}";
                server_ip = 169.254.1.1;
                server_port = $listenPort;
                status_ctl = on;
                query_method=${sanitizeQueryMethod(tuning.queryMethod)};
                min_ttl=${sanitizeTtl(tuning.minTtl, "15m")};
                max_ttl=${sanitizeTtl(tuning.maxTtl, "1w")};
                timeout=${tuning.timeout};
                daemon=off;
                verbosity=${tuning.verbosity};
                par_queries=4;
            }

            $serverBlocks

            rr {
                name=localhost;
                reverse=on;
                a=127.0.0.1;
                owner=localhost;
                soa=localhost,root.localhost,42,86400,900,86400,86400;
            }
        """.trimIndent()
        configFile.writeText(conf)
        return configFile.absolutePath
    }
}
