import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { Button, Chip, Modal, Portal } from 'react-native-paper';
import { COLORS } from '../utils/constants';

interface FilterSheetProps {
  visible: boolean;
  onDismiss: () => void;
  selectedRecommender: string | null;
  selectedGenre: string | null;
  selectedDecade: number | null;
  recommenders: string[];
  genres: string[];
  decades: number[];
  onSelectRecommender: (value: string | null) => void;
  onSelectGenre: (value: string | null) => void;
  onSelectDecade: (value: number | null) => void;
  onClearAll: () => void;
}

function SectionLabel({ label }: { label: string }) {
  return <Text style={styles.sectionLabel}>{label}</Text>;
}

function ChipRow({ children }: { children: React.ReactNode }) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
      {children}
    </ScrollView>
  );
}

export default function FilterSheet({
  visible,
  onDismiss,
  selectedRecommender,
  selectedGenre,
  selectedDecade,
  recommenders,
  genres,
  decades,
  onSelectRecommender,
  onSelectGenre,
  onSelectDecade,
  onClearAll,
}: FilterSheetProps) {
  return (
    <Portal>
      <Modal
        visible={visible}
        onDismiss={onDismiss}
        contentContainerStyle={styles.modalContainer}
        dismissable
      >
        <Text style={styles.title}>Filters</Text>

        <View style={styles.section}>
          <SectionLabel label="Recommender" />
          <ChipRow>
            {recommenders.map((person) => (
              <Chip
                key={person}
                selected={selectedRecommender === person}
                onPress={() =>
                  onSelectRecommender(selectedRecommender === person ? null : person)
                }
                style={styles.chip}
                textStyle={styles.chipText}
              >
                {person}
              </Chip>
            ))}
          </ChipRow>
        </View>

        <View style={styles.section}>
          <SectionLabel label="Genre" />
          <ChipRow>
            {genres.map((genre) => (
              <Chip
                key={genre}
                selected={selectedGenre === genre}
                onPress={() => onSelectGenre(selectedGenre === genre ? null : genre)}
                style={styles.chip}
                textStyle={styles.chipText}
              >
                {genre}
              </Chip>
            ))}
          </ChipRow>
        </View>

        <View style={styles.section}>
          <SectionLabel label="Decade" />
          <ChipRow>
            {decades.map((decade) => (
              <Chip
                key={String(decade)}
                selected={selectedDecade === decade}
                onPress={() => onSelectDecade(selectedDecade === decade ? null : decade)}
                style={styles.chip}
                textStyle={styles.chipText}
              >
                {decade}s
              </Chip>
            ))}
          </ChipRow>
        </View>

        <View style={styles.actions}>
          <Button mode="text" onPress={onClearAll}>
            Clear All
          </Button>
          <Button mode="contained" onPress={onDismiss}>
            Done
          </Button>
        </View>
      </Modal>
    </Portal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    marginHorizontal: 12,
    borderRadius: 20,
    backgroundColor: COLORS.surface,
    padding: 18,
  },
  title: {
    color: COLORS.text,
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 12,
  },
  section: {
    marginBottom: 14,
  },
  sectionLabel: {
    color: COLORS.textSecondary,
    fontSize: 13,
    marginBottom: 8,
    fontWeight: '600',
  },
  chipRow: {
    gap: 8,
    paddingRight: 12,
  },
  chip: {
    backgroundColor: '#2c2c2e',
  },
  chipText: {
    color: COLORS.text,
  },
  actions: {
    marginTop: 6,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
});
