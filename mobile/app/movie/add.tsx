import React, { useState, useEffect } from 'react';
import {
  View,
  StyleSheet,
  FlatList,
  Image,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ScrollView,
} from 'react-native';
import { Text, Searchbar, ActivityIndicator, TextInput, Button, Chip } from 'react-native-paper';
import { router, Stack } from 'expo-router';
import { searchTMDB, getTMDBMovie, TMDBSearchResult } from '../../src/services/api/movies';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { useAuthStore } from '../../src/stores/authStore';
import { usePeopleStore } from '../../src/stores/peopleStore';

export default function AddMovieScreen() {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<TMDBSearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedMovie, setSelectedMovie] = useState<TMDBSearchResult | null>(null);
  const [selectedPerson, setSelectedPerson] = useState('');
  const [customPerson, setCustomPerson] = useState('');
  const [showCustomInput, setShowCustomInput] = useState(false);
  const [isAdding, setIsAdding] = useState(false);

  const addMovie = useMoviesStore((state) => state.addMovie);
  const user = useAuthStore((state) => state.user);
  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);

  useEffect(() => {
    loadPeople();
  }, []);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    setIsSearching(true);
    try {
      const results = await searchTMDB(searchQuery);
      setSearchResults(results);
    } catch (error) {
      Alert.alert('Search Failed', error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setIsSearching(false);
    }
  };

  const parseTitleAndYear = (raw: string): { title: string; year?: number } => {
    const trimmed = raw.trim();
    const match = trimmed.match(/^(.*?)(?:\s+(\d{4}))?$/);
    const title = (match?.[1] || trimmed).trim();
    const year = match?.[2] ? parseInt(match[2], 10) : undefined;
    return { title, year };
  };

  const handleQuickAddOffline = async () => {
    if (!user) return;
    const parsed = parseTitleAndYear(searchQuery);
    if (!parsed.title) {
      Alert.alert('Error', 'Please enter a movie title');
      return;
    }

    setIsAdding(true);
    try {
      await addMovie(
        null,
        user.id,
        {
          id: 0,
          title: parsed.title,
          overview: '',
          poster_path: null,
          backdrop_path: null,
          release_date: parsed.year ? `${parsed.year}-01-01` : '',
          vote_average: 0,
          vote_count: 0,
          genres: [],
          runtime: null,
          tagline: null,
          year: parsed.year,
        } as any
      );

      Alert.alert('Added Offline', 'Movie saved locally. Enrich it when you are back online.', [
        {
          text: 'OK',
          onPress: () => router.back(),
        },
      ]);
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to add movie');
    } finally {
      setIsAdding(false);
    }
  };

  const handleSelectMovie = (movie: TMDBSearchResult) => {
    setSelectedMovie(movie);
  };

  const handleAddMovie = async () => {
    if (!selectedMovie || !user) return;

    const personName = selectedPerson || customPerson.trim();
    if (!personName) {
      Alert.alert('Error', 'Please select or enter who recommended this movie');
      return;
    }

    setIsAdding(true);

    try {
      // Get full movie details from TMDB
      const tmdbData = await getTMDBMovie(selectedMovie.id);

      // Extract IMDb ID from TMDB data or generate one
      const imdbId = `tt${selectedMovie.id}`;

      // Add movie with recommendation
      await addMovie(imdbId, user.id, tmdbData, undefined, personName, 'upvote');

      Alert.alert('Success', 'Movie added successfully!', [
        {
          text: 'OK',
          onPress: () => router.back(),
        },
      ]);
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to add movie');
    } finally {
      setIsAdding(false);
    }
  };

  const renderSearchResult = ({ item }: { item: TMDBSearchResult }) => {
    const posterUrl = item.poster || item.posterSmall || null;

    const isSelected = selectedMovie?.id === item.id;

    return (
      <TouchableOpacity onPress={() => handleSelectMovie(item)}>
        <View style={[styles.resultCard, isSelected && styles.selectedCard]}>
          {posterUrl ? (
            <Image source={{ uri: posterUrl }} style={styles.poster} />
          ) : (
            <View style={[styles.poster, styles.posterPlaceholder]}>
              <Text variant="bodySmall" style={styles.placeholderText}>
                No Poster
              </Text>
            </View>
          )}

          <View style={styles.resultContent}>
            <Text variant="titleMedium" style={styles.resultTitle} numberOfLines={2}>
              {item.title}
            </Text>
            <Text variant="bodySmall" style={styles.resultYear}>
              {item.year || 'N/A'}
            </Text>
            <Text variant="bodySmall" style={styles.resultOverview} numberOfLines={3}>
              {item.overview || 'No description available'}
            </Text>
          </View>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <>
      <Stack.Screen
        options={{
          title: 'Add Movie',
          headerShown: true,
          headerStyle: { backgroundColor: '#1c1c1e' },
          headerTintColor: '#fff',
        }}
      />

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.container}
      >
        <View style={styles.searchContainer}>
          <Searchbar
            placeholder="Search for a movie..."
            onChangeText={setSearchQuery}
            value={searchQuery}
            onSubmitEditing={handleSearch}
            style={styles.searchbar}
          />

          {!selectedMovie && searchQuery.trim().length > 0 && (
            <View style={styles.quickAddContainer}>
              <Button
                mode="contained-tonal"
                onPress={handleQuickAddOffline}
                loading={isAdding}
                disabled={isAdding}
              >
                Add "{searchQuery.trim()}" offline
              </Button>
            </View>
          )}

          {!selectedMovie && (
            <>
              {isSearching ? (
                <View style={styles.loadingContainer}>
                  <ActivityIndicator size="large" color="#DBA506" />
                </View>
              ) : searchResults.length > 0 ? (
                <FlatList
                  data={searchResults}
                  keyExtractor={(item) => item.id.toString()}
                  renderItem={renderSearchResult}
                  contentContainerStyle={styles.results}
                />
              ) : (
                <View style={styles.emptyState}>
                  <Text variant="bodyLarge" style={styles.emptyText}>
                    Search for movies on TMDB
                  </Text>
                </View>
              )}
            </>
          )}

          {selectedMovie && (
            <ScrollView style={styles.selectedContainer}>
              <Text variant="titleLarge" style={styles.selectedTitle}>
                {selectedMovie.title}
              </Text>
              <Text variant="bodyMedium" style={styles.selectedYear}>
                {selectedMovie.year || 'N/A'}
              </Text>

              <Text variant="titleSmall" style={styles.sectionLabel}>
                Who recommended this?
              </Text>

              {people.length > 0 && (
                <View style={styles.peopleChips}>
                  {people.map((p) => (
                    <Chip
                      key={p.name}
                      selected={selectedPerson === p.name}
                      onPress={() => {
                        setSelectedPerson(selectedPerson === p.name ? '' : p.name);
                        setShowCustomInput(false);
                        setCustomPerson('');
                      }}
                      style={[
                        styles.chip,
                        selectedPerson === p.name && { backgroundColor: p.color || '#DBA506' },
                      ]}
                      textStyle={selectedPerson === p.name ? styles.chipTextSelected : styles.chipText}
                      showSelectedOverlay={false}
                    >
                      {p.emoji ? `${p.emoji} ${p.name}` : p.name}
                    </Chip>
                  ))}
                  <Chip
                    icon="plus"
                    onPress={() => {
                      setShowCustomInput(!showCustomInput);
                      setSelectedPerson('');
                    }}
                    style={[styles.chip, showCustomInput && styles.chipActive]}
                    textStyle={showCustomInput ? styles.chipTextSelected : styles.chipText}
                  >
                    New Person
                  </Chip>
                </View>
              )}

              {(showCustomInput || people.length === 0) && (
                <TextInput
                  label="Enter name"
                  value={customPerson}
                  onChangeText={(text) => {
                    setCustomPerson(text);
                    setSelectedPerson('');
                  }}
                  autoCapitalize="words"
                  style={styles.input}
                  mode="outlined"
                />
              )}

              <View style={styles.buttonContainer}>
                <Button
                  mode="outlined"
                  onPress={() => setSelectedMovie(null)}
                  style={styles.button}
                  disabled={isAdding}
                >
                  Change Movie
                </Button>

                <Button
                  mode="contained"
                  onPress={handleAddMovie}
                  loading={isAdding}
                  disabled={isAdding}
                  style={styles.button}
                >
                  Add Movie
                </Button>
              </View>
            </ScrollView>
          )}
        </View>
      </KeyboardAvoidingView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  searchContainer: {
    flex: 1,
  },
  searchbar: {
    margin: 16,
    backgroundColor: '#1c1c1e',
  },
  quickAddContainer: {
    paddingHorizontal: 16,
    paddingBottom: 8,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    color: '#8e8e93',
    textAlign: 'center',
  },
  results: {
    paddingBottom: 20,
  },
  resultCard: {
    flexDirection: 'row',
    padding: 12,
    marginHorizontal: 16,
    marginVertical: 8,
    backgroundColor: '#1c1c1e',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  selectedCard: {
    borderColor: '#DBA506',
  },
  poster: {
    width: 60,
    height: 90,
    borderRadius: 4,
  },
  posterPlaceholder: {
    backgroundColor: '#38383a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    color: '#8e8e93',
    fontSize: 10,
  },
  resultContent: {
    flex: 1,
    marginLeft: 12,
  },
  resultTitle: {
    color: '#fff',
    marginBottom: 4,
  },
  resultYear: {
    color: '#8e8e93',
    marginBottom: 4,
  },
  resultOverview: {
    color: '#8e8e93',
  },
  selectedContainer: {
    padding: 16,
  },
  selectedTitle: {
    color: '#fff',
    marginBottom: 4,
  },
  selectedYear: {
    color: '#8e8e93',
    marginBottom: 16,
  },
  sectionLabel: {
    color: '#8e8e93',
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  peopleChips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 16,
  },
  chip: {
    backgroundColor: '#1c1c1e',
    borderColor: '#38383a',
    borderWidth: 1,
  },
  chipActive: {
    backgroundColor: '#DBA506',
    borderColor: '#DBA506',
  },
  chipText: {
    color: '#fff',
  },
  chipTextSelected: {
    color: '#fff',
    fontWeight: '600',
  },
  input: {
    marginBottom: 16,
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
  },
});
