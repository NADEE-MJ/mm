import React, { useEffect, useState } from 'react';
import { View, StyleSheet, FlatList, RefreshControl } from 'react-native';
import { Text, FAB, Searchbar, SegmentedButtons } from 'react-native-paper';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { useAuthStore } from '../../src/stores/authStore';
import MovieCard from '../../src/components/movies/MovieCard';
import { router } from 'expo-router';

export default function MoviesScreen() {
  const [searchQuery, setSearchQuery] = useState('');
  const [filter, setFilter] = useState<'all' | 'toWatch' | 'watched'>('all');
  const [refreshing, setRefreshing] = useState(false);

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);
  const searchMovies = useMoviesStore((state) => state.searchMovies);
  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    loadMovies();
  }, []);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadMovies();
    setRefreshing(false);
  };

  const filteredMovies = movies.filter((movie) => {
    // Filter by search query
    if (searchQuery) {
      const title = movie.tmdb_data?.title?.toLowerCase() || '';
      if (!title.includes(searchQuery.toLowerCase())) {
        return false;
      }
    }

    // Filter by status
    if (filter === 'toWatch') {
      return movie.status.status === 'toWatch';
    } else if (filter === 'watched') {
      return movie.status.status === 'watched';
    }

    // All filter - show toWatch and watched, hide deleted
    return movie.status.status !== 'deleted';
  });

  return (
    <View style={styles.container}>
      <Searchbar
        placeholder="Search movies..."
        onChangeText={setSearchQuery}
        value={searchQuery}
        style={styles.searchbar}
      />

      <SegmentedButtons
        value={filter}
        onValueChange={(value) => setFilter(value as 'all' | 'toWatch' | 'watched')}
        buttons={[
          { value: 'all', label: 'All' },
          { value: 'toWatch', label: 'To Watch' },
          { value: 'watched', label: 'Watched' },
        ]}
        style={styles.segmentedButtons}
      />

      {filteredMovies.length === 0 ? (
        <View style={styles.emptyState}>
          <Text variant="headlineSmall" style={styles.emptyText}>
            {searchQuery
              ? 'No movies found'
              : filter === 'watched'
              ? 'No watched movies yet'
              : 'No movies yet'}
          </Text>
          <Text variant="bodyMedium" style={styles.emptySubtext}>
            {searchQuery
              ? 'Try a different search term'
              : 'Tap the + button to add your first movie'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredMovies}
          keyExtractor={(item) => item.imdb_id}
          renderItem={({ item }) => <MovieCard movie={item} />}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
          }
        />
      )}

      <FAB
        icon="plus"
        style={styles.fab}
        onPress={() => {
          router.push('/movie/add');
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  searchbar: {
    margin: 16,
    backgroundColor: '#1c1c1e',
  },
  segmentedButtons: {
    marginHorizontal: 16,
    marginBottom: 8,
  },
  list: {
    paddingBottom: 80,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    color: '#fff',
    marginBottom: 8,
  },
  emptySubtext: {
    color: '#8e8e93',
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
    backgroundColor: '#0a84ff',
  },
});
