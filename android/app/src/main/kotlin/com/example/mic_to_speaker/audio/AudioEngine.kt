package com.example.mic_to_speaker.audio

import android.media.*
import kotlinx.coroutines.*
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tanh

data class EqBandParam(val freq: Int, val gainDb: Double)
data class DspParams(
    val eq: List<EqBandParam> = emptyList(),
    val pitch: Double = 1.0,
    val formant: Int = 0,
    val reverb: Boolean = false,
    val reverbWet: Double = 0.0,
    val echo: Boolean = false,
    val echoDelayMs: Int = 240,
    val echoFeedback: Double = 0.35,
    val volume: Double = 1.0,
    val voicePreset: String = "normal",
)

enum class VoicePreset {
    NORMAL, CHILD, FUNNY, ROBOT, DEEP, ALIEN;
    companion object {
        fun from(raw: String?): VoicePreset {
            return values().firstOrNull { it.name.equals(raw ?: "", ignoreCase = true) } ?: NORMAL
        }
    }
}

data class VoicePresetConfig(
    val ringMix: Double = 0.0,
    val ringFrequency: Double = 0.0,
    val vibratoDepth: Double = 0.0,
    val vibratoRate: Double = 0.0,
    val distortion: Double = 0.0,
    val phaseDistortion: Double = 0.0,
    val extraReverb: Double = 0.0,
    val delayMs: Int = 0,
    val delayMix: Double = 0.0,
    val delayFeedback: Double = 0.0,
    val bassGain: Double = 0.0,
    val trebleGain: Double = 0.0
)

class AudioEngine(
    private val onLevel: (Double) -> Unit
) {
    private var record: AudioRecord? = null
    private var track: AudioTrack? = null
    private var job: Job? = null
    private var sampleRate: Int = 44100
    @Volatile private var params = DspParams()
    private val eqFilters = Array(5) { Biquad() }
    @Volatile private var eqEnabled = false
    private var pitchShifter = PitchShiftState(44100 * 2)
    private var reverbProcessor = SimpleReverb(44100)
    private var echoProcessor = SimpleEcho(44100 * 2)
    private val voiceLowShelf = Biquad()
    private val voiceHighShelf = Biquad()
    private val formantFilter = Biquad()
    @Volatile private var voicePreset = VoicePreset.NORMAL
    @Volatile private var voiceConfig = VoicePresetConfig()
    private var vibratoPhase = 0.0
    private var ringPhase = 0.0
    private var alienPhase = 0.0

    fun apply(p: DspParams) {
        params = p
        updateEqFilters()
        voicePreset = VoicePreset.from(p.voicePreset)
        updateVoicePresetConfig()
        updateFormantFilter()
    }

    fun start(): Boolean {
        if (job != null) return true
        val sr = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC)
        val channelIn = AudioFormat.CHANNEL_IN_MONO
        val channelOut = AudioFormat.CHANNEL_OUT_MONO
        val fmt = AudioFormat.ENCODING_PCM_16BIT

        val recBuf = AudioRecord.getMinBufferSize(sr, channelIn, fmt).coerceAtLeast(4096)
        val playBuf = AudioTrack.getMinBufferSize(sr, channelOut, fmt).coerceAtLeast(4096)

        record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, // low AGC
            sr, channelIn, fmt, recBuf
        )
        track = AudioTrack(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build(),
            AudioFormat.Builder().setEncoding(fmt).setChannelMask(channelOut).setSampleRate(sr).build(),
            playBuf,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE
        )

        if (record?.state != AudioRecord.STATE_INITIALIZED || track?.state != AudioTrack.STATE_INITIALIZED) {
            stop(); return false
        }

        record?.startRecording()
        track?.play()
        sampleRate = sr
        resetProcessorsForSampleRate()
        updateEqFilters()
        updateVoicePresetConfig()
        updateFormantFilter()

        job = CoroutineScope(Dispatchers.Default).launch {
            val buf = ShortArray(1024)
            while (isActive) {
                val n = record?.read(buf, 0, buf.size) ?: 0
                if (n > 0) {
                    // simple RMS for VU
                    var sum = 0.0
                    for (i in 0 until n) { val s = buf[i].toDouble(); sum += s*s }
                    val rms = sqrt(sum / n) / 32768.0
                    onLevel(rms.coerceIn(0.0, 1.0))

                    // processing chain
                    val vol = params.volume.coerceIn(0.0, 1.0)
                    val eqOn = eqEnabled
                    val pitchFactor = params.pitch.coerceIn(0.5, 2.0)
                    val reverbMix = (((if (params.reverb) params.reverbWet else 0.0) + voiceConfig.extraReverb).coerceIn(0.0, 1.0))
                    val delayMsBase = if (params.echo) params.echoDelayMs else 0
                    val delayMixBase = if (params.echo) 0.35 else 0.0
                    val delayFeedbackBase = if (params.echo) params.echoFeedback else 0.0
                    val delayMs = maxOf(delayMsBase, voiceConfig.delayMs)
                    val delayMix = (delayMixBase + voiceConfig.delayMix).coerceIn(0.0, 1.0)
                    val delayFeedback = (delayFeedbackBase + voiceConfig.delayFeedback).coerceIn(0.0, 0.95)
                    val delaySamples = if (delayMs > 0) ((delayMs / 1000.0) * sampleRate).toInt().coerceAtLeast(1) else 0

                    for (i in 0 until n) {
                        var sample = buf[i].toDouble() / 32768.0
                        if (eqOn) {
                            for (filter in eqFilters) {
                                sample = filter.process(sample)
                            }
                        }
                        sample = formantFilter.process(sample)
                        sample = applyVoiceTransforms(sample, pitchFactor)
                        if (reverbMix > 0.0) {
                            sample = reverbProcessor.process(sample, reverbMix)
                        }
                        if (delaySamples > 0 && delayMix > 0.0) {
                            sample = echoProcessor.process(sample, delaySamples, delayFeedback, delayMix)
                        }
                        sample *= vol
                        val v = (sample * 32767.0).toInt()
                            .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                        buf[i] = v.toShort()
                    }

                    track?.write(buf, 0, n)
                }
            }
        }
        return true
    }

    fun stop() {
        job?.cancel(); job = null
        try { record?.stop() } catch (_: Throwable) {}
        try { track?.stop() } catch (_: Throwable) {}
        record?.release(); record = null
        track?.release(); track = null
    }

    private fun updateEqFilters() {
        val sr = sampleRate
        if (sr <= 0) return
        val bands = params.eq
        var enabled = false
        for (i in eqFilters.indices) {
            val band = bands.getOrNull(i)
            val gain = band?.gainDb ?: 0.0
            val freq = band?.freq?.toDouble() ?: 0.0
            if (abs(gain) < 0.01 || freq <= 0.0) {
                eqFilters[i].setBypass()
            } else {
                eqFilters[i].setPeaking(freq, gain, 1.0, sr)
                if (!enabled) enabled = true
            }
        }
        eqEnabled = enabled
    }

    private fun applyVoiceTransforms(input: Double, pitchFactor: Double): Double {
        var sample = pitchShifter.process(input, pitchFactor)
        val cfg = voiceConfig
        if (cfg.vibratoDepth > 0 && cfg.vibratoRate > 0 && sampleRate > 0) {
            vibratoPhase += 2 * PI * cfg.vibratoRate / sampleRate
            if (vibratoPhase > 2 * PI) vibratoPhase -= 2 * PI
            val trem = 1.0 + cfg.vibratoDepth * sin(vibratoPhase)
            sample *= trem
        }
        if (cfg.ringMix > 0 && cfg.ringFrequency > 0 && sampleRate > 0) {
            ringPhase += 2 * PI * cfg.ringFrequency / sampleRate
            if (ringPhase > 2 * PI) ringPhase -= 2 * PI
            val mod = sin(ringPhase)
            sample = (1 - cfg.ringMix) * sample + cfg.ringMix * (sample * mod)
        }
        if (cfg.distortion > 0) {
            val drive = 1 + cfg.distortion * 6
            sample = tanh(sample * drive)
        }
        if (cfg.phaseDistortion > 0 && sampleRate > 0) {
            alienPhase += 2 * PI * 0.4 / sampleRate
            if (alienPhase > 2 * PI) alienPhase -= 2 * PI
            val warp = 1 + cfg.phaseDistortion * sin(alienPhase)
            sample = sin(sample * warp)
        }
        sample = voiceLowShelf.process(sample)
        sample = voiceHighShelf.process(sample)
        return sample
    }

    private fun updateVoicePresetConfig() {
        voiceConfig = when (voicePreset) {
            VoicePreset.CHILD -> VoicePresetConfig(
                vibratoDepth = 0.02,
                vibratoRate = 5.0,
                extraReverb = 0.2,
                bassGain = -2.0,
                trebleGain = 3.0
            )
            VoicePreset.FUNNY -> VoicePresetConfig(
                vibratoDepth = 0.06,
                vibratoRate = 6.5,
                ringMix = 0.1,
                ringFrequency = 120.0,
                delayMs = 90,
                delayMix = 0.25,
                delayFeedback = 0.2,
                trebleGain = 1.5
            )
            VoicePreset.ROBOT -> VoicePresetConfig(
                ringMix = 0.65,
                ringFrequency = 55.0,
                distortion = 0.6,
                extraReverb = 0.35,
                delayMs = 210,
                delayMix = 0.35,
                delayFeedback = 0.45,
                bassGain = 2.0
            )
            VoicePreset.DEEP -> VoicePresetConfig(
                extraReverb = 0.12,
                bassGain = 5.0,
                trebleGain = -4.0
            )
            VoicePreset.ALIEN -> VoicePresetConfig(
                ringMix = 0.35,
                ringFrequency = 420.0,
                phaseDistortion = 0.7,
                extraReverb = 0.25,
                delayMs = 180,
                delayMix = 0.3,
                delayFeedback = 0.3,
                trebleGain = 2.0
            )
            VoicePreset.NORMAL -> VoicePresetConfig()
        }

        val sr = sampleRate
        if (sr <= 0) {
            voiceLowShelf.setBypass()
            voiceHighShelf.setBypass()
            return
        }
        if (abs(voiceConfig.bassGain) > 0.1) {
            voiceLowShelf.setLowShelf(180.0, voiceConfig.bassGain, sr)
        } else {
            voiceLowShelf.setBypass()
        }
        if (abs(voiceConfig.trebleGain) > 0.1) {
            voiceHighShelf.setHighShelf(3200.0, voiceConfig.trebleGain, sr)
        } else {
            voiceHighShelf.setBypass()
        }
    }

    private fun updateFormantFilter() {
        val sr = sampleRate
        if (sr <= 0) {
            formantFilter.setBypass()
            return
        }
        val formant = params.formant.coerceIn(-12, 12)
        if (formant == 0) {
            formantFilter.setBypass()
            return
        }
        val gain = formant.toDouble()
        if (formant > 0) {
            formantFilter.setLowShelf(250.0, gain * 0.6, sr)
        } else {
            formantFilter.setHighShelf(2500.0, -gain * 0.6, sr)
        }
    }

    private fun resetProcessorsForSampleRate() {
        val sr = sampleRate.coerceAtLeast(8000)
        pitchShifter = PitchShiftState(sr * 2)
        reverbProcessor = SimpleReverb(sr)
        echoProcessor = SimpleEcho(sr * 2)
    }
}

private class PitchShiftState(size: Int) {
    private var buffer = DoubleArray(size)
    private var writePos = 0
    private var readPos = 0.0
    private var minGap = (size * 0.4).toInt()

    fun reset(newSize: Int) {
        buffer = DoubleArray(newSize)
        writePos = 0
        readPos = 0.0
        minGap = (newSize * 0.4).toInt().coerceAtLeast(64)
    }

    fun process(input: Double, factor: Double): Double {
        val size = buffer.size
        if (size < 2) return input
        buffer[writePos] = input
        val normalFactor = factor.coerceIn(0.5, 2.0)
        var output = input

        if (readPos <= 0.0) {
            readPos = wrapIndex(writePos - minGap, size).toDouble()
        }

        if (abs(normalFactor - 1.0) > 0.02) {
            val base = readPos.toInt()
            val frac = readPos - base
            val next = (base + 1) % size
            output = buffer[base] * (1 - frac) + buffer[next] * frac
            readPos += normalFactor
            while (readPos >= size) readPos -= size.toDouble()
            val gap = distance(writePos, readPos, size)
            val minGapD = minGap.toDouble()
            val maxGap = (size - minGap).toDouble()
            if (gap < minGapD || gap > maxGap) {
                readPos = wrapIndex(writePos - minGap, size).toDouble()
            }
        } else {
            readPos = wrapIndex(writePos - minGap, size).toDouble()
            output = input
        }

        writePos = (writePos + 1) % size
        return output
    }

    private fun distance(write: Int, read: Double, size: Int): Double {
        val diff = (write - read + size) % size
        return if (diff < 0) diff + size else diff
    }
}

private class SimpleReverb(sampleRate: Int) {
    private val combs = arrayOf(
        CombFilter((0.0297 * sampleRate).toInt(), 0.78),
        CombFilter((0.0371 * sampleRate).toInt(), 0.75),
        CombFilter((0.0411 * sampleRate).toInt(), 0.70)
    )

    fun process(input: Double, mix: Double): Double {
        if (mix <= 0.0) return input
        var acc = 0.0
        for (comb in combs) {
            acc += comb.process(input)
        }
        val wet = acc / combs.size
        return input * (1 - mix) + wet * mix
    }
}

private class SimpleEcho(bufferSize: Int) {
    private var buffer = DoubleArray(bufferSize.coerceAtLeast(2048))
    private var index = 0

    fun process(input: Double, delaySamples: Int, feedback: Double, mix: Double): Double {
        if (delaySamples <= 0 || mix <= 0.0) return input
        if (delaySamples >= buffer.size - 1) {
            val newSize = (delaySamples * 1.5).toInt().coerceAtLeast(delaySamples + 1)
            buffer = DoubleArray(newSize)
            index = 0
        }
        val size = buffer.size
        val readIndex = wrapIndex(index - delaySamples, size)
        val delayed = buffer[readIndex]
        val out = input * (1 - mix) + delayed * mix
        buffer[index] = input + delayed * feedback
        index = (index + 1) % size
        return out
    }
}

private class CombFilter(length: Int, private val feedback: Double) {
    private val buffer = DoubleArray(length.coerceAtLeast(1))
    private var index = 0
    fun process(input: Double): Double {
        val out = buffer[index]
        buffer[index] = input + out * feedback
        index = (index + 1) % buffer.size
        return out
    }
}

private fun wrapIndex(value: Int, size: Int): Int {
    var v = value % size
    if (v < 0) v += size
    return v
}

private class Biquad {
    private var b0 = 1.0
    private var b1 = 0.0
    private var b2 = 0.0
    private var a1 = 0.0
    private var a2 = 0.0
    private var z1 = 0.0
    private var z2 = 0.0

    fun setBypass() {
        b0 = 1.0; b1 = 0.0; b2 = 0.0
        a1 = 0.0; a2 = 0.0
        z1 = 0.0; z2 = 0.0
    }

    fun setPeaking(freq: Double, gainDb: Double, q: Double, sampleRate: Int) {
        if (freq <= 0.0 || sampleRate <= 0) { setBypass(); return }
        val A = 10.0.pow(gainDb / 40.0)
        val omega = 2.0 * PI * freq / sampleRate
        val sinW = sin(omega)
        val cosW = cos(omega)
        val alpha = sinW / (2.0 * q.coerceAtLeast(0.1))

        var b0 = 1 + alpha * A
        var b1 = -2 * cosW
        var b2 = 1 - alpha * A
        val a0 = 1 + alpha / A
        var a1 = -2 * cosW
        var a2 = 1 - alpha / A

        b0 /= a0; b1 /= a0; b2 /= a0
        a1 /= a0; a2 /= a0

        this.b0 = b0; this.b1 = b1; this.b2 = b2
        this.a1 = a1; this.a2 = a2
        z1 = 0.0; z2 = 0.0
    }

    fun setLowShelf(freq: Double, gainDb: Double, sampleRate: Int) {
        if (sampleRate <= 0) { setBypass(); return }
        val A = 10.0.pow(gainDb / 40.0)
        val omega = 2.0 * PI * freq / sampleRate
        val sinW = sin(omega)
        val cosW = cos(omega)
        val beta = 2.0 * sqrt(A) * sinW / 2.0

        var b0 = A * ((A + 1) - (A - 1) * cosW + beta)
        var b1 = 2 * A * ((A - 1) - (A + 1) * cosW)
        var b2 = A * ((A + 1) - (A - 1) * cosW - beta)
        val a0 = (A + 1) + (A - 1) * cosW + beta
        var a1 = -2 * ((A - 1) + (A + 1) * cosW)
        var a2 = (A + 1) + (A - 1) * cosW - beta

        b0 /= a0; b1 /= a0; b2 /= a0
        a1 /= a0; a2 /= a0

        this.b0 = b0; this.b1 = b1; this.b2 = b2
        this.a1 = a1; this.a2 = a2
    }

    fun setHighShelf(freq: Double, gainDb: Double, sampleRate: Int) {
        if (sampleRate <= 0) { setBypass(); return }
        val A = 10.0.pow(gainDb / 40.0)
        val omega = 2.0 * PI * freq / sampleRate
        val sinW = sin(omega)
        val cosW = cos(omega)
        val beta = 2.0 * sqrt(A) * sinW / 2.0

        var b0 = A * ((A + 1) + (A - 1) * cosW + beta)
        var b1 = -2 * A * ((A - 1) + (A + 1) * cosW)
        var b2 = A * ((A + 1) + (A - 1) * cosW - beta)
        val a0 = (A + 1) - (A - 1) * cosW + beta
        var a1 = 2 * ((A - 1) - (A + 1) * cosW)
        var a2 = (A + 1) - (A - 1) * cosW - beta

        b0 /= a0; b1 /= a0; b2 /= a0
        a1 /= a0; a2 /= a0

        this.b0 = b0; this.b1 = b1; this.b2 = b2
        this.a1 = a1; this.a2 = a2
    }

    fun process(x: Double): Double {
        val y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}
