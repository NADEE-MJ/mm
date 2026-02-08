import { getDatabase } from '../database/init';
import { Person } from '../../types';

/**
 * Get all people
 */
export async function getAllPeople(): Promise<Person[]> {
  try {
    const db = getDatabase();
    const people = await db.getAllAsync<any>(
      'SELECT * FROM people ORDER BY name ASC'
    );

    return people.map((p) => ({
      ...p,
      is_trusted: p.is_trusted === 1,
      is_default: p.is_default === 1,
    }));
  } catch (error) {
    console.error('Failed to get all people:', error);
    return [];
  }
}

/**
 * Get a single person by name
 */
export async function getPerson(name: string): Promise<Person | null> {
  try {
    const db = getDatabase();
    const person = await db.getFirstAsync<any>(
      'SELECT * FROM people WHERE name = ?',
      [name]
    );

    if (!person) {
      return null;
    }

    return {
      ...person,
      is_trusted: person.is_trusted === 1,
      is_default: person.is_default === 1,
    };
  } catch (error) {
    console.error('Failed to get person:', error);
    return null;
  }
}

/**
 * Add or update a person
 */
export async function savePerson(
  name: string,
  userId: string,
  isTrusted: boolean = false,
  isDefault: boolean = false,
  color: string = '#DBA506',
  emoji?: string
): Promise<void> {
  try {
    const db = getDatabase();

    await db.runAsync(
      `INSERT OR REPLACE INTO people (name, user_id, is_trusted, is_default, color, emoji)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [name, userId, isTrusted ? 1 : 0, isDefault ? 1 : 0, color, emoji || null]
    );
  } catch (error) {
    console.error('Failed to save person:', error);
    throw error;
  }
}

/**
 * Update person settings
 */
export async function updatePerson(
  name: string,
  updates: {
    is_trusted?: boolean;
    is_default?: boolean;
    color?: string;
    emoji?: string;
  }
): Promise<void> {
  try {
    const db = getDatabase();

    // Build dynamic update query
    const updateFields: string[] = [];
    const values: any[] = [];

    if (updates.is_trusted !== undefined) {
      updateFields.push('is_trusted = ?');
      values.push(updates.is_trusted ? 1 : 0);
    }

    if (updates.is_default !== undefined) {
      updateFields.push('is_default = ?');
      values.push(updates.is_default ? 1 : 0);
    }

    if (updates.color !== undefined) {
      updateFields.push('color = ?');
      values.push(updates.color);
    }

    if (updates.emoji !== undefined) {
      updateFields.push('emoji = ?');
      values.push(updates.emoji);
    }

    if (updateFields.length === 0) {
      return;
    }

    values.push(name);

    await db.runAsync(
      `UPDATE people SET ${updateFields.join(', ')} WHERE name = ?`,
      values
    );
  } catch (error) {
    console.error('Failed to update person:', error);
    throw error;
  }
}

/**
 * Delete a person
 */
export async function deletePerson(name: string): Promise<void> {
  try {
    const db = getDatabase();
    await db.runAsync('DELETE FROM people WHERE name = ?', [name]);
  } catch (error) {
    console.error('Failed to delete person:', error);
    throw error;
  }
}

/**
 * Get person statistics (recommendation counts, etc.)
 */
export async function getPersonStats(name: string): Promise<{
  totalRecommendations: number;
  upvotes: number;
  downvotes: number;
  moviesWatched: number;
}> {
  try {
    const db = getDatabase();

    const stats = await db.getFirstAsync<any>(
      `SELECT
        COUNT(*) as totalRecommendations,
        SUM(CASE WHEN vote_type = 'upvote' THEN 1 ELSE 0 END) as upvotes,
        SUM(CASE WHEN vote_type = 'downvote' THEN 1 ELSE 0 END) as downvotes
       FROM recommendations
       WHERE person = ?`,
      [name]
    );

    // Get movies watched (movies with watch_history and this person's recommendation)
    const watched = await db.getFirstAsync<{ count: number }>(
      `SELECT COUNT(DISTINCT r.imdb_id) as count
       FROM recommendations r
       JOIN watch_history wh ON r.imdb_id = wh.imdb_id
       WHERE r.person = ?`,
      [name]
    );

    return {
      totalRecommendations: stats?.totalRecommendations || 0,
      upvotes: stats?.upvotes || 0,
      downvotes: stats?.downvotes || 0,
      moviesWatched: watched?.count || 0,
    };
  } catch (error) {
    console.error('Failed to get person stats:', error);
    return {
      totalRecommendations: 0,
      upvotes: 0,
      downvotes: 0,
      moviesWatched: 0,
    };
  }
}
