package com.ringapp

import android.os.ParcelUuid
import java.util.UUID

/**
 * 指环 BLE 协议配置
 *
 * 指环已有固件，BLE 协议固定。此配置类定义了 App 如何与指环通信。
 * 如果你的指环使用了不同的 UUID，修改这里的常量即可（无需改业务代码）。
 *
 * 要更新配置：直接修改 [DEFAULT] 对象中的对应字段。
 */
data class RingBLEConfig(
    /** 指环 BLE Service UUID */
    val serviceUuid: UUID,
    /** 震动指令 Characteristic UUID （App 写入此特征值发送震动指令） */
    val vibrationCharUuid: UUID,
    /** 通知 Characteristic UUID（指环向 App 回传状态，可为 null） */
    val notifyCharUuid: UUID? = null,
    /** 扫描时按设备名过滤的前缀列表 */
    val scanNamePrefixes: List<String> = listOf("Ring", "SmartRing", "指环", "VibrationRing"),
    /** 扫描时按 Service UUID 过滤（可为 null = 不过滤） */
    val scanServiceUuid: UUID? = null,
) {
    companion object {
        /**
         * 默认配置 — 请根据你的指环固件实际 UUID 修改！
         *
         * 以下 UUID 为占位值，你需要替换为指环固件中定义的实际 UUID。
         * 获取方式：
         * 1. 查看指环固件源码中的 Service/Characteristic UUID 定义
         * 2. 或使用 nRF Connect 等 BLE 调试工具扫描指环获取
         */
        val DEFAULT = RingBLEConfig(
            serviceUuid = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb"),
            vibrationCharUuid = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb"),
            notifyCharUuid = null,
            scanNamePrefixes = listOf("Ring", "SmartRing", "指环", "VibrationRing", "BLE_RING"),
            scanServiceUuid = null,
        )
    }
}
