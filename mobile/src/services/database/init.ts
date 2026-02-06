import * as SQLite from 'expo-sqlite';
import { DB_NAME, SCHEMA_SQL, DROP_ALL_TABLES_SQL, DB_VERSION, MIGRATIONS } from './schema';

let dbInstance: SQLite.SQLiteDatabase | null = null;

/**
 * Initialize and return the SQLite database instance
 */
export async function initDatabase(): Promise<SQLite.SQLiteDatabase> {
  if (dbInstance) {
    return dbInstance;
  }

  try {
    dbInstance = await SQLite.openDatabaseAsync(DB_NAME);

    // Enable foreign keys
    await dbInstance.execAsync('PRAGMA foreign_keys = ON;');

    // Create tables
    await dbInstance.execAsync(SCHEMA_SQL);

    // Run migrations if needed
    await runMigrations(dbInstance);

    console.log('Database initialized successfully');
    return dbInstance;
  } catch (error) {
    console.error('Failed to initialize database:', error);
    throw error;
  }
}

/**
 * Get the current database instance
 */
export function getDatabase(): SQLite.SQLiteDatabase {
  if (!dbInstance) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return dbInstance;
}

/**
 * Run database migrations
 */
async function runMigrations(db: SQLite.SQLiteDatabase): Promise<void> {
  try {
    // Get current DB version
    const result = await db.getFirstAsync<{ value: string }>(
      'SELECT value FROM metadata WHERE key = ?',
      ['db_version']
    );

    const currentVersion = result ? parseInt(result.value, 10) : 0;

    // Run any pending migrations
    for (const migration of MIGRATIONS) {
      if (migration.version > currentVersion) {
        console.log(`Running migration to version ${migration.version}`);
        await db.execAsync(migration.sql);

        // Update version in metadata
        await db.runAsync(
          'UPDATE metadata SET value = ?, updated_at = ? WHERE key = ?',
          [migration.version.toString(), Date.now(), 'db_version']
        );
      }
    }

    console.log('Migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

/**
 * Clear all data from the database (used on logout)
 */
export async function clearDatabase(): Promise<void> {
  try {
    const db = getDatabase();

    // Drop all tables
    await db.execAsync(DROP_ALL_TABLES_SQL);

    // Recreate tables
    await db.execAsync(SCHEMA_SQL);

    console.log('Database cleared successfully');
  } catch (error) {
    console.error('Failed to clear database:', error);
    throw error;
  }
}

/**
 * Close the database connection
 */
export async function closeDatabase(): Promise<void> {
  if (dbInstance) {
    await dbInstance.closeAsync();
    dbInstance = null;
    console.log('Database closed');
  }
}

/**
 * Get metadata value
 */
export async function getMetadata(key: string): Promise<string | null> {
  try {
    const db = getDatabase();
    const result = await db.getFirstAsync<{ value: string }>(
      'SELECT value FROM metadata WHERE key = ?',
      [key]
    );
    return result?.value || null;
  } catch (error) {
    console.error('Failed to get metadata:', error);
    return null;
  }
}

/**
 * Set metadata value
 */
export async function setMetadata(key: string, value: string): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync(
      'INSERT OR REPLACE INTO metadata (key, value, updated_at) VALUES (?, ?, ?)',
      [key, value, Date.now()]
    );
  } catch (error) {
    console.error('Failed to set metadata:', error);
    throw error;
  }
}
