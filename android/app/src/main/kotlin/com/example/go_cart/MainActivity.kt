package com.example.go_cart

import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "content_provider_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "insertProduct" -> {
                    try {
                        val authority = call.argument<String>("authority")!!
                        val table = call.argument<String>("table")!!
                        val data = call.argument<Map<String, Any>>("data")!!
                        
                        val uri = Uri.parse("content://$authority/$table")
                        val values = ContentValues().apply {
                            data.forEach { (key, value) ->
                                when (value) {
                                    is String -> put(key, value)
                                    is Int -> put(key, value)
                                    is Long -> put(key, value)
                                    is Double -> put(key, value)
                                    is Float -> put(key, value)
                                    is Boolean -> put(key, if (value) 1 else 0)
                                }
                            }
                        }
                        
                        val insertedUri = contentResolver.insert(uri, values)
                        result.success(insertedUri != null)
                        Log.d("MainActivity", "Inserted product via ContentProvider")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to insert product", e)
                        result.error("INSERT_ERROR", e.message, null)
                    }
                }
                
                "insertProducts" -> {
                    try {
                        val authority = call.argument<String>("authority")!!
                        val table = call.argument<String>("table")!!
                        val dataList = call.argument<List<Map<String, Any>>>("dataList")!!
                        
                        val uri = Uri.parse("content://$authority/$table")
                        var successCount = 0
                        
                        dataList.forEach { data ->
                            val values = ContentValues().apply {
                                data.forEach { (key, value) ->
                                    when (value) {
                                        is String -> put(key, value)
                                        is Int -> put(key, value)
                                        is Long -> put(key, value)
                                        is Double -> put(key, value)
                                        is Float -> put(key, value)
                                        is Boolean -> put(key, if (value) 1 else 0)
                                    }
                                }
                            }
                            
                            val insertedUri = contentResolver.insert(uri, values)
                            if (insertedUri != null) successCount++
                        }
                        
                        result.success(successCount == dataList.size)
                        Log.d("MainActivity", "Batch inserted $successCount/${dataList.size} products")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to batch insert products", e)
                        result.error("BATCH_INSERT_ERROR", e.message, null)
                    }
                }
                
                "queryProducts" -> {
                    try {
                        val authority = call.argument<String>("authority")!!
                        val table = call.argument<String>("table")!!
                        val selection = call.argument<String?>("selection")
                        val selectionArgs = call.argument<List<String>?>("selectionArgs")?.toTypedArray()
                        
                        val uri = Uri.parse("content://$authority/$table")
                        val cursor: Cursor? = contentResolver.query(
                            uri, null, selection, selectionArgs, null
                        )
                        
                        val products = mutableListOf<Map<String, Any>>()
                        cursor?.use {
                            while (it.moveToNext()) {
                                val product = mutableMapOf<String, Any>()
                                for (i in 0 until it.columnCount) {
                                    val columnName = it.getColumnName(i)
                                    val value: Any = when (it.getType(i)) {
                                        Cursor.FIELD_TYPE_STRING -> it.getString(i)
                                        Cursor.FIELD_TYPE_INTEGER -> it.getLong(i)
                                        Cursor.FIELD_TYPE_FLOAT -> it.getDouble(i)
                                        else -> it.getString(i) ?: ""
                                    }
                                    product[columnName] = value
                                }
                                products.add(product)
                            }
                        }
                        
                        result.success(products)
                        Log.d("MainActivity", "Queried ${products.size} products")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to query products", e)
                        result.error("QUERY_ERROR", e.message, null)
                    }
                }
                
                "updateProduct" -> {
                    try {
                        val authority = call.argument<String>("authority")!!
                        val table = call.argument<String>("table")!!
                        val data = call.argument<Map<String, Any>>("data")!!
                        val selection = call.argument<String?>("selection")
                        val selectionArgs = call.argument<List<String>?>("selectionArgs")?.toTypedArray()
                        
                        val uri = Uri.parse("content://$authority/$table")
                        val values = ContentValues().apply {
                            data.forEach { (key, value) ->
                                when (value) {
                                    is String -> put(key, value)
                                    is Int -> put(key, value)
                                    is Long -> put(key, value)
                                    is Double -> put(key, value)
                                    is Float -> put(key, value)
                                    is Boolean -> put(key, if (value) 1 else 0)
                                }
                            }
                        }
                        
                        val updatedRows = contentResolver.update(uri, values, selection, selectionArgs)
                        result.success(updatedRows > 0)
                        Log.d("MainActivity", "Updated $updatedRows products")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to update product", e)
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                
                "deleteProducts" -> {
                    try {
                        val authority = call.argument<String>("authority")!!
                        val table = call.argument<String>("table")!!
                        val selection = call.argument<String?>("selection")
                        val selectionArgs = call.argument<List<String>?>("selectionArgs")?.toTypedArray()
                        
                        val uri = Uri.parse("content://$authority/$table")
                        val deletedRows = contentResolver.delete(uri, selection, selectionArgs)
                        result.success(deletedRows > 0)
                        Log.d("MainActivity", "Deleted $deletedRows products")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to delete products", e)
                        result.error("DELETE_ERROR", e.message, null)
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }
}