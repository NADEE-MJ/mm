import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, FAB } from 'react-native-paper';

export default function PeopleScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.emptyState}>
        <Text variant="headlineSmall" style={styles.emptyText}>
          No people yet
        </Text>
        <Text variant="bodyMedium" style={styles.emptySubtext}>
          Add people to track their movie recommendations
        </Text>
      </View>

      <FAB
        icon="plus"
        style={styles.fab}
        onPress={() => {
          // TODO: Navigate to add person screen
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
