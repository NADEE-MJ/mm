import React, { useEffect, useState } from 'react';
import { View, StyleSheet, FlatList } from 'react-native';
import { Stack } from 'expo-router';
import { Button, Card, ProgressBar, Text } from 'react-native-paper';
import { useMoviesStore } from '../src/stores/moviesStore';
import { MovieWithDetails } from '../src/types';

function getTitle(movie: MovieWithDetails): string {
  return (
    (movie.tmdb_data as any)?.title ||
    (movie.omdb_data as any)?.title ||
    (movie.omdb_data as any)?.Title ||
    movie.imdb_id
  );
}

export default function EnrichScreen() {
  const getUnenrichedMovies = useMoviesStore((state) => state.getUnenrichedMovies);
  const enrichMovie = useMoviesStore((state) => state.enrichMovie);

  const [movies, setMovies] = useState<MovieWithDetails[]>([]);
  const [isEnriching, setIsEnriching] = useState(false);
  const [progress, setProgress] = useState(0);

  const load = async () => {
    const rows = await getUnenrichedMovies();
    setMovies(rows);
  };

  useEffect(() => {
    load();
  }, []);

  const handleEnrichOne = async (imdbId: string) => {
    setIsEnriching(true);
    try {
      await enrichMovie(imdbId);
      await load();
    } finally {
      setIsEnriching(false);
    }
  };

  const handleEnrichAll = async () => {
    setIsEnriching(true);
    try {
      const total = Math.max(movies.length, 1);
      let done = 0;
      for (const movie of movies) {
        await enrichMovie(movie.imdb_id).catch((error) =>
          console.warn('Single enrichment failed', error)
        );
        done += 1;
        setProgress(done / total);
      }
      await load();
    } finally {
      setIsEnriching(false);
      setProgress(0);
    }
  };

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          title: 'Enrich Movies',
          headerShown: true,
          headerStyle: { backgroundColor: '#1c1c1e' },
          headerTintColor: '#fff',
        }}
      />

      <View style={styles.header}>
        <Text variant="headlineSmall" style={styles.title}>
          Missing metadata
        </Text>
        <Text variant="bodyMedium" style={styles.subtitle}>
          {movies.length} movie{movies.length === 1 ? '' : 's'} need enrichment
        </Text>
      </View>

      {isEnriching && <ProgressBar progress={progress} color="#0a84ff" style={styles.progress} />}

      <View style={styles.actions}>
        <Button mode="contained" onPress={handleEnrichAll} disabled={isEnriching || movies.length === 0}>
          Enrich All
        </Button>
      </View>

      <FlatList
        data={movies}
        keyExtractor={(item) => item.imdb_id}
        contentContainerStyle={styles.list}
        renderItem={({ item }) => (
          <Card style={styles.card}>
            <Card.Title title={getTitle(item)} subtitle={item.imdb_id} />
            <Card.Actions>
              <Button disabled={isEnriching} onPress={() => handleEnrichOne(item.imdb_id)}>
                Enrich
              </Button>
            </Card.Actions>
          </Card>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  header: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
  },
  title: {
    color: '#fff',
  },
  subtitle: {
    color: '#8e8e93',
    marginTop: 4,
  },
  progress: {
    marginHorizontal: 16,
    marginBottom: 8,
  },
  actions: {
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  list: {
    paddingHorizontal: 16,
    paddingBottom: 20,
  },
  card: {
    marginBottom: 10,
    backgroundColor: '#1c1c1e',
  },
});
