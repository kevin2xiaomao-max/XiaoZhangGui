package com.xiaozhanggui.app.data.ai

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * API Key 加密存储抽象（对应 iOS AIKeychain）。
 *
 * 实现约束（安全红线）：
 * - 唯一允许的生产实现是 [EncryptedApiKeyStore]（经 Android Keystore 的
 *   EncryptedSharedPreferences），密钥绝不以明文进入 DataStore / 日志 / 仓库 / artifact；
 * - 接口只做存取，不回显、不打印密钥值。
 */
interface ApiKeyStore {
    fun get(key: String): String
    fun put(key: String, value: String)
    fun remove(key: String)
}

/**
 * 生产实现：EncryptedSharedPreferences（Android Keystore，AES256_GCM）。
 * 对应 iOS `kSecAttrAccessibleAfterFirstUnlock` 的 Keychain 存储。
 */
class EncryptedApiKeyStore(context: Context) : ApiKeyStore {

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context, MasterKey.DEFAULT_MASTER_KEY_ALIAS)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            FILE_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override fun get(key: String): String = prefs.getString(key, "") ?: ""

    override fun put(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    override fun remove(key: String) {
        prefs.edit().remove(key).apply()
    }

    companion object {
        const val FILE_NAME = "ai_secrets"
    }
}
