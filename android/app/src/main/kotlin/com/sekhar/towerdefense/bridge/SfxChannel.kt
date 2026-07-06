package com.sekhar.towerdefense

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Codec-free, low-latency SFX engine.
 *
 * Earlier backends all routed audio through `MediaCodec`
 * (`c2.android.raw.decoder`): `MediaPlayer`-per-voice (crashed on codec
 * exhaustion), `audioplayers` (decoded per voice/shot), and even `SoundPool`
 * (decodes each clip through the codec framework at load). This engine removes
 * the codec entirely: the WAV files are parsed to raw 16-bit PCM in Kotlin and
 * fed straight into [AudioTrack] in MODE_STATIC. Playback is an immediate
 * `play()` on a pre-filled buffer — the lowest-latency path available — with no
 * decoder, no audio-focus management, and overlap handled by a small ring of
 * tracks per clip. All work runs on a dedicated audio thread so it never
 * touches the UI thread.
 *
 * Channel: `towerdefense/sfx`
 *  - `init`                            -> start the audio thread
 *  - `load`  {key, asset, voices}      -> parse a WAV once, build its tracks
 *  - `play`  {key, volume}             -> fire-and-forget playback
 *  - `dispose`                         -> release everything
 */
class SfxChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SfxChannel"
        private const val CHANNEL = "towerdefense/sfx"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val thread = HandlerThread("sfx-audio").apply { start() }
    private val handler = Handler(thread.looper)

    /** key -> a clip's round-robin ring of statically-loaded tracks. */
    private val clips = HashMap<String, Clip>()

    init {
        channel.setMethodCallHandler(this)
    }

    private class Clip(val tracks: List<AudioTrack>) {
        var cursor = 0
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> result.success(null)
            "load" -> {
                val key = call.argument<String>("key")
                val asset = call.argument<String>("asset")
                val voices = call.argument<Int>("voices") ?: 3
                if (key != null && asset != null) {
                    handler.post { loadClip(key, asset, voices.coerceIn(1, 6)) }
                }
                result.success(null)
            }
            "play" -> {
                val key = call.argument<String>("key")
                val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                if (key != null) {
                    handler.post { playClip(key, volume) }
                }
                result.success(null)
            }
            "dispose" -> {
                handler.post { disposeAll() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun loadClip(key: String, asset: String, voices: Int) {
        try {
            val lookupKey = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset(asset)
            val bytes = context.assets.open(lookupKey).use { it.readBytes() }
            val wav = parseWav(bytes)
            if (wav == null) {
                Log.w(TAG, "Unsupported/!16-bit WAV: $asset")
                return
            }
            if (wav.pcm.isEmpty()) {
                return
            }
            val channelMask = if (wav.channels >= 2) {
                AudioFormat.CHANNEL_OUT_STEREO
            } else {
                AudioFormat.CHANNEL_OUT_MONO
            }
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val format = AudioFormat.Builder()
                .setSampleRate(wav.sampleRate)
                .setEncoding(wav.encoding)
                .setChannelMask(channelMask)
                .build()

            val tracks = ArrayList<AudioTrack>(voices)
            for (i in 0 until voices) {
                // API 21-safe constructor (AudioTrack.Builder needs API 23).
                val track = AudioTrack(
                    attributes,
                    format,
                    wav.pcm.size,
                    AudioTrack.MODE_STATIC,
                    AudioManager.AUDIO_SESSION_ID_GENERATE,
                )
                if (track.state != AudioTrack.STATE_INITIALIZED) {
                    track.release()
                    continue
                }
                track.write(wav.pcm, 0, wav.pcm.size)
                tracks.add(track)
            }
            if (tracks.isEmpty()) {
                return
            }
            val old = clips.put(key, Clip(tracks))
            old?.tracks?.forEach { safeRelease(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load SFX '$asset': ${e.message}")
        }
    }

    private fun playClip(key: String, volume: Float) {
        val clip = clips[key] ?: return
        if (clip.tracks.isEmpty()) {
            return
        }
        val track = clip.tracks[clip.cursor]
        clip.cursor = (clip.cursor + 1) % clip.tracks.size
        val gain = volume.coerceIn(0f, 1f)
        try {
            if (track.playState != AudioTrack.PLAYSTATE_STOPPED) {
                track.stop()
            }
        } catch (_: Exception) {
        }
        // Rewind the static buffer to the start, set gain, then play.
        try {
            track.reloadStaticData()
        } catch (_: Exception) {
        }
        try {
            track.setVolume(gain)
        } catch (_: Exception) {
        }
        try {
            track.play()
        } catch (_: Exception) {
        }
    }

    private fun disposeAll() {
        for (clip in clips.values) {
            for (track in clip.tracks) {
                safeRelease(track)
            }
        }
        clips.clear()
    }

    private fun safeRelease(track: AudioTrack) {
        try {
            track.pause()
        } catch (_: Exception) {
        }
        try {
            track.flush()
        } catch (_: Exception) {
        }
        try {
            track.release()
        } catch (_: Exception) {
        }
    }

    /** Releases native resources and stops the audio thread. */
    fun dispose() {
        channel.setMethodCallHandler(null)
        handler.post {
            disposeAll()
            thread.quitSafely()
        }
    }

    // ---- Minimal RIFF/WAVE PCM parser -------------------------------------
    // Supports PCM 8/16/24-bit and 32-bit float, including WAVE_FORMAT_EXTENSIBLE
    // (0xFFFE). 24-bit is down-converted to 16-bit; the rest map straight to an
    // AudioTrack encoding. [encoding] is the chosen AudioFormat.ENCODING_* value.
    private class Wav(
        val sampleRate: Int,
        val channels: Int,
        val encoding: Int,
        val pcm: ByteArray,
    )

    private fun parseWav(b: ByteArray): Wav? {
        if (b.size < 44) {
            return null
        }
        fun tag(offset: Int): String = String(b, offset, 4, Charsets.US_ASCII)
        if (tag(0) != "RIFF" || tag(8) != "WAVE") {
            return null
        }
        val buffer = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)

        var sampleRate = 44100
        var channels = 1
        var bitsPerSample = 16
        var audioFormat = 1
        var effectiveFormat = 1
        var dataOffset = -1
        var dataLength = 0

        var pos = 12 // skip RIFF(4) + size(4) + WAVE(4)
        while (pos + 8 <= b.size) {
            val id = tag(pos)
            val size = buffer.getInt(pos + 4)
            val body = pos + 8
            if (size < 0) {
                break
            }
            when (id) {
                "fmt " -> {
                    if (body + 16 <= b.size) {
                        audioFormat = buffer.getShort(body).toInt() and 0xFFFF
                        channels = buffer.getShort(body + 2).toInt() and 0xFFFF
                        sampleRate = buffer.getInt(body + 4)
                        bitsPerSample = buffer.getShort(body + 14).toInt() and 0xFFFF
                        effectiveFormat = audioFormat
                        // WAVE_FORMAT_EXTENSIBLE: real format is the first 2 bytes
                        // of the sub-format GUID at body+24.
                        if (audioFormat == 0xFFFE && body + 26 <= b.size) {
                            effectiveFormat = buffer.getShort(body + 24).toInt() and 0xFFFF
                        }
                    }
                }
                "data" -> {
                    dataOffset = body
                    dataLength = size
                }
            }
            // Chunks are word-aligned (pad byte when size is odd).
            pos = body + size + (size and 1)
        }

        if (dataOffset < 0 || channels < 1) {
            return null
        }
        val end = minOf(dataOffset + dataLength, b.size)
        if (end <= dataOffset) {
            return null
        }
        val raw = b.copyOfRange(dataOffset, end)

        // format 1 = PCM, format 3 = IEEE float.
        return when {
            effectiveFormat == 1 && bitsPerSample == 16 ->
                Wav(sampleRate, channels, AudioFormat.ENCODING_PCM_16BIT, raw)
            effectiveFormat == 1 && bitsPerSample == 8 ->
                Wav(sampleRate, channels, AudioFormat.ENCODING_PCM_8BIT, raw)
            effectiveFormat == 1 && bitsPerSample == 24 ->
                Wav(sampleRate, channels, AudioFormat.ENCODING_PCM_16BIT, pcm24To16(raw))
            effectiveFormat == 3 && bitsPerSample == 32 ->
                Wav(sampleRate, channels, AudioFormat.ENCODING_PCM_FLOAT, raw)
            else -> {
                Log.w(
                    TAG,
                    "Unsupported WAV: format=$audioFormat eff=$effectiveFormat bits=$bitsPerSample",
                )
                null
            }
        }
    }

    /** Down-converts little-endian 24-bit PCM to 16-bit (keeps the top 2 bytes). */
    private fun pcm24To16(src: ByteArray): ByteArray {
        val frames = src.size / 3
        val out = ByteArray(frames * 2)
        var s = 0
        var d = 0
        while (s + 2 < src.size) {
            out[d] = src[s + 1]
            out[d + 1] = src[s + 2]
            s += 3
            d += 2
        }
        return out
    }
}
