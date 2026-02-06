import React from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { Text, List, Switch, Button, Divider } from 'react-native-paper';
import { useAuthStore } from '../../src/stores/authStore';
import { router } from 'expo-router';
import { useState, useEffect } from 'react';

export default function AccountScreen() {
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);
  const checkBiometric = useAuthStore((state) => state.checkBiometric);
  const enableBiometric = useAuthStore((state) => state.enableBiometric);

  const [biometricEnabled, setBiometricEnabled] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    loadBiometricStatus();
  }, []);

  const loadBiometricStatus = async () => {
    const enabled = await checkBiometric();
    setBiometricEnabled(enabled);
  };

  const handleBiometricToggle = async () => {
    try {
      const newValue = !biometricEnabled;
      await enableBiometric(newValue);
      setBiometricEnabled(newValue);
    } catch (error) {
      Alert.alert('Error', 'Failed to update biometric setting');
    }
  };

  const handleLogout = async () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout? All local data will be cleared.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Logout',
          style: 'destructive',
          onPress: async () => {
            setIsLoading(true);
            await logout();
            router.replace('/(auth)/login');
          },
        },
      ]
    );
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text variant="headlineMedium" style={styles.username}>
          {user?.username}
        </Text>
        <Text variant="bodyMedium" style={styles.email}>
          {user?.email}
        </Text>
      </View>

      <Divider style={styles.divider} />

      <List.Section>
        <List.Subheader style={styles.subheader}>Settings</List.Subheader>

        <List.Item
          title="Biometric Unlock"
          description="Use Face ID or fingerprint to unlock"
          left={(props) => <List.Icon {...props} icon="fingerprint" />}
          right={() => (
            <Switch
              value={biometricEnabled}
              onValueChange={handleBiometricToggle}
            />
          )}
          style={styles.listItem}
          titleStyle={styles.listItemTitle}
          descriptionStyle={styles.listItemDescription}
        />

        <List.Item
          title="Sync Status"
          description="All changes synced"
          left={(props) => <List.Icon {...props} icon="sync" />}
          style={styles.listItem}
          titleStyle={styles.listItemTitle}
          descriptionStyle={styles.listItemDescription}
        />
      </List.Section>

      <Divider style={styles.divider} />

      <List.Section>
        <List.Subheader style={styles.subheader}>About</List.Subheader>

        <List.Item
          title="Version"
          description="1.0.0"
          left={(props) => <List.Icon {...props} icon="information" />}
          style={styles.listItem}
          titleStyle={styles.listItemTitle}
          descriptionStyle={styles.listItemDescription}
        />
      </List.Section>

      <View style={styles.buttonContainer}>
        <Button
          mode="outlined"
          onPress={handleLogout}
          loading={isLoading}
          disabled={isLoading}
          textColor="#ff3b30"
          style={styles.logoutButton}
        >
          Logout
        </Button>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  header: {
    padding: 20,
    alignItems: 'center',
  },
  username: {
    color: '#fff',
    marginBottom: 4,
  },
  email: {
    color: '#8e8e93',
  },
  divider: {
    backgroundColor: '#38383a',
  },
  subheader: {
    color: '#8e8e93',
  },
  listItem: {
    backgroundColor: '#000',
  },
  listItemTitle: {
    color: '#fff',
  },
  listItemDescription: {
    color: '#8e8e93',
  },
  buttonContainer: {
    padding: 20,
    marginTop: 20,
  },
  logoutButton: {
    borderColor: '#ff3b30',
  },
});
