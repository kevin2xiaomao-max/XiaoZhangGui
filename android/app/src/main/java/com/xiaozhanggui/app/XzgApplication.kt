package com.xiaozhanggui.app

import android.app.Application

/**
 * Application。对应 iOS `App/XiaoZhangGuiApp.swift` 的启动装配职责。
 *
 * Phase 2 接入：Room 数据库单例、DataStore、通知渠道创建、
 * 数据库失败显式报错（P0-2：绝不静默回退内存库）。
 */
class XzgApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
