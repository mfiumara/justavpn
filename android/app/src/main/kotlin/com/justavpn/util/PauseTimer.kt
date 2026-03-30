package com.justavpn.util

enum class PauseDuration(val seconds: Int, val label: String) {
    FIVE_MINUTES(300, "5 minutes"),
    FIFTEEN_MINUTES(900, "15 minutes"),
    ONE_HOUR(3600, "1 hour");
}
