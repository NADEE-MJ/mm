import React, { useState } from 'react';
import {
  View,
  StyleSheet,
  FlatList,
  Image,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { Text, Searchbar, ActivityIndicator, TextInput, Button } from 'react-native-paper';
import { router, Stack } from 'expo-router';
import { searchTMDB, getTMDBMovie, TMDBSearchResult } from '../../src/services/api/movies';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { useAuthStore } from '../../src/stores/authStore';

export default function AddMovieScreen() {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<TMDBSearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedMovie, setSelectedMovie] = useState<TMDBSearchResult | null>(null);
  const [person, setPerson] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const addMovie = useMoviesStore((state) => state.addMovie);
  const user = useAuthStore((state) => state.user);

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

  const handleSelectMovie = (movie: TMDBSearchResult) => {
    setSelectedMovie(movie);
  };

  const handleAddMovie = async () => {
    if (!selectedMovie || !user) return;

    if (!person.trim()) {
      Alert.alert('Error', 'Please enter who recommended this movie');
      return;
    }

    setIsAdding(true);

    try {
      // Get full movie details from TMDB
      const tmdbData = await getTMDBMovie(selectedMovie.id);

      // Extract IMDb ID from TMDB data or generate one
      const imdbId = `tt${selectedMovie.id}`;

      // Add movie with recommendation
      await addMovie(imdbId, user.id, tmdbData, undefined, person, 'upvote');

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
    const posterUrl = item.poster_path
      ? `https://image.tmdb.org/t/p/w500${item.poster_path}`
      : null;

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
              {item.release_date?.substring(0, 4) || 'N/A'}
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

          {!selectedMovie && (
            <>
              {isSearching ? (
                <View style={styles.loadingContainer}>
                  <ActivityIndicator size="large" color="#0a84ff" />
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
            <View style={styles.selectedContainer}>
              <Text variant="titleLarge" style={styles.selectedTitle}>
                {selectedMovie.title}
              </Text>
              <Text variant="bodyMedium" style={styles.selectedYear}>
                {selectedMovie.release_date?.substring(0, 4)}
              </Text>

              <TextInput
                label="Who recommended this?"
                value={person}
                onChangeText={setPerson}
                autoCapitalize="words"
                style={styles.input}
                mode="outlined"
              />

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
            </View>
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
    borderColor: '#0a84ff',
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
