import React from 'react';
import { Button, Portal, Dialog, Text } from 'react-native-paper';

interface EnrichmentPromptProps {
  visible: boolean;
  count: number;
  onDismiss: () => void;
  onEnrich: () => void;
}

export default function EnrichmentPrompt({
  visible,
  count,
  onDismiss,
  onEnrich,
}: EnrichmentPromptProps) {
  return (
    <Portal>
      <Dialog visible={visible} onDismiss={onDismiss}>
        <Dialog.Title>Enrich Movies</Dialog.Title>
        <Dialog.Content>
          <Text>
            You have {count} movie{count === 1 ? '' : 's'} missing metadata. Enrich now?
          </Text>
        </Dialog.Content>
        <Dialog.Actions>
          <Button onPress={onDismiss}>Later</Button>
          <Button onPress={onEnrich}>Enrich</Button>
        </Dialog.Actions>
      </Dialog>
    </Portal>
  );
}

