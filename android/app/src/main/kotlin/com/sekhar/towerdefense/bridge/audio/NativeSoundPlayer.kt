package com.sekhar.towerdefense

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.SoundPool
import java.util.concurrent.ConcurrentHashMap

class NativeSoundPlayer(context: Context) {
    private val soundPool = SoundPool.Builder()
        .setMaxStreams(6)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()

    private val soundIds = ConcurrentHashMap<String, Int>()
    private val loadedIds = ConcurrentHashMap.newKeySet<Int>()
    private val pendingPlays = ConcurrentHashMap<String, Int>()

    init {
        soundPool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) {
                loadedIds.add(sampleId)
                val key = soundIds.entries.firstOrNull { it.value == sampleId }?.key
                if (key != null) {
                    val queued = pendingPlays.remove(key) ?: 0
                    repeat(queued.coerceAtMost(2)) {
                        playLoaded(sampleId)
                    }
                }
            }
        }

        preload(context, "boom", "assets/audio/boom.wav")
        preload(context, "missile", "assets/audio/missile.wav")
        preload(context, "pop", "assets/audio/pop.wav")
        preload(context, "railgun", "assets/audio/railgun.wav")
        preload(context, "sniper", "assets/audio/sniper.wav")
        preload(context, "spark", "assets/audio/spark.wav")
        preload(context, "taunt", "assets/audio/taunt.wav")
    }

    fun play(soundName: String, muted: Boolean) {
        if (muted || soundName.isBlank()) {
            return
        }
        val sampleId = soundIds[soundName] ?: return
        if (loadedIds.contains(sampleId)) {
            playLoaded(sampleId)
            return
        }
        pendingPlays[soundName] = (pendingPlays[soundName] ?: 0) + 1
    }

    fun release() {
        soundPool.release()
    }

    private fun preload(context: Context, name: String, assetPath: String) {
        openAssetFd(context, assetPath)?.use { afd ->
            val sampleId = soundPool.load(afd, 1)
            if (sampleId != 0) {
                soundIds[name] = sampleId
            }
        }
    }

    private fun playLoaded(sampleId: Int) {
        soundPool.play(sampleId, 0.7f, 0.7f, 1, 0, 1.0f)
    }

    private fun openAssetFd(context: Context, assetPath: String): AssetFileDescriptor? {
        return try {
            context.assets.openFd("flutter_assets/$assetPath")
        } catch (_: Throwable) {
            try {
                context.assets.openFd(assetPath)
            } catch (_: Throwable) {
                null
            }
        }
    }
}
