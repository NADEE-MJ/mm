import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Href, router } from 'expo-router';
import { Button, Dialog, FAB, Portal, TextInput } from 'react-native-paper';
import { List as ListIcon, Trash2 } from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useListsStore } from '../../src/stores/listsStore';
import { useAuthStore } from '../../src/stores/authStore';
import { useMoviesStore } from '../../src/stores/moviesStore';
import GroupedList from '../../src/components/ui/GroupedList';
import GroupedListItem from '../../src/components/ui/GroupedListItem';
import { COLORS } from '../../src/utils/constants';
import { getMovieTitle, getPosterUrl } from '../../src/utils/movieData';

export default function ListsScreen() {
  const insets = useSafeAreaInsets();
  const [dialogVisible, setDialogVisible] = useState(false);
  const [listName, setListName] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const lists = useListsStore((state) => state.lists);
  const loadLists = useListsStore((state) => state.loadLists);
  const createList = useListsStore((state) => state.createList);
  const getListMovieCount = useListsStore((state) => state.getListMovieCount);
  const user = useAuthStore((state) => state.user);

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);

  const [listCounts, setListCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    loadLists();
    loadMovies();
  }, [loadLists, loadMovies]);

  useEffect(() => {
    async function loadCounts() {
      const counts: Record<string, number> = {};
      for (const list of lists) {
        counts[list.id] = await getListMovieCount(list.id);
      }
      setListCounts(counts);
    }

    if (lists.length > 0) {
      loadCounts();
    } else {
      setListCounts({});
    }
  }, [lists, getListMovieCount]);

  const deletedMovies = useMemo(
    () => movies.filter((movie) => movie.status.status === 'deleted'),
    [movies]
  );

  const handleAddList = async () => {
    if (!listName.trim() || !user) {
      Alert.alert('Error', 'Please enter a list name');
      return;
    }

    setIsAdding(true);

    try {
      const id = `list_${Date.now()}`;
      await createList(id, user.id, listName.trim());
      setDialogVisible(false);
      setListName('');
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to create list');
    } finally {
      setIsAdding(false);
    }
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + 8, paddingBottom: 120 + insets.bottom }]}>
        <Text style={styles.largeTitle}>Lists</Text>

        <Text style={styles.sectionTitle}>Deleted Movies</Text>
        <View style={styles.deletedCard}>
          <View style={styles.deletedHeaderRow}>
            <View style={styles.deletedIconWrap}>
              <Trash2 size={16} color={COLORS.error} />
            </View>
            <Text style={styles.deletedCount}>{deletedMovies.length}</Text>
          </View>

          {deletedMovies.length === 0 ? (
            <Text style={styles.deletedEmptyText}>Deleted movies will appear here.</Text>
          ) : (
            <View style={styles.deletedMoviesWrap}>
              {deletedMovies.slice(0, 8).map((movie) => {
                const poster = getPosterUrl(movie);
                return (
                  <Pressable
                    key={movie.imdb_id}
                    style={({ pressed }) => [styles.deletedMovieRow, pressed && styles.pressed]}
                    onPress={() => router.push(`/movie/${movie.imdb_id}` as Href)}
                  >
                    {poster ? (
                      <Image source={{ uri: poster }} style={styles.deletedPoster} />
                    ) : (
                      <View style={[styles.deletedPoster, styles.deletedPosterPlaceholder]} />
                    )}
                    <Text style={styles.deletedMovieTitle} numberOfLines={1}>
                      {getMovieTitle(movie)}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          )}
        </View>

        <Text style={styles.sectionTitle}>Custom Lists</Text>
        {lists.length === 0 ? (
          <View style={styles.emptyState}>
            <ListIcon size={52} color={COLORS.textSecondary} />
            <Text style={styles.emptyTitle}>No custom lists yet</Text>
            <Text style={styles.emptySubtitle}>Create a list to group movies your way.</Text>
          </View>
        ) : (
          <GroupedList>
            {lists.map((item, index) => (
              <GroupedListItem
                key={item.id}
                title={item.name}
                subtitle={`${listCounts[item.id] || 0} ${(listCounts[item.id] || 0) === 1 ? 'movie' : 'movies'}`}
                onPress={() => router.push(`/lists/${item.id}` as Href)}
                left={
                  <View style={[styles.listIconWrap, { backgroundColor: item.color || COLORS.primary }]}>
                    <ListIcon size={16} color="#fff" />
                  </View>
                }
                right={<Text style={styles.listCountText}>{listCounts[item.id] || 0}</Text>}
                showDivider={index < lists.length - 1}
              />
            ))}
          </GroupedList>
        )}
      </ScrollView>

      <FAB
        icon="plus"
        style={[styles.fab, { bottom: 106 + insets.bottom }]}
        onPress={() => setDialogVisible(true)}
      />

      <Portal>
        <Dialog visible={dialogVisible} onDismiss={() => setDialogVisible(false)}>
          <Dialog.Title>Create List</Dialog.Title>
          <Dialog.Content>
            <TextInput
              label="List Name"
              value={listName}
              onChangeText={setListName}
              autoCapitalize="words"
              mode="outlined"
            />
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setDialogVisible(false)} disabled={isAdding}>
              Cancel
            </Button>
            <Button onPress={handleAddList} loading={isAdding} disabled={isAdding}>
              Create
            </Button>
          </Dialog.Actions>
        </Dialog>
      </Portal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  content: {
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 120,
  },
  largeTitle: {
    fontSize: 34,
    fontWeight: '700',
    color: COLORS.text,
    marginBottom: 10,
  },
  sectionTitle: {
    color: COLORS.textSecondary,
    fontSize: 13,
    fontWeight: '700',
    marginTop: 14,
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  deletedCard: {
    borderRadius: 12,
    backgroundColor: COLORS.surfaceGroup,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    padding: 12,
  },
  deletedHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  deletedIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,59,48,0.12)',
  },
  deletedCount: {
    color: COLORS.text,
    fontSize: 18,
    fontWeight: '700',
  },
  deletedEmptyText: {
    color: COLORS.textSecondary,
    fontSize: 13,
  },
  deletedMoviesWrap: {
    gap: 8,
  },
  deletedMovieRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  deletedPoster: {
    width: 30,
    height: 44,
    borderRadius: 6,
    backgroundColor: '#2c2c2e',
  },
  deletedPosterPlaceholder: {
    opacity: 0.6,
  },
  deletedMovieTitle: {
    color: COLORS.text,
    fontSize: 14,
    flex: 1,
  },
  listIconWrap: {
    width: 28,
    height: 28,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listCountText: {
    color: COLORS.textSecondary,
    fontSize: 13,
    fontWeight: '600',
  },
  emptyState: {
    alignItems: 'center',
    paddingTop: 40,
    paddingHorizontal: 20,
  },
  emptyTitle: {
    color: COLORS.text,
    fontSize: 20,
    fontWeight: '700',
    marginTop: 12,
  },
  emptySubtitle: {
    color: COLORS.textSecondary,
    marginTop: 6,
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 106,
    backgroundColor: COLORS.primary,
  },
  pressed: {
    opacity: 0.75,
  },
});
