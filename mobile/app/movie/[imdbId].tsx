import React, { useEffect, useState } from 'react';
import {
  Alert,
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack, router, useLocalSearchParams } from 'expo-router';
import { Button, Chip, Dialog, Portal, TextInput } from 'react-native-paper';
import {
  ChevronLeft,
  RefreshCw,
  Star,
  ThumbsDown,
  ThumbsUp,
  Trash2,
} from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { useAuthStore } from '../../src/stores/authStore';
import { usePeopleStore } from '../../src/stores/peopleStore';
import { useListsStore } from '../../src/stores/listsStore';
import { MovieWithDetails } from '../../src/types';
import CircleButton from '../../src/components/ui/CircleButton';
import { COLORS } from '../../src/utils/constants';
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
import { refreshMovie as refreshMovieApi } from '../../src/services/api/movies';

function StatusPill({ label }: { label: string }) {
  return (
    <View style={styles.statusPill}>
      <Text style={styles.statusPillText}>{label}</Text>
    </View>
  );
}

export default function MovieDetailScreen() {
  const { imdbId } = useLocalSearchParams<{ imdbId: string }>();
  const insets = useSafeAreaInsets();

  const [movie, setMovie] = useState<MovieWithDetails | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const [showRecommendationDialog, setShowRecommendationDialog] = useState(false);
  const [recommendationVoteType, setRecommendationVoteType] = useState<'upvote' | 'downvote'>('upvote');
  const [selectedPerson, setSelectedPerson] = useState('');
  const [customPerson, setCustomPerson] = useState('');

  const [showListDialog, setShowListDialog] = useState(false);
  const [selectedListId, setSelectedListId] = useState('');

  const getMovie = useMoviesStore((state) => state.getMovie);
  const markAsWatched = useMoviesStore((state) => state.markAsWatched);
  const updateRating = useMoviesStore((state) => state.updateRating);
  const updateRecommendationVote = useMoviesStore((state) => state.updateRecommendationVote);
  const removeRecommendation = useMoviesStore((state) => state.removeRecommendation);
  const addRecommendation = useMoviesStore((state) => state.addRecommendation);
  const updateStatus = useMoviesStore((state) => state.updateStatus);
  const loadMovies = useMoviesStore((state) => state.loadMovies);

  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);

  const lists = useListsStore((state) => state.lists);
  const loadLists = useListsStore((state) => state.loadLists);

  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    loadMovie();
    loadPeople();
    loadLists();
  }, [imdbId, loadPeople, loadLists]);

  const loadMovie = async () => {
    if (!imdbId) return;
    const movieData = await getMovie(imdbId);
    setMovie(movieData);
  };

  const openRecommendationDialog = (voteType: 'upvote' | 'downvote') => {
    setRecommendationVoteType(voteType);
    setSelectedPerson('');
    setCustomPerson('');
    setShowRecommendationDialog(true);
  };

  const handleAddRecommendation = async () => {
    if (!movie || !user) return;

    const person = selectedPerson || customPerson.trim();
    if (!person) {
      Alert.alert('Select Person', 'Choose a person or enter a name.');
      return;
    }

    setIsLoading(true);
    try {
      await addRecommendation(movie.imdb_id, user.id, person, recommendationVoteType);
      setShowRecommendationDialog(false);
      await loadMovie();
    } catch (_error) {
      Alert.alert('Error', 'Failed to add recommendation');
    } finally {
      setIsLoading(false);
    }
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

            if (Number.isNaN(numRating) || numRating < 1 || numRating > 10) {
              Alert.alert('Error', 'Please enter a valid rating between 1 and 10');
              return;
            }

            setIsLoading(true);
            try {
              await markAsWatched(movie.imdb_id, user.id, numRating);
              await loadMovie();
            } catch (_error) {
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

            if (Number.isNaN(numRating) || numRating < 1 || numRating > 10) {
              Alert.alert('Error', 'Please enter a valid rating between 1 and 10');
              return;
            }

            setIsLoading(true);
            try {
              await updateRating(movie.imdb_id, numRating);
              await loadMovie();
            } catch (_error) {
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

  const handleToggleVote = async (person: string, currentVoteType: 'upvote' | 'downvote') => {
    if (!movie) return;

    const newVoteType = currentVoteType === 'upvote' ? 'downvote' : 'upvote';

    setIsLoading(true);
    try {
      await updateRecommendationVote(movie.imdb_id, person, newVoteType);
      await loadMovie();
    } catch (_error) {
      Alert.alert('Error', 'Failed to update vote');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveRecommendation = (person: string) => {
    if (!movie) return;

    Alert.alert('Remove Recommendation', `Remove ${person}'s recommendation?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Remove',
        style: 'destructive',
        onPress: async () => {
          setIsLoading(true);
          try {
            await removeRecommendation(movie.imdb_id, person);
            await loadMovie();
          } catch (_error) {
            Alert.alert('Error', 'Failed to remove recommendation');
          } finally {
            setIsLoading(false);
          }
        },
      },
    ]);
  };

  const handleSetStatus = async (
    status: 'toWatch' | 'watched' | 'deleted' | 'custom',
    customListId?: string
  ) => {
    if (!movie || !user) return;

    setIsLoading(true);
    try {
      await updateStatus(movie.imdb_id, user.id, status, customListId);
      await loadMovie();
    } catch (_error) {
      Alert.alert('Error', 'Failed to update movie status');
    } finally {
      setIsLoading(false);
    }
  };

  const handleMoveToList = async () => {
    if (!selectedListId) {
      Alert.alert('Select List', 'Choose a list first.');
      return;
    }

    await handleSetStatus('custom', selectedListId);
    setShowListDialog(false);
    setSelectedListId('');
  };

  const handleRefreshMovie = async () => {
    if (!movie) return;

    setIsRefreshing(true);
    try {
      await refreshMovieApi(movie.imdb_id);
      await loadMovie();
      await loadMovies();
      Alert.alert('Refreshed', 'Movie metadata was refreshed.');
    } catch (_error) {
      Alert.alert('Error', 'Failed to refresh movie data');
    } finally {
      setIsRefreshing(false);
    }
  };

  const status = movie?.status.status;
  const actionBarConfig =
    status === 'watched'
      ? {
          primaryLabel: 'Update Rating',
          primaryAction: handleUpdateRating,
          secondaryLabel: 'Move to To Watch',
          secondaryAction: () => handleSetStatus('toWatch'),
          secondaryDestructive: false,
        }
      : status === 'deleted'
      ? {
          primaryLabel: 'Restore to To Watch',
          primaryAction: () => handleSetStatus('toWatch'),
          secondaryLabel: '',
          secondaryAction: () => undefined,
          secondaryDestructive: false,
        }
      : {
          primaryLabel: 'Mark as Watched',
          primaryAction: handleMarkAsWatched,
          secondaryLabel: 'Delete from List',
          secondaryAction: () => handleSetStatus('deleted'),
          secondaryDestructive: true,
        };

  if (!movie) {
    return (
      <View style={styles.loadingWrap}>
        <Text style={styles.errorText}>Movie not found</Text>
      </View>
    );
  }

  const title = getMovieTitle(movie);
  const year = getMovieYear(movie);
  const voteAverage = getMovieVoteAverage(movie);
  const runtime = getMovieRuntime(movie);
  const tagline = getMovieTagline(movie);
  const overview = getMovieOverview(movie);
  const genres = getMovieGenres(movie);
  const posterUrl = getPosterUrl(movie);
  const backdropUrl = getBackdropUrl(movie);

  const upvotes = movie.recommendations.filter((recommendation) => recommendation.vote_type === 'upvote');
  const downvotes = movie.recommendations.filter((recommendation) => recommendation.vote_type === 'downvote');

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: COLORS.background },
          headerBackVisible: false,
          headerTitleAlign: 'center',
          headerTitle: () => <Text style={styles.headerTitle}>{title}</Text>,
          headerLeft: () => <CircleButton icon={ChevronLeft} onPress={() => router.back()} />,
          headerRight: () => (
            <CircleButton
              icon={RefreshCw}
              onPress={handleRefreshMovie}
              iconColor={isRefreshing ? COLORS.textSecondary : COLORS.text}
            />
          ),
        }}
      />

      <ScrollView
        style={styles.container}
        contentContainerStyle={{
          paddingBottom: 180 + insets.bottom,
        }}
      >
        {backdropUrl ? <Image source={{ uri: backdropUrl }} style={styles.backdrop} /> : null}

        <View style={styles.content}>
          <View style={styles.headerSection}>
            {posterUrl ? <Image source={{ uri: posterUrl }} style={styles.poster} /> : null}

            <View style={styles.headerTextWrap}>
              <Text style={styles.title}>{title}</Text>
              <Text style={styles.subtitle}>{year}</Text>

              {voteAverage ? (
                <View style={styles.ratingRow}>
                  <Star size={15} color="#ffd60a" fill="#ffd60a" />
                  <Text style={styles.ratingText}>{voteAverage.toFixed(1)} / 10</Text>
                </View>
              ) : null}

              {runtime ? <Text style={styles.runtime}>{runtime}</Text> : null}
              <StatusPill label={movie.status.status} />
            </View>
          </View>

          {tagline ? <Text style={styles.tagline}>"{tagline}"</Text> : null}

          {overview ? (
            <>
              <Text style={styles.sectionTitle}>Overview</Text>
              <Text style={styles.overview}>{overview}</Text>
            </>
          ) : null}

          {genres.length > 0 ? (
            <>
              <Text style={styles.sectionTitle}>Genres</Text>
              <View style={styles.genreWrap}>
                {genres.map((genre) => (
                  <Chip key={genre} style={styles.genreChip} textStyle={styles.genreChipText}>
                    {genre}
                  </Chip>
                ))}
              </View>
            </>
          ) : null}

          {lists.length > 0 && movie.status.status !== 'deleted' ? (
            <Pressable
              onPress={() => setShowListDialog(true)}
              style={({ pressed }) => [styles.addToListButton, pressed && styles.pressed]}
            >
              <Text style={styles.addToListButtonText}>Add to List</Text>
            </Pressable>
          ) : null}

          <Text style={styles.sectionTitle}>Recommendations</Text>
          <View style={styles.addVoteRow}>
            <Pressable
              onPress={() => openRecommendationDialog('upvote')}
              style={({ pressed }) => [styles.voteActionButton, pressed && styles.pressed]}
            >
              <ThumbsUp size={14} color={COLORS.success} />
              <Text style={styles.voteActionText}>+ Add Upvote</Text>
            </Pressable>

            <Pressable
              onPress={() => openRecommendationDialog('downvote')}
              style={({ pressed }) => [styles.voteActionButton, pressed && styles.pressed]}
            >
              <ThumbsDown size={14} color={COLORS.error} />
              <Text style={styles.voteActionText}>+ Add Downvote</Text>
            </Pressable>
          </View>

          {upvotes.length > 0 ? <Text style={styles.voteLabel}>Upvotes ({upvotes.length})</Text> : null}
          {upvotes.map((recommendation) => (
            <View key={`up_${recommendation.person}`} style={styles.recRow}>
              <Pressable
                onPress={() => handleToggleVote(recommendation.person, recommendation.vote_type)}
                style={({ pressed }) => [styles.voteToggle, pressed && styles.pressed]}
              >
                <ThumbsUp size={16} color={COLORS.success} />
              </Pressable>

              <Text style={styles.recName}>{recommendation.person}</Text>

              <Pressable
                onPress={() => handleRemoveRecommendation(recommendation.person)}
                style={({ pressed }) => [styles.removeAction, pressed && styles.pressed]}
              >
                <Trash2 size={14} color={COLORS.error} />
              </Pressable>
            </View>
          ))}

          {downvotes.length > 0 ? <Text style={styles.voteLabel}>Downvotes ({downvotes.length})</Text> : null}
          {downvotes.map((recommendation) => (
            <View key={`down_${recommendation.person}`} style={styles.recRow}>
              <Pressable
                onPress={() => handleToggleVote(recommendation.person, recommendation.vote_type)}
                style={({ pressed }) => [styles.voteToggle, pressed && styles.pressed]}
              >
                <ThumbsDown size={16} color={COLORS.error} />
              </Pressable>

              <Text style={styles.recName}>{recommendation.person}</Text>

              <Pressable
                onPress={() => handleRemoveRecommendation(recommendation.person)}
                style={({ pressed }) => [styles.removeAction, pressed && styles.pressed]}
              >
                <Trash2 size={14} color={COLORS.error} />
              </Pressable>
            </View>
          ))}

          {movie.recommendations.length === 0 ? (
            <Text style={styles.noRecommendations}>No recommendations yet</Text>
          ) : null}
        </View>
      </ScrollView>

      <View style={[styles.actionBar, { bottom: 18 + insets.bottom }]}>
        <Button
          mode="contained"
          onPress={actionBarConfig.primaryAction}
          disabled={isLoading || isRefreshing}
          style={styles.primaryActionButton}
        >
          {actionBarConfig.primaryLabel}
        </Button>

        {actionBarConfig.secondaryLabel ? (
          <Pressable
            onPress={actionBarConfig.secondaryAction}
            style={({ pressed }) => [styles.secondaryActionWrap, pressed && styles.pressed]}
          >
            <Text
              style={[
                styles.secondaryActionText,
                actionBarConfig.secondaryDestructive ? styles.destructiveText : undefined,
              ]}
            >
              {actionBarConfig.secondaryLabel}
            </Text>
          </Pressable>
        ) : null}
      </View>

      <Portal>
        <Dialog
          visible={showRecommendationDialog}
          onDismiss={() => setShowRecommendationDialog(false)}
        >
          <Dialog.Title>
            {recommendationVoteType === 'upvote' ? 'Add Upvote' : 'Add Downvote'}
          </Dialog.Title>
          <Dialog.Content>
            <View style={styles.personChipsWrap}>
              {people.map((person) => (
                <Chip
                  key={person.name}
                  selected={selectedPerson === person.name}
                  onPress={() => {
                    setSelectedPerson(selectedPerson === person.name ? '' : person.name);
                    setCustomPerson('');
                  }}
                  style={styles.personChip}
                >
                  {person.name}
                </Chip>
              ))}
            </View>
            <TextInput
              label="Or enter name"
              value={customPerson}
              onChangeText={(value) => {
                setCustomPerson(value);
                setSelectedPerson('');
              }}
              mode="outlined"
              style={styles.customPersonInput}
            />
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setShowRecommendationDialog(false)}>Cancel</Button>
            <Button onPress={handleAddRecommendation} loading={isLoading}>
              Add
            </Button>
          </Dialog.Actions>
        </Dialog>

        <Dialog visible={showListDialog} onDismiss={() => setShowListDialog(false)}>
          <Dialog.Title>Add to List</Dialog.Title>
          <Dialog.Content>
            <View style={styles.personChipsWrap}>
              {lists.map((list) => (
                <Chip
                  key={list.id}
                  selected={selectedListId === list.id}
                  onPress={() => setSelectedListId(selectedListId === list.id ? '' : list.id)}
                  style={styles.personChip}
                >
                  {list.name}
                </Chip>
              ))}
            </View>
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setShowListDialog(false)}>Cancel</Button>
            <Button onPress={handleMoveToList} loading={isLoading}>
              Save
            </Button>
          </Dialog.Actions>
        </Dialog>
      </Portal>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  loadingWrap: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  errorText: {
    color: COLORS.error,
  },
  headerTitle: {
    color: COLORS.text,
    fontSize: 17,
    fontWeight: '600',
  },
  backdrop: {
    width: '100%',
    height: 210,
  },
  content: {
    padding: 16,
  },
  headerSection: {
    flexDirection: 'row',
    gap: 14,
    marginBottom: 14,
  },
  poster: {
    width: 110,
    height: 165,
    borderRadius: 10,
    backgroundColor: '#2c2c2e',
  },
  headerTextWrap: {
    flex: 1,
  },
  title: {
    color: COLORS.text,
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    color: COLORS.textSecondary,
    marginTop: 5,
    fontSize: 14,
  },
  ratingRow: {
    marginTop: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  ratingText: {
    color: COLORS.text,
    fontSize: 14,
  },
  runtime: {
    color: COLORS.textSecondary,
    marginTop: 6,
    fontSize: 13,
  },
  statusPill: {
    marginTop: 10,
    alignSelf: 'flex-start',
    backgroundColor: '#2c2c2e',
    borderRadius: 12,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  statusPillText: {
    color: COLORS.textSecondary,
    fontSize: 12,
    fontWeight: '600',
  },
  tagline: {
    color: COLORS.textSecondary,
    fontStyle: 'italic',
    marginBottom: 12,
  },
  sectionTitle: {
    color: COLORS.text,
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 8,
    marginTop: 10,
  },
  overview: {
    color: COLORS.text,
    lineHeight: 22,
  },
  genreWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  genreChip: {
    backgroundColor: '#2c2c2e',
  },
  genreChipText: {
    color: COLORS.text,
  },
  addToListButton: {
    marginTop: 14,
    alignSelf: 'flex-start',
    backgroundColor: '#2c2c2e',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  addToListButtonText: {
    color: COLORS.text,
    fontWeight: '600',
    fontSize: 13,
  },
  addVoteRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 8,
  },
  voteActionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderRadius: 14,
    backgroundColor: '#2c2c2e',
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  voteActionText: {
    color: COLORS.text,
    fontSize: 13,
    fontWeight: '600',
  },
  voteLabel: {
    color: COLORS.textSecondary,
    marginTop: 8,
    marginBottom: 4,
    fontSize: 13,
    fontWeight: '600',
  },
  recRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    gap: 10,
  },
  voteToggle: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: '#2c2c2e',
    alignItems: 'center',
    justifyContent: 'center',
  },
  recName: {
    flex: 1,
    color: COLORS.text,
    fontSize: 15,
  },
  removeAction: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  noRecommendations: {
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginTop: 6,
  },
  actionBar: {
    position: 'absolute',
    left: 12,
    right: 12,
    borderRadius: 16,
    padding: 12,
    backgroundColor: COLORS.surfaceGroup,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
  },
  primaryActionButton: {
    borderRadius: 12,
  },
  secondaryActionWrap: {
    marginTop: 10,
    alignItems: 'center',
  },
  secondaryActionText: {
    color: COLORS.textSecondary,
    fontSize: 14,
    fontWeight: '600',
  },
  destructiveText: {
    color: COLORS.error,
  },
  personChipsWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  personChip: {
    marginBottom: 8,
    backgroundColor: '#2c2c2e',
  },
  customPersonInput: {
    marginTop: 8,
  },
  pressed: {
    opacity: 0.75,
  },
});
