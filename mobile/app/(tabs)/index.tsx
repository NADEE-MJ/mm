import React, { useEffect, useMemo, useState } from 'react';
import { FlatList, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import { Href, router } from 'expo-router';
import { FAB, Menu } from 'react-native-paper';
import { ChevronDown, Filter } from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMoviesStore } from '../../src/stores/moviesStore';
import MovieCard from '../../src/components/movies/MovieCard';
import EnrichmentPrompt from '../../src/components/EnrichmentPrompt';
import FilterSheet from '../../src/components/FilterSheet';
import { COLORS } from '../../src/utils/constants';
import { getMovieGenres, getMovieTitle, getMovieVoteAverage, getMovieYear } from '../../src/utils/movieData';

const SORT_LABELS = {
  dateRecommended: 'Date Added',
  dateWatched: 'Date Watched',
  myRating: 'My Rating',
  imdbRating: 'IMDb Rating',
  year: 'Year',
  title: 'Title',
} as const;

type SortKey = keyof typeof SORT_LABELS;

function toNumberYear(value: string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function newestRecommendationTimestamp(movie: { recommendations: Array<{ date_recommended: number }> }): number {
  if (movie.recommendations.length === 0) {
    return 0;
  }
  return Math.max(...movie.recommendations.map((recommendation) => recommendation.date_recommended));
}

export default function MoviesScreen() {
  const insets = useSafeAreaInsets();
  const [refreshing, setRefreshing] = useState(false);
  const [showEnrichmentPrompt, setShowEnrichmentPrompt] = useState(false);
  const [unenrichedCount, setUnenrichedCount] = useState(0);
  const [showFilterSheet, setShowFilterSheet] = useState(false);
  const [showSortMenu, setShowSortMenu] = useState(false);

  const [selectedRecommender, setSelectedRecommender] = useState<string | null>(null);
  const [selectedGenre, setSelectedGenre] = useState<string | null>(null);
  const [selectedDecade, setSelectedDecade] = useState<number | null>(null);
  const [sortBy, setSortBy] = useState<SortKey>('dateRecommended');

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);
  const getUnenrichedMovies = useMoviesStore((state) => state.getUnenrichedMovies);

  useEffect(() => {
    loadMovies();
  }, [loadMovies]);

  useEffect(() => {
    const checkEnrichment = async () => {
      const net = await NetInfo.fetch();
      if (!net.isConnected || !net.isInternetReachable) {
        return;
      }

      const unenriched = await getUnenrichedMovies();
      if (unenriched.length > 0) {
        setUnenrichedCount(unenriched.length);
        setShowEnrichmentPrompt(true);
      }
    };

    checkEnrichment();
  }, [getUnenrichedMovies]);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadMovies();
    setRefreshing(false);
  };

  const activeFilterCount = [selectedRecommender, selectedGenre, selectedDecade]
    .filter(Boolean)
    .length;

  const visibleMovies = useMemo(
    () => movies.filter((movie) => movie.status.status !== 'deleted'),
    [movies]
  );

  const recommenders = useMemo(() => {
    const set = new Set<string>();
    for (const movie of visibleMovies) {
      for (const rec of movie.recommendations) {
        set.add(rec.person);
      }
    }
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [visibleMovies]);

  const genres = useMemo(() => {
    const set = new Set<string>();
    for (const movie of visibleMovies) {
      for (const genre of getMovieGenres(movie)) {
        set.add(genre);
      }
    }
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [visibleMovies]);

  const decades = useMemo(() => {
    const set = new Set<number>();
    for (const movie of visibleMovies) {
      const year = Number(getMovieYear(movie));
      if (Number.isFinite(year) && year > 0) {
        set.add(Math.floor(year / 10) * 10);
      }
    }
    return Array.from(set).sort((a, b) => b - a);
  }, [visibleMovies]);

  const filteredMovies = useMemo(() => {
    return visibleMovies.filter((movie) => {
      if (
        selectedRecommender &&
        !movie.recommendations.some((recommendation) => recommendation.person === selectedRecommender)
      ) {
        return false;
      }

      if (selectedGenre && !getMovieGenres(movie).includes(selectedGenre)) {
        return false;
      }

      if (selectedDecade) {
        const year = Number(getMovieYear(movie));
        if (!Number.isFinite(year) || Math.floor(year / 10) * 10 !== selectedDecade) {
          return false;
        }
      }

      return true;
    });
  }, [visibleMovies, selectedRecommender, selectedGenre, selectedDecade]);

  const sortedMovies = useMemo(() => {
    const sorted = [...filteredMovies];

    switch (sortBy) {
      case 'dateRecommended':
        return sorted.sort(
          (a, b) => newestRecommendationTimestamp(b) - newestRecommendationTimestamp(a)
        );
      case 'dateWatched':
        return sorted.sort((a, b) => (b.watch_history?.date_watched || 0) - (a.watch_history?.date_watched || 0));
      case 'myRating':
        return sorted.sort((a, b) => (b.watch_history?.my_rating || 0) - (a.watch_history?.my_rating || 0));
      case 'imdbRating':
        return sorted.sort((a, b) => (getMovieVoteAverage(b) || 0) - (getMovieVoteAverage(a) || 0));
      case 'year':
        return sorted.sort((a, b) => toNumberYear(getMovieYear(b)) - toNumberYear(getMovieYear(a)));
      case 'title':
        return sorted.sort((a, b) => getMovieTitle(a).localeCompare(getMovieTitle(b)));
      default:
        return sorted;
    }
  }, [filteredMovies, sortBy]);

  return (
    <View style={styles.container}>
      <FlatList
        data={sortedMovies}
        keyExtractor={(item) => item.imdb_id}
        renderItem={({ item }) => <MovieCard movie={item} />}
        contentContainerStyle={[styles.listContent, { paddingBottom: 120 + insets.bottom }]}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />}
        ListHeaderComponent={
          <View style={[styles.headerArea, { paddingTop: insets.top + 8 }]}>
            <Text style={styles.largeTitle}>Movies</Text>

            <View style={styles.toolbarRow}>
              <Pressable
                style={({ pressed }) => [styles.toolbarPill, pressed && styles.pressed]}
                onPress={() => setShowFilterSheet(true)}
              >
                <Filter size={16} color={COLORS.text} />
                <Text style={styles.toolbarPillText}>Filter</Text>
                {activeFilterCount > 0 ? (
                  <View style={styles.filterBadge}>
                    <Text style={styles.filterBadgeText}>{activeFilterCount}</Text>
                  </View>
                ) : null}
              </Pressable>

              <Menu
                visible={showSortMenu}
                onDismiss={() => setShowSortMenu(false)}
                anchor={
                  <Pressable
                    style={({ pressed }) => [styles.toolbarPill, pressed && styles.pressed]}
                    onPress={() => setShowSortMenu(true)}
                  >
                    <Text style={styles.toolbarPillText}>{SORT_LABELS[sortBy]}</Text>
                    <ChevronDown size={16} color={COLORS.textSecondary} />
                  </Pressable>
                }
              >
                {(Object.keys(SORT_LABELS) as SortKey[]).map((key) => (
                  <Menu.Item
                    key={key}
                    title={SORT_LABELS[key]}
                    onPress={() => {
                      setSortBy(key);
                      setShowSortMenu(false);
                    }}
                  />
                ))}
              </Menu>
            </View>
          </View>
        }
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Text style={styles.emptyTitle}>No movies found</Text>
            <Text style={styles.emptySubtitle}>Add movies or change your filters.</Text>
          </View>
        }
      />

      <FAB
        icon="plus"
        style={[styles.fab, { bottom: 106 + insets.bottom }]}
        onPress={() => router.push('/movie/add')}
      />

      <FilterSheet
        visible={showFilterSheet}
        onDismiss={() => setShowFilterSheet(false)}
        selectedRecommender={selectedRecommender}
        selectedGenre={selectedGenre}
        selectedDecade={selectedDecade}
        recommenders={recommenders}
        genres={genres}
        decades={decades}
        onSelectRecommender={setSelectedRecommender}
        onSelectGenre={setSelectedGenre}
        onSelectDecade={setSelectedDecade}
        onClearAll={() => {
          setSelectedRecommender(null);
          setSelectedGenre(null);
          setSelectedDecade(null);
        }}
      />

      <EnrichmentPrompt
        visible={showEnrichmentPrompt}
        count={unenrichedCount}
        onDismiss={() => setShowEnrichmentPrompt(false)}
        onEnrich={() => {
          setShowEnrichmentPrompt(false);
          router.push('/enrich' as Href);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  headerArea: {
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 10,
  },
  largeTitle: {
    fontSize: 34,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: 12,
  },
  toolbarRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  toolbarPill: {
    height: 36,
    borderRadius: 18,
    backgroundColor: '#2c2c2e',
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  toolbarPillText: {
    color: COLORS.text,
    fontSize: 14,
    fontWeight: '600',
  },
  filterBadge: {
    minWidth: 18,
    height: 18,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 5,
    backgroundColor: COLORS.primary,
  },
  filterBadgeText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '700',
  },
  pressed: {
    opacity: 0.75,
  },
  listContent: {
    paddingBottom: 120,
  },
  emptyState: {
    paddingTop: 80,
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  emptyTitle: {
    color: COLORS.text,
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 6,
  },
  emptySubtitle: {
    color: COLORS.textSecondary,
    fontSize: 14,
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 106,
    backgroundColor: COLORS.primary,
  },
});
