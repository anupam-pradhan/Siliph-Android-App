package com.siliph.siliph.bridge

/**
 * Pre-flight heap check for heavy local processing.
 *
 * Reused from Karna14314/Pdf_Tools (Apache-2.0), file
 * app/src/main/java/com/yourname/pdftoolkit/util/MemoryGuard.kt at commit
 * bb4125bf89852527af4b74ace91c71fc87b8d7f3. See docs/reuse-records.md for
 * the full source modification record.
 */
object MemoryGuard {
    private const val MIN_FREE_MB = 40L

    fun checkMemory(operationName: String) {
        if (freeMemoryMb() < MIN_FREE_MB) {
            throw OutOfMemoryError(
                "Insufficient memory for $operationName: ${freeMemoryMb()}MB available"
            )
        }
    }

    fun freeMemoryMb(): Long {
        val rt = Runtime.getRuntime()
        return (rt.maxMemory() - rt.totalMemory() + rt.freeMemory()) / (1024 * 1024)
    }
}
