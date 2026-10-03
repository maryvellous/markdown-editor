package dev.diaspro.diaspro_markdown_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dev.diaspro.markdown/files"
        private const val OPEN_REQUEST = 4101
        private const val CREATE_REQUEST = 4102
        private const val PREFS_NAME = "diaspro_markdown"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCreateContent: String = ""
    private var pendingDocument: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingDocument = documentFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingDocument = documentFromIntent(intent)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickOpenDocument" -> pickOpenDocument(result)
            "createDocument" -> createDocument(call, result)
            "readDocument" -> readDocumentCall(call, result)
            "writeDocument" -> writeDocumentCall(call, result)
            "takePendingDocument" -> {
                result.success(pendingDocument)
                pendingDocument = null
            }
            "getPreference" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("bad_args", "Chiave preferenza mancante.", null)
                } else {
                    result.success(getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(key, null))
                }
            }
            "setPreference" -> {
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key == null || value == null) {
                    result.error("bad_args", "Preferenza non valida.", null)
                } else {
                    getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                        .edit()
                        .putString(key, value)
                        .apply()
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun pickOpenDocument(result: MethodChannel.Result) {
        if (!claimPendingResult(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("text/markdown", "text/plain", "text/x-markdown")
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        startActivityForResult(intent, OPEN_REQUEST)
    }

    private fun createDocument(call: MethodCall, result: MethodChannel.Result) {
        if (!claimPendingResult(result)) return
        val suggestedName = call.argument<String>("suggestedName") ?: "documento.md"
        pendingCreateContent = call.argument<String>("content") ?: ""
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/markdown"
            putExtra(Intent.EXTRA_TITLE, suggestedName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        startActivityForResult(intent, CREATE_REQUEST)
    }

    private fun readDocumentCall(call: MethodCall, result: MethodChannel.Result) {
        val rawUri = call.argument<String>("uri")
        if (rawUri.isNullOrBlank()) {
            result.error("bad_args", "URI del documento mancante.", null)
            return
        }
        try {
            result.success(readDocument(Uri.parse(rawUri)))
        } catch (error: Exception) {
            result.error("read_failed", "Impossibile leggere il file: ${error.message}", null)
        }
    }

    private fun writeDocumentCall(call: MethodCall, result: MethodChannel.Result) {
        val rawUri = call.argument<String>("uri")
        val content = call.argument<String>("content") ?: ""
        if (rawUri.isNullOrBlank()) {
            result.error("bad_args", "URI del documento mancante.", null)
            return
        }
        val uri = Uri.parse(rawUri)
        try {
            writeDocument(uri, content)
            result.success(readDocument(uri))
        } catch (error: Exception) {
            result.error("write_failed", "Impossibile salvare il file: ${error.message}", null)
        }
    }

    private fun claimPendingResult(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "È già aperta una finestra di selezione file.", null)
            return false
        }
        pendingResult = result
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OPEN_REQUEST && requestCode != CREATE_REQUEST) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri = data.data!!
        persistPermission(uri, data.flags)

        try {
            if (requestCode == CREATE_REQUEST) {
                writeDocument(uri, pendingCreateContent)
                pendingCreateContent = ""
            }
            result.success(readDocument(uri))
        } catch (error: Exception) {
            result.error("file_failed", "Operazione sul file non riuscita: ${error.message}", null)
        }
    }

    private fun documentFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        return try {
            when (intent.action) {
                Intent.ACTION_VIEW, Intent.ACTION_EDIT -> {
                    val uri = intent.data ?: return null
                    persistPermission(uri, intent.flags)
                    readDocument(uri)
                }
                Intent.ACTION_SEND -> {
                    @Suppress("DEPRECATION")
                    val uri = intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                    if (uri != null) {
                        persistPermission(uri, intent.flags)
                        readDocument(uri)
                    } else {
                        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                        mapOf(
                            "uri" to "",
                            "name" to "Condiviso.md",
                            "content" to text
                        )
                    }
                }
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun persistPermission(uri: Uri, sourceFlags: Int) {
        val flags = sourceFlags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (flags == 0) return
        try {
            contentResolver.takePersistableUriPermission(uri, flags)
        } catch (_: Exception) {
            // Alcuni provider concedono accesso solo per la sessione corrente.
        }
    }

    private fun readDocument(uri: Uri): Map<String, Any?> {
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("stream di lettura non disponibile")
        var content = String(bytes, StandardCharsets.UTF_8)
        if (content.startsWith('\uFEFF')) content = content.substring(1)
        return mapOf(
            "uri" to uri.toString(),
            "name" to displayName(uri),
            "content" to content
        )
    }

    private fun writeDocument(uri: Uri, content: String) {
        val stream = contentResolver.openOutputStream(uri, "wt")
            ?: throw IllegalStateException("stream di scrittura non disponibile")
        stream.use { it.write(content.toByteArray(StandardCharsets.UTF_8)) }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) return cursor.getString(index) ?: "documento.md"
                }
            }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "documento.md"
    }
}
