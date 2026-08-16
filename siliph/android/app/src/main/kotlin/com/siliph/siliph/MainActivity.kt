package com.siliph.siliph

import android.content.Intent
import com.siliph.siliph.bridge.FileAccessApi
import com.siliph.siliph.bridge.FileAccessBridge
import com.siliph.siliph.bridge.FileResultsApi
import com.siliph.siliph.bridge.FileToolsApi
import com.siliph.siliph.bridge.FileToolsBridge
import com.siliph.siliph.bridge.ImageToolsApi
import com.siliph.siliph.bridge.ImageToolsBridge
import com.siliph.siliph.bridge.OcrApi
import com.siliph.siliph.bridge.OcrBridge
import com.siliph.siliph.bridge.PdfApi
import com.siliph.siliph.bridge.PdfBridge
import com.siliph.siliph.bridge.TaskEventsApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var pdfBridge: PdfBridge? = null
    private var fileAccessBridge: FileAccessBridge? = null
    private var fileToolsBridge: FileToolsBridge? = null
    private var imageToolsBridge: ImageToolsBridge? = null
    private var ocrBridge: OcrBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor

        val fileResults = FileResultsApi(messenger)
        val taskEvents = TaskEventsApi(messenger)

        val fileAccess = FileAccessBridge(this, fileResults)
        fileAccessBridge = fileAccess
        FileAccessApi.setUp(messenger, fileAccess)

        val pdf = PdfBridge(applicationContext, taskEvents)
        pdfBridge = pdf
        PdfApi.setUp(messenger, pdf)

        val fileTools = FileToolsBridge(applicationContext, taskEvents)
        fileToolsBridge = fileTools
        FileToolsApi.setUp(messenger, fileTools)

        val imageTools = ImageToolsBridge(applicationContext, taskEvents)
        imageToolsBridge = imageTools
        ImageToolsApi.setUp(messenger, imageTools)

        val ocr = OcrBridge(applicationContext, taskEvents)
        ocrBridge = ocr
        OcrApi.setUp(messenger, ocr)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        fileAccessBridge?.handleActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        pdfBridge?.shutdown()
        fileToolsBridge?.shutdown()
        imageToolsBridge?.shutdown()
        ocrBridge?.shutdown()
        super.onDestroy()
    }
}
