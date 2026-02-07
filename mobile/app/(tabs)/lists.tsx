import React, { useEffect, useState } from 'react';
import { View, StyleSheet, FlatList, Alert } from 'react-native';
import { Text, FAB, Card, IconButton, Portal, Dialog, TextInput, Button } from 'react-native-paper';
import { useListsStore } from '../../src/stores/listsStore';
import { useAuthStore } from '../../src/stores/authStore';
import { CustomList } from '../../src/types';
import { List as ListIcon } from 'lucide-react-native';

export default function ListsScreen() {
  const [dialogVisible, setDialogVisible] = useState(false);
  const [listName, setListName] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const lists = useListsStore((state) => state.lists);
  const loadLists = useListsStore((state) => state.loadLists);
  const createList = useListsStore((state) => state.createList);
  const deleteList = useListsStore((state) => state.deleteList);
  const getListMovieCount = useListsStore((state) => state.getListMovieCount);
  const user = useAuthStore((state) => state.user);

  const [listCounts, setListCounts] = useState<{ [key: string]: number }>({});

  useEffect(() => {
    loadLists();
  }, []);

  useEffect(() => {
    // Load movie counts for all lists
    async function loadCounts() {
      const counts: { [key: string]: number } = {};
      for (const list of lists) {
        counts[list.id] = await getListMovieCount(list.id);
      }
      setListCounts(counts);
    }

    if (lists.length > 0) {
      loadCounts();
    }
  }, [lists]);

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
      Alert.alert('Success', 'List created successfully!');
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to create list');
    } finally {
      setIsAdding(false);
    }
  };

  const handleDeleteList = (list: CustomList) => {
    const movieCount = listCounts[list.id] || 0;

    Alert.alert(
      'Delete List',
      `Are you sure you want to delete "${list.name}"?${
        movieCount > 0 ? ` ${movieCount} movie(s) will be moved to "To Watch".` : ''
      }`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteList(list.id);
              Alert.alert('Success', 'List deleted');
            } catch (error) {
              Alert.alert('Error', 'Failed to delete list');
            }
          },
        },
      ]
    );
  };

  const renderList = ({ item }: { item: CustomList }) => {
    const movieCount = listCounts[item.id] || 0;

    return (
      <Card style={styles.card}>
        <View style={styles.cardContent}>
          <View style={styles.header}>
            <View style={styles.listInfo}>
              <View
                style={[
                  styles.iconContainer,
                  { backgroundColor: item.color || '#DBA506' },
                ]}
              >
                <ListIcon size={24} color="#fff" />
              </View>

              <View style={styles.nameContainer}>
                <Text variant="titleMedium" style={styles.name}>
                  {item.name}
                </Text>
                <Text variant="bodySmall" style={styles.count}>
                  {movieCount} {movieCount === 1 ? 'movie' : 'movies'}
                </Text>
              </View>
            </View>

            <IconButton
              icon="delete"
              iconColor="#ff3b30"
              size={20}
              onPress={() => handleDeleteList(item)}
            />
          </View>
        </View>
      </Card>
    );
  };

  return (
    <View style={styles.container}>
      {lists.length === 0 ? (
        <View style={styles.emptyState}>
          <ListIcon size={64} color="#8e8e93" />
          <Text variant="headlineSmall" style={styles.emptyText}>
            No custom lists yet
          </Text>
          <Text variant="bodyMedium" style={styles.emptySubtext}>
            Create custom lists to organize your movies
          </Text>
        </View>
      ) : (
        <FlatList
          data={lists}
          keyExtractor={(item) => item.id}
          renderItem={renderList}
          contentContainerStyle={styles.list}
        />
      )}

      <FAB
        icon="plus"
        style={styles.fab}
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
              style={styles.input}
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
    backgroundColor: '#000',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    color: '#fff',
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtext: {
    color: '#8e8e93',
    textAlign: 'center',
  },
  list: {
    paddingVertical: 8,
    paddingBottom: 80,
  },
  card: {
    marginHorizontal: 16,
    marginVertical: 8,
    backgroundColor: '#1c1c1e',
  },
  cardContent: {
    padding: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  listInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  nameContainer: {
    flex: 1,
  },
  name: {
    color: '#fff',
    marginBottom: 4,
  },
  count: {
    color: '#8e8e93',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 80,
    backgroundColor: '#DBA506',
  },
  input: {
    marginBottom: 8,
  },
});
