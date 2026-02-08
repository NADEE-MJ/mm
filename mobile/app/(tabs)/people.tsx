import React, { useEffect, useState } from 'react';
import { Alert, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Href, router } from 'expo-router';
import { Button, Dialog, FAB, Portal, TextInput } from 'react-native-paper';
import { Users } from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { usePeopleStore } from '../../src/stores/peopleStore';
import { useAuthStore } from '../../src/stores/authStore';
import GroupedList from '../../src/components/ui/GroupedList';
import GroupedListItem from '../../src/components/ui/GroupedListItem';
import { COLORS } from '../../src/utils/constants';

export default function PeopleScreen() {
  const insets = useSafeAreaInsets();
  const [dialogVisible, setDialogVisible] = useState(false);
  const [personName, setPersonName] = useState('');
  const [isAdding, setIsAdding] = useState(false);

  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);
  const addPerson = usePeopleStore((state) => state.addPerson);
  const getPersonStats = usePeopleStore((state) => state.getPersonStats);
  const user = useAuthStore((state) => state.user);

  const [personStats, setPersonStats] = useState<Record<string, {
    totalRecommendations: number;
    upvotes: number;
    downvotes: number;
    moviesWatched: number;
  }>>({});

  useEffect(() => {
    loadPeople();
  }, [loadPeople]);

  useEffect(() => {
    async function loadStats() {
      const stats: Record<string, {
        totalRecommendations: number;
        upvotes: number;
        downvotes: number;
        moviesWatched: number;
      }> = {};

      for (const person of people) {
        const personStat = await getPersonStats(person.name);
        stats[person.name] = personStat;
      }

      setPersonStats(stats);
    }

    if (people.length > 0) {
      loadStats();
    } else {
      setPersonStats({});
    }
  }, [people, getPersonStats]);

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
    } catch (error) {
      Alert.alert('Error', error instanceof Error ? error.message : 'Failed to add person');
    } finally {
      setIsAdding(false);
    }
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + 8, paddingBottom: 120 + insets.bottom }]}>
        <Text style={styles.largeTitle}>People</Text>

        {people.length === 0 ? (
          <View style={styles.emptyState}>
            <Users size={52} color={COLORS.textSecondary} />
            <Text style={styles.emptyTitle}>No people yet</Text>
            <Text style={styles.emptySubtitle}>Add recommenders to personalize your lists.</Text>
          </View>
        ) : (
          <GroupedList>
            {people.map((item, index) => {
              const stats = personStats[item.name] || {
                totalRecommendations: 0,
                upvotes: 0,
                downvotes: 0,
                moviesWatched: 0,
              };

              return (
                <GroupedListItem
                  key={item.name}
                  title={item.name}
                  subtitle={`${stats.upvotes} upvotes · ${stats.downvotes} downvotes · ${stats.moviesWatched} watched`}
                  onPress={() => router.push(`/people/${encodeURIComponent(item.name)}` as Href)}
                  left={
                    item.emoji ? (
                      <Text style={styles.emoji}>{item.emoji}</Text>
                    ) : (
                      <View style={[styles.avatar, { backgroundColor: item.color || COLORS.primary }]}>
                        <Text style={styles.avatarLabel}>{item.name.charAt(0).toUpperCase()}</Text>
                      </View>
                    )
                  }
                  right={
                    <View style={styles.countBadge}>
                      <Text style={styles.countBadgeText}>{stats.totalRecommendations}</Text>
                    </View>
                  }
                  showDivider={index < people.length - 1}
                />
              );
            })}
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
          <Dialog.Title>Add Person</Dialog.Title>
          <Dialog.Content>
            <TextInput
              label="Name"
              value={personName}
              onChangeText={setPersonName}
              autoCapitalize="words"
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
  emoji: {
    fontSize: 22,
  },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarLabel: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 13,
  },
  countBadge: {
    minWidth: 26,
    height: 22,
    borderRadius: 11,
    paddingHorizontal: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2c2c2e',
  },
  countBadgeText: {
    color: COLORS.text,
    fontSize: 12,
    fontWeight: '600',
  },
  emptyState: {
    paddingTop: 90,
    alignItems: 'center',
    paddingHorizontal: 24,
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
});
