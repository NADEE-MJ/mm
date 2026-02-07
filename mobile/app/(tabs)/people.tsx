import React, { useEffect, useState } from 'react';
import { View, StyleSheet, FlatList, Alert } from 'react-native';
import { Text, FAB, Card, Chip, IconButton, Portal, Dialog, TextInput, Button } from 'react-native-paper';
import { usePeopleStore } from '../../src/stores/peopleStore';
import { useAuthStore } from '../../src/stores/authStore';
import { Person } from '../../src/types';
import { Users } from 'lucide-react-native';

export default function PeopleScreen() {
  const [dialogVisible, setDialogVisible] = useState(false);
  const [personName, setPersonName] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);
  const addPerson = usePeopleStore((state) => state.addPerson);
  const deletePerson = usePeopleStore((state) => state.deletePerson);
  const getPersonStats = usePeopleStore((state) => state.getPersonStats);
  const user = useAuthStore((state) => state.user);

  const [personStats, setPersonStats] = useState<{ [key: string]: any }>({});

  useEffect(() => {
    loadPeople();
  }, []);

  useEffect(() => {
    // Load stats for all people
    async function loadStats() {
      const stats: { [key: string]: any } = {};
      for (const person of people) {
        stats[person.name] = await getPersonStats(person.name);
      }
      setPersonStats(stats);
    }

    if (people.length > 0) {
      loadStats();
    }
  }, [people]);

  const handleAddPerson = async () => {
    if (!personName.trim() || !user) {
      Alert.alert('Error', 'Please enter a name');
      return;
    }

    setIsAdding(true);

    try {
      await addPerson(personName.trim(), user.id);
      setDialogVisible(false);
      setPersonName('');
      Alert.alert('Success', 'Person added successfully!');
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to add person');
    } finally {
      setIsAdding(false);
    }
  };

  const handleDeletePerson = (person: Person) => {
    Alert.alert(
      'Delete Person',
      `Are you sure you want to delete ${person.name}? This will not delete their recommendations.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await deletePerson(person.name);
              Alert.alert('Success', 'Person deleted');
            } catch (error) {
              Alert.alert('Error', 'Failed to delete person');
            }
          },
        },
      ]
    );
  };

  const renderPerson = ({ item }: { item: Person }) => {
    const stats = personStats[item.name] || {
      totalRecommendations: 0,
      upvotes: 0,
      downvotes: 0,
      moviesWatched: 0,
    };

    return (
      <Card style={styles.card}>
        <View style={styles.cardContent}>
          <View style={styles.header}>
            <View style={styles.personInfo}>
              {item.emoji ? (
                <Text style={styles.emoji}>{item.emoji}</Text>
              ) : (
                <View
                  style={[
                    styles.avatar,
                    { backgroundColor: item.color || '#DBA506' },
                  ]}
                >
                  <Text style={styles.avatarText}>
                    {item.name.charAt(0).toUpperCase()}
                  </Text>
                </View>
              )}

              <View style={styles.nameContainer}>
                <Text variant="titleMedium" style={styles.name}>
                  {item.name}
                </Text>

                <View style={styles.badges}>
                  {item.is_trusted && (
                    <Chip style={styles.badge} textStyle={styles.badgeText} compact>
                      Trusted
                    </Chip>
                  )}
                  {item.is_default && (
                    <Chip style={styles.badge} textStyle={styles.badgeText} compact>
                      Default
                    </Chip>
                  )}
                </View>
              </View>
            </View>

            <IconButton
              icon="delete"
              iconColor="#ff3b30"
              size={20}
              onPress={() => handleDeletePerson(item)}
            />
          </View>

          <View style={styles.stats}>
            <View style={styles.stat}>
              <Text variant="titleMedium" style={styles.statValue}>
                {stats.totalRecommendations}
              </Text>
              <Text variant="bodySmall" style={styles.statLabel}>
                Recommendations
              </Text>
            </View>

            <View style={styles.stat}>
              <Text variant="titleMedium" style={styles.statValue}>
                {stats.upvotes}
              </Text>
              <Text variant="bodySmall" style={styles.statLabel}>
                Upvotes
              </Text>
            </View>

            <View style={styles.stat}>
              <Text variant="titleMedium" style={styles.statValue}>
                {stats.downvotes}
              </Text>
              <Text variant="bodySmall" style={styles.statLabel}>
                Downvotes
              </Text>
            </View>

            <View style={styles.stat}>
              <Text variant="titleMedium" style={styles.statValue}>
                {stats.moviesWatched}
              </Text>
              <Text variant="bodySmall" style={styles.statLabel}>
                Watched
              </Text>
            </View>
          </View>
        </View>
      </Card>
    );
  };

  return (
    <View style={styles.container}>
      {people.length === 0 ? (
        <View style={styles.emptyState}>
          <Users size={64} color="#8e8e93" />
          <Text variant="headlineSmall" style={styles.emptyText}>
            No people yet
          </Text>
          <Text variant="bodyMedium" style={styles.emptySubtext}>
            Add people to track their movie recommendations
          </Text>
        </View>
      ) : (
        <FlatList
          data={people}
          keyExtractor={(item) => item.name}
          renderItem={renderPerson}
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
          <Dialog.Title>Add Person</Dialog.Title>
          <Dialog.Content>
            <TextInput
              label="Name"
              value={personName}
              onChangeText={setPersonName}
              autoCapitalize="words"
              style={styles.input}
              mode="outlined"
            />
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setDialogVisible(false)} disabled={isAdding}>
              Cancel
            </Button>
            <Button onPress={handleAddPerson} loading={isAdding} disabled={isAdding}>
              Add
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
    alignItems: 'flex-start',
    marginBottom: 16,
  },
  personInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  emoji: {
    fontSize: 40,
    marginRight: 12,
  },
  avatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  avatarText: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
  },
  nameContainer: {
    flex: 1,
  },
  name: {
    color: '#fff',
    marginBottom: 4,
  },
  badges: {
    flexDirection: 'row',
    gap: 4,
  },
  badge: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    height: 24,
  },
  badgeText: {
    color: '#fff',
    fontSize: 10,
  },
  stats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  stat: {
    alignItems: 'center',
  },
  statValue: {
    color: '#DBA506',
    fontWeight: 'bold',
  },
  statLabel: {
    color: '#8e8e93',
    marginTop: 2,
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
