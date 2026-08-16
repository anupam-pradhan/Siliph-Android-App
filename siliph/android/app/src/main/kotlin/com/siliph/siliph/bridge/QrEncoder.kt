package com.siliph.siliph.bridge

import kotlin.math.abs

/**
 * QR Code Model 2 generator: byte mode, versions 1..40, all four error
 * correction levels, automatic mask selection.
 *
 * Ported to Kotlin from Project Nayuki's QR Code generator library
 * (MIT License), java/src/main/java/io/nayuki/qrcodegen/QrCode.java and
 * QrSegment.java (master branch). The capacity tables and algorithms are
 * unchanged; only the API was trimmed to what Siliph needs (one byte-mode
 * segment, no numeric/alphanumeric/kanji modes). See docs/reuse-records.md
 * Record 7 for the source modification record.
 */
internal object QrEncoder {

    /** Error correction level; declaration order matters (low -> high). */
    enum class Ecc(val formatBits: Int) {
        LOW(1), MEDIUM(0), QUARTILE(3), HIGH(2);
    }

    class DataTooLongException(message: String) : RuntimeException(message)

    /** Immutable square module grid; true = dark. */
    class Matrix internal constructor(
        val version: Int,
        ecl: Ecc,
        dataCodewords: ByteArray,
    ) {
        val size: Int = version * 4 + 17
        private val modules = Array(size) { BooleanArray(size) }
        private val isFunction = Array(size) { BooleanArray(size) }

        init {
            require(dataCodewords.size == getNumDataCodewords(version, ecl)) {
                "Data length mismatch"
            }
            drawFunctionPatterns(ecl)
            val allCodewords = addEccAndInterleave(dataCodewords, ecl)
            drawCodewords(allCodewords)

            // Automatically choose the mask with the lowest penalty.
            var mask = 0
            var minPenalty = Int.MAX_VALUE
            for (candidate in 0 until 8) {
                applyMask(candidate)
                drawFormatBits(candidate, ecl)
                val penalty = getPenaltyScore()
                if (penalty < minPenalty) {
                    mask = candidate
                    minPenalty = penalty
                }
                applyMask(candidate) // XOR undoes the mask.
            }
            applyMask(mask)
            drawFormatBits(mask, ecl)
        }

        fun isDark(x: Int, y: Int): Boolean = modules[y][x]

        private fun drawFunctionPatterns(ecl: Ecc) {
            for (i in 0 until size) {
                setFunctionModule(6, i, i % 2 == 0)
                setFunctionModule(i, 6, i % 2 == 0)
            }
            drawFinderPattern(3, 3)
            drawFinderPattern(size - 4, 3)
            drawFinderPattern(3, size - 4)

            val alignPatPos = getAlignmentPatternPositions(version, size)
            val numAlign = alignPatPos.size
            for (i in 0 until numAlign) {
                for (j in 0 until numAlign) {
                    val overlapsFinder = (i == 0 && j == 0) ||
                        (i == 0 && j == numAlign - 1) ||
                        (i == numAlign - 1 && j == 0)
                    if (!overlapsFinder) {
                        drawAlignmentPattern(alignPatPos[i], alignPatPos[j])
                    }
                }
            }
            drawFormatBits(0, ecl) // Dummy; overwritten after masking.
            drawVersion()
        }

        private fun drawFormatBits(msk: Int, ecl: Ecc) {
            val data = ecl.formatBits shl 3 or msk
            var rem = data
            for (i in 0 until 10) {
                rem = (rem shl 1) xor ((rem ushr 9) * 0x537)
            }
            val bits = (data shl 10 or rem) xor 0x5412

            for (i in 0..5) setFunctionModule(8, i, getBit(bits, i))
            setFunctionModule(8, 7, getBit(bits, 6))
            setFunctionModule(8, 8, getBit(bits, 7))
            setFunctionModule(7, 8, getBit(bits, 8))
            for (i in 9 until 15) setFunctionModule(14 - i, 8, getBit(bits, i))

            for (i in 0 until 8) setFunctionModule(size - 1 - i, 8, getBit(bits, i))
            for (i in 8 until 15) setFunctionModule(8, size - 15 + i, getBit(bits, i))
            setFunctionModule(8, size - 8, true) // Always dark.
        }

        private fun drawVersion() {
            if (version < 7) return
            var rem = version
            for (i in 0 until 12) {
                rem = (rem shl 1) xor ((rem ushr 11) * 0x1F25)
            }
            val bits = version shl 12 or rem
            for (i in 0 until 18) {
                val bit = getBit(bits, i)
                val a = size - 11 + i % 3
                val b = i / 3
                setFunctionModule(a, b, bit)
                setFunctionModule(b, a, bit)
            }
        }

        private fun drawFinderPattern(x: Int, y: Int) {
            for (dy in -4..4) {
                for (dx in -4..4) {
                    val dist = maxOf(abs(dx), abs(dy))
                    val xx = x + dx
                    val yy = y + dy
                    if (xx in 0 until size && yy in 0 until size) {
                        setFunctionModule(xx, yy, dist != 2 && dist != 4)
                    }
                }
            }
        }

        private fun drawAlignmentPattern(x: Int, y: Int) {
            for (dy in -2..2) {
                for (dx in -2..2) {
                    setFunctionModule(x + dx, y + dy, maxOf(abs(dx), abs(dy)) != 1)
                }
            }
        }

        private fun setFunctionModule(x: Int, y: Int, isDark: Boolean) {
            modules[y][x] = isDark
            isFunction[y][x] = true
        }

        private fun addEccAndInterleave(data: ByteArray, ecl: Ecc): ByteArray {
            val numBlocks = NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][version]
            val blockEccLen = ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][version]
            val rawCodewords = getNumRawDataModules(version) / 8
            val numShortBlocks = numBlocks - rawCodewords % numBlocks
            val shortBlockLen = rawCodewords / numBlocks

            val blocks = Array(numBlocks) { ByteArray(0) }
            val rsDiv = reedSolomonComputeDivisor(blockEccLen)
            var k = 0
            for (i in 0 until numBlocks) {
                val datLen = shortBlockLen - blockEccLen + if (i < numShortBlocks) 0 else 1
                val dat = data.copyOfRange(k, k + datLen)
                k += dat.size
                val block = dat.copyOf(shortBlockLen + 1)
                val ecc = reedSolomonComputeRemainder(dat, rsDiv)
                ecc.copyInto(block, block.size - blockEccLen)
                blocks[i] = block
            }

            val result = ByteArray(rawCodewords)
            var out = 0
            for (i in blocks[0].indices) {
                for (j in blocks.indices) {
                    // Skip the padding byte in short blocks.
                    if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) {
                        result[out++] = blocks[j][i]
                    }
                }
            }
            return result
        }

        private fun drawCodewords(data: ByteArray) {
            require(data.size == getNumRawDataModules(version) / 8) {
                "Codeword length mismatch"
            }
            var i = 0
            var right = size - 1
            while (right >= 1) {
                if (right == 6) right = 5
                for (vert in 0 until size) {
                    for (j in 0..1) {
                        val x = right - j
                        val upward = ((right + 1) and 2) == 0
                        val y = if (upward) size - 1 - vert else vert
                        if (!isFunction[y][x] && i < data.size * 8) {
                            modules[y][x] = getBit(data[i ushr 3].toInt(), 7 - (i and 7))
                            i++
                        }
                    }
                }
                right -= 2
            }
        }

        private fun applyMask(msk: Int) {
            for (y in 0 until size) {
                for (x in 0 until size) {
                    val invert = when (msk) {
                        0 -> (x + y) % 2 == 0
                        1 -> y % 2 == 0
                        2 -> x % 3 == 0
                        3 -> (x + y) % 3 == 0
                        4 -> (x / 3 + y / 2) % 2 == 0
                        5 -> x * y % 2 + x * y % 3 == 0
                        6 -> (x * y % 2 + x * y % 3) % 2 == 0
                        else -> ((x + y) % 2 + x * y % 3) % 2 == 0
                    }
                    modules[y][x] = modules[y][x] xor (invert && !isFunction[y][x])
                }
            }
        }

        private fun getPenaltyScore(): Int {
            var result = 0

            // Adjacent modules in row having same color, and finder-like patterns.
            for (y in 0 until size) {
                var runColor = false
                var runX = 0
                val runHistory = IntArray(7)
                for (x in 0 until size) {
                    if (modules[y][x] == runColor) {
                        runX++
                        if (runX == 5) result += PENALTY_N1
                        else if (runX > 5) result++
                    } else {
                        finderPenaltyAddHistory(runX, runHistory)
                        if (!runColor) {
                            result += finderPenaltyCountPatterns(runHistory) * PENALTY_N3
                        }
                        runColor = modules[y][x]
                        runX = 1
                    }
                }
                result += finderPenaltyTerminateAndCount(runColor, runX, runHistory) * PENALTY_N3
            }
            // Adjacent modules in column having same color, and finder-like patterns.
            for (x in 0 until size) {
                var runColor = false
                var runY = 0
                val runHistory = IntArray(7)
                for (y in 0 until size) {
                    if (modules[y][x] == runColor) {
                        runY++
                        if (runY == 5) result += PENALTY_N1
                        else if (runY > 5) result++
                    } else {
                        finderPenaltyAddHistory(runY, runHistory)
                        if (!runColor) {
                            result += finderPenaltyCountPatterns(runHistory) * PENALTY_N3
                        }
                        runColor = modules[y][x]
                        runY = 1
                    }
                }
                result += finderPenaltyTerminateAndCount(runColor, runY, runHistory) * PENALTY_N3
            }

            // 2x2 blocks of modules having same color.
            for (y in 0 until size - 1) {
                for (x in 0 until size - 1) {
                    val color = modules[y][x]
                    if (color == modules[y][x + 1] &&
                        color == modules[y + 1][x] &&
                        color == modules[y + 1][x + 1]
                    ) {
                        result += PENALTY_N2
                    }
                }
            }

            // Balance of dark and light modules.
            var dark = 0
            for (row in modules) {
                for (color in row) {
                    if (color) dark++
                }
            }
            val total = size * size
            val k = (abs(dark * 20 - total * 10) + total - 1) / total - 1
            result += k * PENALTY_N4
            return result
        }

        private fun finderPenaltyCountPatterns(runHistory: IntArray): Int {
            val n = runHistory[1]
            val core = n > 0 && runHistory[2] == n && runHistory[3] == n * 3 &&
                runHistory[4] == n && runHistory[5] == n
            return (if (core && runHistory[0] >= n * 4 && runHistory[6] >= n) 1 else 0) +
                (if (core && runHistory[6] >= n * 4 && runHistory[0] >= n) 1 else 0)
        }

        private fun finderPenaltyTerminateAndCount(
            currentRunColor: Boolean,
            currentRunLength: Int,
            runHistory: IntArray,
        ): Int {
            var runLength = currentRunLength
            if (currentRunColor) {
                finderPenaltyAddHistory(runLength, runHistory)
                runLength = 0
            }
            runLength += size // Add light border to final run.
            finderPenaltyAddHistory(runLength, runHistory)
            return finderPenaltyCountPatterns(runHistory)
        }

        private fun finderPenaltyAddHistory(currentRunLength: Int, runHistory: IntArray) {
            var length = currentRunLength
            if (runHistory[0] == 0) length += size // Add light border to initial run.
            System.arraycopy(runHistory, 0, runHistory, 1, runHistory.size - 1)
            runHistory[0] = length
        }
    }

    /** Encodes [text] as a single byte-mode segment at [ecl]. */
    fun encode(text: String, ecl: Ecc): Matrix {
        val data = text.toByteArray(Charsets.UTF_8)
        var level = ecl

        // Find the minimal version that fits.
        var version = 1
        var dataUsedBits: Int
        while (true) {
            val ccBits = byteModeCharCountBits(version)
            dataUsedBits = if (data.size >= (1 shl ccBits)) {
                -1
            } else {
                4 + ccBits + data.size * 8
            }
            if (dataUsedBits != -1 && dataUsedBits <= getNumDataCodewords(version, level) * 8) {
                break
            }
            if (version >= 40) {
                throw DataTooLongException(
                    "Data length = ${data.size} bytes exceeds QR capacity"
                )
            }
            version++
        }

        // Boost the error correction level while it still fits.
        for (candidate in Ecc.values()) {
            if (dataUsedBits <= getNumDataCodewords(version, candidate) * 8) {
                level = candidate
            }
        }

        val bits = BitBuffer()
        bits.appendBits(0x4, 4) // Byte mode indicator.
        bits.appendBits(data.size, byteModeCharCountBits(version))
        for (b in data) bits.appendBits(b.toInt() and 0xFF, 8)

        val capacityBits = getNumDataCodewords(version, level) * 8
        bits.appendBits(0, minOf(4, capacityBits - bits.bitLength))
        bits.appendBits(0, (8 - bits.bitLength % 8) % 8)
        var padByte = 0xEC
        while (bits.bitLength < capacityBits) {
            bits.appendBits(padByte, 8)
            padByte = padByte xor 0xEC xor 0x11
        }

        val dataCodewords = ByteArray(bits.bitLength / 8)
        for (i in 0 until bits.bitLength) {
            if (bits[i]) {
                dataCodewords[i shr 3] =
                    (dataCodewords[i shr 3].toInt() or (0x80 ushr (i and 7))).toByte()
            }
        }
        return Matrix(version, level, dataCodewords)
    }

    private fun byteModeCharCountBits(version: Int): Int = if (version < 10) 8 else 16

    private fun getAlignmentPatternPositions(version: Int, size: Int): IntArray {
        if (version == 1) return IntArray(0)
        val numAlign = version / 7 + 2
        val step = (version * 8 + numAlign * 3 + 5) / (numAlign * 4 - 4) * 2
        val result = IntArray(numAlign)
        result[0] = 6
        var pos = size - 7
        for (i in result.size - 1 downTo 1) {
            result[i] = pos
            pos -= step
        }
        return result
    }

    private fun getNumRawDataModules(ver: Int): Int {
        require(ver in 1..40) { "Version number out of range" }
        val size = ver * 4 + 17
        var result = size * size
        result -= 8 * 8 * 3
        result -= 15 * 2 + 1
        result -= (size - 16) * 2
        if (ver >= 2) {
            val numAlign = ver / 7 + 2
            result -= (numAlign - 1) * (numAlign - 1) * 25
            result -= (numAlign - 2) * 2 * 20
            if (ver >= 7) result -= 6 * 3 * 2
        }
        return result
    }

    fun getNumDataCodewords(ver: Int, ecl: Ecc): Int {
        return getNumRawDataModules(ver) / 8 -
            ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][ver] *
            NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][ver]
    }

    private fun reedSolomonComputeDivisor(degree: Int): ByteArray {
        require(degree in 1..255) { "Degree out of range" }
        val result = ByteArray(degree)
        result[degree - 1] = 1
        var root = 1
        for (i in 0 until degree) {
            for (j in result.indices) {
                result[j] = reedSolomonMultiply(result[j].toInt() and 0xFF, root).toByte()
                if (j + 1 < result.size) result[j] = (result[j].toInt() xor result[j + 1].toInt()).toByte()
            }
            root = reedSolomonMultiply(root, 0x02)
        }
        return result
    }

    private fun reedSolomonComputeRemainder(data: ByteArray, divisor: ByteArray): ByteArray {
        val result = ByteArray(divisor.size)
        for (b in data) {
            val factor = (b.toInt() xor result[0].toInt()) and 0xFF
            System.arraycopy(result, 1, result, 0, result.size - 1)
            result[result.size - 1] = 0
            for (i in result.indices) {
                result[i] = (result[i].toInt() xor reedSolomonMultiply(divisor[i].toInt() and 0xFF, factor)).toByte()
            }
        }
        return result
    }

    private fun reedSolomonMultiply(x: Int, y: Int): Int {
        var z = 0
        for (i in 7 downTo 0) {
            z = (z shl 1) xor ((z ushr 7) * 0x11D)
            z = z xor (((y ushr i) and 1) * x)
        }
        return z
    }

    private fun getBit(x: Int, i: Int): Boolean = ((x ushr i) and 1) != 0

    private const val PENALTY_N1 = 3
    private const val PENALTY_N2 = 3
    private const val PENALTY_N3 = 40
    private const val PENALTY_N4 = 10

    private val ECC_CODEWORDS_PER_BLOCK = arrayOf(
        // Index 0 is padding; versions 1..40 follow.
        intArrayOf(-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30), // Low
        intArrayOf(-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28), // Medium
        intArrayOf(-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30), // Quartile
        intArrayOf(-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30), // High
    )

    private val NUM_ERROR_CORRECTION_BLOCKS = arrayOf(
        intArrayOf(-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25), // Low
        intArrayOf(-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49), // Medium
        intArrayOf(-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68), // Quartile
        intArrayOf(-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81), // High
    )

    /** Growable bit string, MSB-first. */
    private class BitBuffer {
        private val bits = ArrayList<Boolean>()

        val bitLength: Int get() = bits.size

        fun appendBits(value: Int, len: Int) {
            for (i in len - 1 downTo 0) {
                bits.add(((value ushr i) and 1) != 0)
            }
        }

        operator fun get(index: Int): Boolean = bits[index]
    }
}
