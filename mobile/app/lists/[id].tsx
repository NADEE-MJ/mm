import React, { useEffect, useMemo } from 'react';
import { Image, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Href, Stack, router, useLocalSearchParams } from 'expo-router';
import { ChevronLeft } from 'lucide-react-native';
import { useListsStore } from '../../src/stores/listsStore';
import { useMoviesStore } from '../../src/stores/moviesStore';
import CircleButton from '../../src/components/ui/CircleButton';
import GroupedList from '../../src/components/ui/GroupedList';
import GroupedListItem from '../../src/components/ui/GroupedListItem';
import { COLORS } from '../../src/utils/constants';
import { getMovieTitle, getMovieYear, getPosterUrl } from '../../src/utils/movieData';

export default function ListDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();

  const lists = useListsStore((state) => state.lists);
  const loadLists = useListsStore((state) => state.loadLists);

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);

  useEffect(() => {
    loadLists();
    loadMovies();
  }, [loadLists, loadMovies]);

  const list = useMemo(() => lists.find((entry) => entry.id === id), [lists, id]);

  const listMovies = useMemo(
    () =>
      movies.filter(
        (movie) => movie.status.status === 'custom' && movie.status.custom_list_id === id
      ),
    [movies, id]
  );

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: COLORS.background },
          headerTitleAlign: 'center',
          headerBackVisible: false,
          headerTitle: () => <Text style={styles.headerTitle}>{list?.name || 'List'}</Text>,
          headerLeft: () => <CircleButton icon={ChevronLeft} onPress={() => router.back()} />,
          headerRight: () => <View style={{ width: 36 }} />,
        }}
      />

      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        {listMovies.length === 0 ? (
          <View style={styles.emptyWrap}>
            <Text style={styles.emptyTitle}>No movies in this list</Text>
            <Text style={styles.emptySubtitle}>Add movies from movie detail with "Add to List".</Text>
          </View>
        ) : (
          <GroupedList>
            {listMovies.map((movie, index) => {
              const poster = getPosterUrl(movie);
              return (
                <GroupedListItem
                  key={movie.imdb_id}
                  title={getMovieTitle(movie)}
                  subtitle={getMovieYear(movie)}
                  onPress={() => router.push(`/movie/${movie.imdb_id}` as Href)}
                  showDivider={index < listMovies.length - 1}
                  left={
                    poster ? (
                      <Image source={{ uri: poster }} style={styles.poster} />
                    ) : (
                      <View style={[styles.poster, styles.posterPlaceholder]} />
                    )
                  }
                />
              );
            })}
          </GroupedList>
        )}
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  headerTitle: {
    color: COLORS.text,
    fontSize: 17,
    fontWeight: '600',
  },
  poster: {
    width: 30,
    height: 44,
    borderRadius: 5,
    backgroundColor: '#2c2c2e',
  },
  posterPlaceholder: {
    opacity: 0.65,
  },
  emptyWrap: {
    borderRadius: 12,
    backgroundColor: COLORS.surfaceGroup,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    alignItems: 'center',
    padding: 22,
  },
  emptyTitle: {
    color: COLORS.text,
    fontSize: 18,
    fontWeight: '700',
  },
  emptySubtitle: {
    color: COLORS.textSecondary,
    marginTop: 6,
    textAlign: 'center',
  },
});
