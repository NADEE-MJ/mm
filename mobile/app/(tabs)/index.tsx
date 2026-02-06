import React from 'react';
import { View, StyleSheet, FlatList } from 'react-native';
import { Text, FAB, Searchbar } from 'react-native-paper';
import { useState } from 'react';

export default function MoviesScreen() {
  const [searchQuery, setSearchQuery] = useState('');

  return (
    <View style={styles.container}>
      <Searchbar
        placeholder="Search movies..."
        onChangeText={setSearchQuery}
        value={searchQuery}
        style={styles.searchbar}
      />

      <View style={styles.emptyState}>
        <Text variant="headlineSmall" style={styles.emptyText}>
          No movies yet
        </Text>
        <Text variant="bodyMedium" style={styles.emptySubtext}>
          Tap the + button to add your first movie
        </Text>
      </View>

      <FAB
        icon="plus"
        style={styles.fab}
        onPress={() => {
          // TODO: Navigate to add movie screen
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  searchbar: {
    margin: 16,
    backgroundColor: '#1c1c1e',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  emptyText: {
    color: '#fff',
    marginBottom: 8,
  },
  emptySubtext: {
    color: '#8e8e93',
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
    backgroundColor: '#0a84ff',
  },
});
