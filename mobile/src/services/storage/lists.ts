import { getDatabase } from '../database/init';
import { CustomList } from '../../types';

/**
 * Get all custom lists
 */
export async function getAllLists(): Promise<CustomList[]> {
  try {
    const db = getDatabase();
    const lists = await db.getAllAsync<CustomList>(
      'SELECT * FROM custom_lists ORDER BY position ASC, created_at ASC'
    );

    return lists;
  } catch (error) {
    console.error('Failed to get all lists:', error);
    return [];
  }
}

/**
 * Get a single list by ID
 */
export async function getList(id: string): Promise<CustomList | null> {
  try {
    const db = getDatabase();
    const list = await db.getFirstAsync<CustomList>(
      'SELECT * FROM custom_lists WHERE id = ?',
      [id]
    );

    return list || null;
  } catch (error) {
    console.error('Failed to get list:', error);
    return null;
  }
}

/**
 * Create a new list
 */
export async function createList(
  id: string,
  userId: string,
  name: string,
  color: string = '#DBA506',
  icon: string = 'list',
  position: number = 0
): Promise<void> {
  try {
    const db = getDatabase();
    const now = Date.now();

    await db.runAsync(
      `INSERT INTO custom_lists (id, user_id, name, color, icon, position, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, userId, name, color, icon, position, now]
    );
  } catch (error) {
    console.error('Failed to create list:', error);
    throw error;
  }
}

/**
 * Update a list
 */
export async function updateList(
  id: string,
  updates: {
    name?: string;
    color?: string;
    icon?: string;
    position?: number;
  }
): Promise<void> {
  try {
    const db = getDatabase();

    // Build dynamic update query
    const updateFields: string[] = [];
    const values: any[] = [];

    if (updates.name !== undefined) {
      updateFields.push('name = ?');
      values.push(updates.name);
    }

    if (updates.color !== undefined) {
      updateFields.push('color = ?');
      values.push(updates.color);
    }

    if (updates.icon !== undefined) {
      updateFields.push('icon = ?');
      values.push(updates.icon);
    }

    if (updates.position !== undefined) {
      updateFields.push('position = ?');
      values.push(updates.position);
    }

    if (updateFields.length === 0) {
      return;
    }

    values.push(id);

    await db.runAsync(
      `UPDATE custom_lists SET ${updateFields.join(', ')} WHERE id = ?`,
      values
    );
  } catch (error) {
    console.error('Failed to update list:', error);
    throw error;
  }
}

/**
 * Delete a list
 */
export async function deleteList(id: string): Promise<void> {
  try {
    const db = getDatabase();

    // Also update any movies with this list back to toWatch
    await db.runAsync(
      `UPDATE movie_status SET status = 'toWatch', custom_list_id = NULL
       WHERE custom_list_id = ?`,
      [id]
    );

    // Delete the list
    await db.runAsync('DELETE FROM custom_lists WHERE id = ?', [id]);
  } catch (error) {
    console.error('Failed to delete list:', error);
    throw error;
  }
}

/**
 * Get movie count for a list
 */
export async function getListMovieCount(listId: string): Promise<number> {
  try {
    const db = getDatabase();
    const result = await db.getFirstAsync<{ count: number }>(
      `SELECT COUNT(*) as count FROM movie_status
       WHERE custom_list_id = ?`,
      [listId]
    );

    return result?.count || 0;
  } catch (error) {
    console.error('Failed to get list movie count:', error);
    return 0;
  }
}
