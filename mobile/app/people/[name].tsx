import React, { useEffect, useMemo } from 'react';
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Href, Stack, router, useLocalSearchParams } from 'expo-router';
import { Switch } from 'react-native-paper';
import { ChevronLeft } from 'lucide-react-native';
import { usePeopleStore } from '../../src/stores/peopleStore';
import { useMoviesStore } from '../../src/stores/moviesStore';
import CircleButton from '../../src/components/ui/CircleButton';
import GroupedList from '../../src/components/ui/GroupedList';
import GroupedListItem from '../../src/components/ui/GroupedListItem';
import { COLORS } from '../../src/utils/constants';
import { getMovieTitle, getMovieYear, getPosterUrl } from '../../src/utils/movieData';

const COLOR_OPTIONS = ['#DBA506', '#0a84ff', '#34c759', '#ff9500', '#5856d6', '#ff2d55', '#00b4d8', '#ffd60a', '#8e8e93'];
const EMOJI_OPTIONS = ['🍿', '🎬', '🎯', '🔥', '🌟', '💡', '🤝', '🎲', '🧠', '📽️'];

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.statBox}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function statusLabel(status: string) {
  if (status === 'watched') return 'Watched';
  if (status === 'deleted') return 'Deleted';
  if (status === 'custom') return 'In List';
  return 'To Watch';
}

export default function PersonDetailScreen() {
  const { name } = useLocalSearchParams<{ name: string }>();
  const decodedName = decodeURIComponent(name || '');

  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);
  const updatePerson = usePeopleStore((state) => state.updatePerson);

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);

  useEffect(() => {
    loadPeople();
    loadMovies();
  }, [loadPeople, loadMovies]);

  const person = useMemo(() => people.find((item) => item.name === decodedName), [people, decodedName]);

  const personMovies = useMemo(
    () => movies.filter((movie) => movie.recommendations.some((rec) => rec.person === decodedName)),
    [movies, decodedName]
  );

  const stats = useMemo(() => {
    let upvotes = 0;
    let downvotes = 0;
    let watched = 0;

    for (const movie of personMovies) {
      const recommendation = movie.recommendations.find((entry) => entry.person === decodedName);
      if (recommendation?.vote_type === 'upvote') {
        upvotes += 1;
      } else if (recommendation?.vote_type === 'downvote') {
        downvotes += 1;
      }

      if (movie.status.status === 'watched') {
        watched += 1;
      }
    }

    return {
      recs: personMovies.length,
      upvotes,
      downvotes,
      watched,
    };
  }, [personMovies, decodedName]);

  const handleUpdatePerson = async (updates: {
    color?: string;
    emoji?: string;
    is_trusted?: boolean;
  }) => {
    if (!person) return;

    try {
      await updatePerson(person.name, updates);
    } catch (_error) {
      Alert.alert('Error', 'Failed to update person');
    }
  };

  if (!person) {
    return (
      <View style={styles.notFoundWrap}>
        <Text style={styles.notFoundText}>Person not found</Text>
      </View>
    );
  }

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: COLORS.background },
          headerTitleAlign: 'center',
          headerBackVisible: false,
          headerTitle: () => <Text style={styles.headerTitle}>{decodedName}</Text>,
          headerLeft: () => <CircleButton icon={ChevronLeft} onPress={() => router.back()} />,
          headerRight: () => <View style={{ width: 36 }} />,
        }}
      />

      <ScrollView style={styles.container} contentContainerStyle={styles.content}>
        <View style={styles.topCard}>
          <View style={[styles.avatar, { backgroundColor: person.color || COLORS.primary }]}>
            <Text style={styles.avatarText}>{person.emoji || person.name.charAt(0).toUpperCase()}</Text>
          </View>
          <Text style={styles.name}>{person.name}</Text>
        </View>

        <View style={styles.statsRow}>
          <Stat label="Recs" value={stats.recs} />
          <Stat label="Upvotes" value={stats.upvotes} />
          <Stat label="Downvotes" value={stats.downvotes} />
          <Stat label="Watched" value={stats.watched} />
        </View>

        <Text style={styles.sectionTitle}>Edit</Text>
        <GroupedList>
          <GroupedListItem
            title="Trusted"
            subtitle="Prioritize this recommender"
            showChevron={false}
            right={
              <Switch
                value={person.is_trusted}
                onValueChange={(value) => handleUpdatePerson({ is_trusted: value })}
              />
            }
            showDivider
          />
          <View style={styles.editBlock}>
            <Text style={styles.editLabel}>Color</Text>
            <View style={styles.colorRow}>
              {COLOR_OPTIONS.map((color) => (
                <Pressable
                  key={color}
                  onPress={() => handleUpdatePerson({ color })}
                  style={[
                    styles.colorCircle,
                    { backgroundColor: color },
                    person.color === color ? styles.selectedCircle : undefined,
                  ]}
                />
              ))}
            </View>

            <Text style={styles.editLabel}>Emoji</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.emojiRow}>
              {EMOJI_OPTIONS.map((emoji) => (
                <Pressable
                  key={emoji}
                  onPress={() => handleUpdatePerson({ emoji })}
                  style={[styles.emojiPill, person.emoji === emoji ? styles.selectedEmojiPill : undefined]}
                >
                  <Text style={styles.emojiPillText}>{emoji}</Text>
                </Pressable>
              ))}
            </ScrollView>
          </View>
        </GroupedList>

        <Text style={styles.sectionTitle}>Movies</Text>
        {personMovies.length === 0 ? (
          <View style={styles.emptyMoviesWrap}>
            <Text style={styles.emptyMoviesText}>No movies recommended yet.</Text>
          </View>
        ) : (
          <GroupedList>
            {personMovies.map((movie, index) => {
              const poster = getPosterUrl(movie);
              return (
                <GroupedListItem
                  key={movie.imdb_id}
                  title={getMovieTitle(movie)}
                  subtitle={`${getMovieYear(movie)} · ${statusLabel(movie.status.status)}`}
                  onPress={() => router.push(`/movie/${movie.imdb_id}` as Href)}
                  showDivider={index < personMovies.length - 1}
                  left={
                    poster ? (
                      <Image source={{ uri: poster }} style={styles.movieThumb} />
                    ) : (
                      <View style={[styles.movieThumb, styles.movieThumbPlaceholder]} />
                    )
                  }
                  right={<Text style={styles.movieStatus}>{statusLabel(movie.status.status)}</Text>}
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
  topCard: {
    alignItems: 'center',
    marginBottom: 14,
  },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontSize: 30,
    color: '#fff',
  },
  name: {
    color: COLORS.text,
    marginTop: 10,
    fontSize: 20,
    fontWeight: '700',
  },
  statsRow: {
    flexDirection: 'row',
    marginHorizontal: -4,
    marginBottom: 16,
  },
  statBox: {
    flex: 1,
    marginHorizontal: 4,
    borderRadius: 12,
    backgroundColor: COLORS.surfaceGroup,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    paddingVertical: 10,
    alignItems: 'center',
  },
  statValue: {
    color: COLORS.text,
    fontSize: 18,
    fontWeight: '700',
  },
  statLabel: {
    color: COLORS.textSecondary,
    fontSize: 11,
    marginTop: 4,
  },
  sectionTitle: {
    color: COLORS.textSecondary,
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 8,
    marginTop: 6,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  editBlock: {
    padding: 14,
  },
  editLabel: {
    color: COLORS.textSecondary,
    fontSize: 12,
    marginBottom: 8,
    marginTop: 6,
  },
  colorRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  colorCircle: {
    width: 28,
    height: 28,
    borderRadius: 14,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  selectedCircle: {
    borderColor: '#fff',
  },
  emojiRow: {
    gap: 8,
    paddingRight: 12,
    paddingTop: 2,
  },
  emojiPill: {
    minWidth: 38,
    height: 34,
    borderRadius: 10,
    backgroundColor: '#2c2c2e',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  selectedEmojiPill: {
    backgroundColor: COLORS.primary,
  },
  emojiPillText: {
    fontSize: 18,
  },
  movieThumb: {
    width: 30,
    height: 44,
    borderRadius: 5,
    backgroundColor: '#2c2c2e',
  },
  movieThumbPlaceholder: {
    opacity: 0.65,
  },
  movieStatus: {
    color: COLORS.textSecondary,
    fontSize: 12,
    fontWeight: '600',
  },
  emptyMoviesWrap: {
    backgroundColor: COLORS.surfaceGroup,
    borderRadius: 12,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    padding: 18,
    alignItems: 'center',
  },
  emptyMoviesText: {
    color: COLORS.textSecondary,
  },
  notFoundWrap: {
    flex: 1,
    backgroundColor: COLORS.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  notFoundText: {
    color: COLORS.error,
  },
});
