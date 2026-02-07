import React, { useEffect, useState } from 'react';
import {
  View,
  StyleSheet,
  ScrollView,
  Image,
  Alert,
  TouchableOpacity,
} from 'react-native';
import { Text, Button, Chip, IconButton, Divider } from 'react-native-paper';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { useAuthStore } from '../../src/stores/authStore';
import { MovieWithDetails } from '../../src/types';
import { Star, ThumbsUp, ThumbsDown, Trash2 } from 'lucide-react-native';
import {
  getBackdropUrl,
  getMovieGenres,
  getMovieOverview,
  getMovieRuntime,
  getMovieTagline,
  getMovieTitle,
  getMovieVoteAverage,
  getMovieYear,
  getPosterUrl,
} from '../../src/utils/movieData';

export default function MovieDetailScreen() {
  const { imdbId } = useLocalSearchParams<{ imdbId: string }>();
  const [movie, setMovie] = useState<MovieWithDetails | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const getMovie = useMoviesStore((state) => state.getMovie);
  const markAsWatched = useMoviesStore((state) => state.markAsWatched);
  const updateRating = useMoviesStore((state) => state.updateRating);
  const updateRecommendationVote = useMoviesStore(
    (state) => state.updateRecommendationVote
  );
  const removeRecommendation = useMoviesStore((state) => state.removeRecommendation);
  const deleteMovie = useMoviesStore((state) => state.deleteMovie);
  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    loadMovie();
  }, [imdbId]);

  const loadMovie = async () => {
    if (!imdbId) return;
    const movieData = await getMovie(imdbId);
    setMovie(movieData);
  };

  const handleMarkAsWatched = () => {
    if (!user || !movie) return;

    Alert.prompt(
      'Rate this movie',
      'Enter your rating (1-10)',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Submit',
          onPress: async (rating?: string) => {
            if (!rating) return;
            const numRating = parseFloat(rating);

            if (isNaN(numRating) || numRating < 1 || numRating > 10) {
              Alert.alert('Error', 'Please enter a valid rating between 1 and 10');
              return;
            }

            setIsLoading(true);
            try {
              await markAsWatched(movie.imdb_id, user.id, numRating);
              await loadMovie();
              Alert.alert('Success', 'Movie marked as watched!');
            } catch (error) {
              Alert.alert('Error', 'Failed to mark as watched');
            } finally {
              setIsLoading(false);
            }
          },
        },
      ],
      'plain-text',
      movie.watch_history?.my_rating.toString() || ''
    );
  };

  const handleUpdateRating = () => {
    if (!movie?.watch_history) return;

    Alert.prompt(
      'Update rating',
      'Enter your new rating (1-10)',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Update',
          onPress: async (rating?: string) => {
            if (!rating) return;
            const numRating = parseFloat(rating);

            if (isNaN(numRating) || numRating < 1 || numRating > 10) {
              Alert.alert('Error', 'Please enter a valid rating between 1 and 10');
              return;
            }

            setIsLoading(true);
            try {
              await updateRating(movie.imdb_id, numRating);
              await loadMovie();
              Alert.alert('Success', 'Rating updated!');
            } catch (error) {
              Alert.alert('Error', 'Failed to update rating');
            } finally {
              setIsLoading(false);
            }
          },
        },
      ],
      'plain-text',
      movie.watch_history.my_rating.toString()
    );
  };

  const handleToggleVote = async (person: string, currentVoteType: string) => {
    if (!movie) return;

    const newVoteType = currentVoteType === 'upvote' ? 'downvote' : 'upvote';

    setIsLoading(true);
    try {
      await updateRecommendationVote(movie.imdb_id, person, newVoteType);
      await loadMovie();
    } catch (error) {
      Alert.alert('Error', 'Failed to update vote');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveRecommendation = (person: string) => {
    if (!movie) return;

    Alert.alert(
      'Remove Recommendation',
      `Remove ${person}'s recommendation?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            setIsLoading(true);
            try {
              await removeRecommendation(movie.imdb_id, person);
              await loadMovie();
              Alert.alert('Success', 'Recommendation removed');
            } catch (error) {
              Alert.alert('Error', 'Failed to remove recommendation');
            } finally {
              setIsLoading(false);
            }
          },
        },
      ]
    );
  };

  const handleDeleteMovie = () => {
    if (!movie) return;

    Alert.alert(
      'Delete Movie',
      'Are you sure you want to delete this movie?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            setIsLoading(true);
            try {
              await deleteMovie(movie.imdb_id);
              router.back();
            } catch (error) {
              Alert.alert('Error', 'Failed to delete movie');
              setIsLoading(false);
            }
          },
        },
      ]
    );
  };

  if (!movie) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Movie not found</Text>
      </View>
    );
  }

  const { recommendations, watch_history } = movie;
  const title = getMovieTitle(movie);
  const year = getMovieYear(movie);
  const voteAverage = getMovieVoteAverage(movie);
  const runtime = getMovieRuntime(movie);
  const tagline = getMovieTagline(movie);
  const overview = getMovieOverview(movie);
  const genres = getMovieGenres(movie);
  const posterUrl = getPosterUrl(movie);
  const backdropUrl = getBackdropUrl(movie);

  const upvotes = recommendations.filter((r) => r.vote_type === 'upvote');
  const downvotes = recommendations.filter((r) => r.vote_type === 'downvote');

  return (
    <>
      <Stack.Screen
        options={{
          title: title || 'Movie Details',
          headerShown: true,
          headerStyle: { backgroundColor: '#1c1c1e' },
          headerTintColor: '#fff',
          headerRight: () => (
            <IconButton
              icon={() => <Trash2 size={20} color="#ff3b30" />}
              onPress={handleDeleteMovie}
            />
          ),
        }}
      />

      <ScrollView style={styles.container}>
        {backdropUrl && (
          <Image source={{ uri: backdropUrl }} style={styles.backdrop} />
        )}

        <View style={styles.content}>
          <View style={styles.header}>
            {posterUrl && (
              <Image source={{ uri: posterUrl }} style={styles.poster} />
            )}

            <View style={styles.headerText}>
              <Text variant="headlineSmall" style={styles.title}>
                {title}
              </Text>

              <Text variant="bodyMedium" style={styles.year}>
                {year}
              </Text>

              {voteAverage ? (
                <View style={styles.rating}>
                  <Star size={16} color="#ffd700" fill="#ffd700" />
                  <Text variant="bodyMedium" style={styles.ratingText}>
                    {voteAverage.toFixed(1)} / 10
                  </Text>
                </View>
              ) : null}

              {runtime ? (
                <Text variant="bodySmall" style={styles.runtime}>
                  {runtime}
                </Text>
              ) : null}
            </View>
          </View>

          {tagline ? (
            <Text variant="bodyMedium" style={styles.tagline}>
              "{tagline}"
            </Text>
          ) : null}

          {overview ? (
            <>
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Overview
              </Text>
              <Text variant="bodyMedium" style={styles.overview}>
                {overview}
              </Text>
            </>
          ) : null}

          {genres.length > 0 && (
            <>
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Genres
              </Text>
              <View style={styles.genres}>
                {genres.map((genre) => (
                  <Chip key={genre} style={styles.genreChip} textStyle={styles.genreText}>
                    {genre}
                  </Chip>
                ))}
              </View>
            </>
          )}

          <Divider style={styles.divider} />

          {watch_history ? (
            <View style={styles.watchedSection}>
              <Text variant="titleMedium" style={styles.sectionTitle}>
                Your Rating
              </Text>
              <View style={styles.myRating}>
                <Star size={24} color="#DBA506" fill="#DBA506" />
                <Text variant="headlineMedium" style={styles.myRatingText}>
                  {watch_history.my_rating.toFixed(1)}
                </Text>
              </View>
              <Button mode="outlined" onPress={handleUpdateRating} disabled={isLoading}>
                Update Rating
              </Button>
            </View>
          ) : (
            <Button
              mode="contained"
              onPress={handleMarkAsWatched}
              disabled={isLoading}
              style={styles.watchButton}
            >
              Mark as Watched
            </Button>
          )}

          <Divider style={styles.divider} />

          <Text variant="titleMedium" style={styles.sectionTitle}>
            Recommendations
          </Text>

          {upvotes.length > 0 && (
            <>
              <Text variant="titleSmall" style={styles.voteTypeTitle}>
                Upvotes ({upvotes.length})
              </Text>
              {upvotes.map((rec) => (
                <View key={rec.person} style={styles.recommendationItem}>
                  <TouchableOpacity
                    onPress={() => handleToggleVote(rec.person, rec.vote_type)}
                    style={styles.voteButton}
                  >
                    <ThumbsUp size={20} color="#34c759" fill="#34c759" />
                  </TouchableOpacity>
                  <Text variant="bodyMedium" style={styles.personName}>
                    {rec.person}
                  </Text>
                  <IconButton
                    icon={() => <Trash2 size={16} color="#ff3b30" />}
                    size={20}
                    onPress={() => handleRemoveRecommendation(rec.person)}
                  />
                </View>
              ))}
            </>
          )}

          {downvotes.length > 0 && (
            <>
              <Text variant="titleSmall" style={styles.voteTypeTitle}>
                Downvotes ({downvotes.length})
              </Text>
              {downvotes.map((rec) => (
                <View key={rec.person} style={styles.recommendationItem}>
                  <TouchableOpacity
                    onPress={() => handleToggleVote(rec.person, rec.vote_type)}
                    style={styles.voteButton}
                  >
                    <ThumbsDown size={20} color="#ff3b30" fill="#ff3b30" />
                  </TouchableOpacity>
                  <Text variant="bodyMedium" style={styles.personName}>
                    {rec.person}
                  </Text>
                  <IconButton
                    icon={() => <Trash2 size={16} color="#ff3b30" />}
                    size={20}
                    onPress={() => handleRemoveRecommendation(rec.person)}
                  />
                </View>
              ))}
            </>
          )}

          {recommendations.length === 0 && (
            <Text variant="bodyMedium" style={styles.noRecommendations}>
              No recommendations yet
            </Text>
          )}
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  backdrop: {
    width: '100%',
    height: 200,
  },
  content: {
    padding: 16,
  },
  header: {
    flexDirection: 'row',
    marginBottom: 16,
  },
  poster: {
    width: 100,
    height: 150,
    borderRadius: 8,
    marginRight: 16,
  },
  headerText: {
    flex: 1,
  },
  title: {
    color: '#fff',
    marginBottom: 8,
  },
  year: {
    color: '#8e8e93',
    marginBottom: 8,
  },
  rating: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  ratingText: {
    color: '#fff',
    marginLeft: 4,
  },
  runtime: {
    color: '#8e8e93',
  },
  tagline: {
    color: '#8e8e93',
    fontStyle: 'italic',
    marginBottom: 16,
  },
  sectionTitle: {
    color: '#fff',
    marginTop: 16,
    marginBottom: 8,
  },
  overview: {
    color: '#fff',
    lineHeight: 22,
  },
  genres: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  genreChip: {
    backgroundColor: '#38383a',
  },
  genreText: {
    color: '#fff',
  },
  divider: {
    backgroundColor: '#38383a',
    marginVertical: 16,
  },
  watchedSection: {
    alignItems: 'center',
  },
  myRating: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginVertical: 16,
  },
  myRatingText: {
    color: '#fff',
  },
  watchButton: {
    marginVertical: 8,
  },
  voteTypeTitle: {
    color: '#8e8e93',
    marginTop: 8,
    marginBottom: 8,
  },
  recommendationItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    gap: 12,
  },
  voteButton: {
    padding: 8,
  },
  personName: {
    flex: 1,
    color: '#fff',
  },
  noRecommendations: {
    color: '#8e8e93',
    textAlign: 'center',
    marginTop: 8,
  },
  errorText: {
    color: '#ff3b30',
    textAlign: 'center',
    marginTop: 20,
  },
});
