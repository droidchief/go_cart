package com.example.go_cart

import android.content.*
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import android.util.Log

class SharedDatabaseProvider : ContentProvider() {
    
    companion object {
        const val AUTHORITY = "com.example.go_cart.shared.database"
        const val DATABASE_NAME = "go_cart_shared.db"
        const val DATABASE_VERSION = 1
        const val TABLE_PRODUCTS = "products"
        
        val BASE_URI: Uri = Uri.parse("content://$AUTHORITY")
        val PRODUCTS_URI: Uri = Uri.withAppendedPath(BASE_URI, TABLE_PRODUCTS)
        
        const val PRODUCTS_CODE = 1
        const val PRODUCT_CODE = 2
        
        private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(AUTHORITY, TABLE_PRODUCTS, PRODUCTS_CODE)
            addURI(AUTHORITY, "$TABLE_PRODUCTS/#", PRODUCT_CODE)
        }
    }
    
    private lateinit var dbHelper: DatabaseHelper
    
    override fun onCreate(): Boolean {
        dbHelper = DatabaseHelper(context!!)
        Log.d("SharedDatabaseProvider", "ContentProvider created")
        return true
    }
    
    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? {
        val db = dbHelper.readableDatabase
        
        return when (uriMatcher.match(uri)) {
            PRODUCTS_CODE -> {
                Log.d("SharedDatabaseProvider", "Querying all products")
                db.query(TABLE_PRODUCTS, projection, selection, selectionArgs, null, null, sortOrder)
            }
            PRODUCT_CODE -> {
                val id = uri.lastPathSegment
                val newSelection = "${ProductColumns.ID} = ?"
                val newSelectionArgs = arrayOf(id)
                db.query(TABLE_PRODUCTS, projection, newSelection, newSelectionArgs, null, null, sortOrder)
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }
    
    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        val db = dbHelper.writableDatabase
        
        return when (uriMatcher.match(uri)) {
            PRODUCTS_CODE -> {
                val id = db.insertWithOnConflict(TABLE_PRODUCTS, null, values, SQLiteDatabase.CONFLICT_REPLACE)
                if (id > 0) {
                    context?.contentResolver?.notifyChange(uri, null)
                    Log.d("SharedDatabaseProvider", "Inserted product with ID: $id")
                    Uri.withAppendedPath(PRODUCTS_URI, id.toString())
                } else null
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }
    
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<String>?): Int {
        val db = dbHelper.writableDatabase
        
        val rowsUpdated = when (uriMatcher.match(uri)) {
            PRODUCTS_CODE -> {
                db.update(TABLE_PRODUCTS, values, selection, selectionArgs)
            }
            PRODUCT_CODE -> {
                val id = uri.lastPathSegment
                val newSelection = "${ProductColumns.ID} = ?"
                val newSelectionArgs = arrayOf(id)
                db.update(TABLE_PRODUCTS, values, newSelection, newSelectionArgs)
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
        
        if (rowsUpdated > 0) {
            context?.contentResolver?.notifyChange(uri, null)
            Log.d("SharedDatabaseProvider", "Updated $rowsUpdated products")
        }
        
        return rowsUpdated
    }
    
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<String>?): Int {
        val db = dbHelper.writableDatabase
        
        val rowsDeleted = when (uriMatcher.match(uri)) {
            PRODUCTS_CODE -> {
                db.delete(TABLE_PRODUCTS, selection, selectionArgs)
            }
            PRODUCT_CODE -> {
                val id = uri.lastPathSegment
                val newSelection = "${ProductColumns.ID} = ?"
                val newSelectionArgs = arrayOf(id)
                db.delete(TABLE_PRODUCTS, newSelection, newSelectionArgs)
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
        
        if (rowsDeleted > 0) {
            context?.contentResolver?.notifyChange(uri, null)
            Log.d("SharedDatabaseProvider", "Deleted $rowsDeleted products")
        }
        
        return rowsDeleted
    }
    
    override fun getType(uri: Uri): String? {
        return when (uriMatcher.match(uri)) {
            PRODUCTS_CODE -> "vnd.android.cursor.dir/vnd.$AUTHORITY.$TABLE_PRODUCTS"
            PRODUCT_CODE -> "vnd.android.cursor.item/vnd.$AUTHORITY.$TABLE_PRODUCTS"
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }
    
    private class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
        
        override fun onCreate(db: SQLiteDatabase) {
            val createTable = """
                CREATE TABLE $TABLE_PRODUCTS (
                    ${ProductColumns.ID} TEXT PRIMARY KEY,
                    ${ProductColumns.NAME} TEXT NOT NULL,
                    ${ProductColumns.IMAGE_PATH} TEXT,
                    ${ProductColumns.COUNT} INTEGER NOT NULL DEFAULT 1,
                    ${ProductColumns.PACKAGING_TYPE} TEXT DEFAULT 'Packs',
                    ${ProductColumns.MRP} REAL NOT NULL DEFAULT 0.0,
                    ${ProductColumns.PP} REAL NOT NULL DEFAULT 0.0,
                    ${ProductColumns.LAST_UPDATED} INTEGER NOT NULL,
                    ${ProductColumns.UPDATED_BY} TEXT NOT NULL,
                    ${ProductColumns.VERSION} INTEGER NOT NULL DEFAULT 1,
                    ${ProductColumns.IS_DELETED} INTEGER NOT NULL DEFAULT 0
                )
            """.trimIndent()
            
            db.execSQL(createTable)
            Log.d("DatabaseHelper", "Created products table")
        }
        
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            db.execSQL("DROP TABLE IF EXISTS $TABLE_PRODUCTS")
            onCreate(db)
        }
    }
    
    object ProductColumns {
        const val ID = "id"
        const val NAME = "name"
        const val IMAGE_PATH = "image_path"
        const val COUNT = "count"
        const val PACKAGING_TYPE = "packaging_type"
        const val MRP = "mrp"
        const val PP = "pp"
        const val LAST_UPDATED = "last_updated"
        const val UPDATED_BY = "updated_by"
        const val VERSION = "version"
        const val IS_DELETED = "is_deleted"
    }
}