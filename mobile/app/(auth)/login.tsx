import React, { useState } from 'react';
import { View, StyleSheet, KeyboardAvoidingView, Platform, Alert } from 'react-native';
import { Text, TextInput, Button, Surface } from 'react-native-paper';
import { router } from 'expo-router';
import { useAuthStore } from '../../src/stores/authStore';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const login = useAuthStore((state) => state.login);

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Please enter email and password');
      return;
    }

    setIsLoading(true);

    try {
      await login(email, password);
      // Navigation will be handled by the root layout
      router.replace('/(tabs)');
    } catch (error) {
      Alert.alert('Login Failed', error instanceof Error ? error.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <Surface style={styles.surface}>
        <Text variant="headlineLarge" style={styles.title}>
          Movie Manager
        </Text>
        <Text variant="bodyLarge" style={styles.subtitle}>
          Sign in to continue
        </Text>

        <TextInput
          label="Email"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
          autoCorrect={false}
          style={styles.input}
          mode="outlined"
          disabled={isLoading}
        />

        <TextInput
          label="Password"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          autoCapitalize="none"
          autoCorrect={false}
          style={styles.input}
          mode="outlined"
          disabled={isLoading}
        />

        <Button
          mode="contained"
          onPress={handleLogin}
          loading={isLoading}
          disabled={isLoading}
          style={styles.button}
        >
          Sign In
        </Button>

        <Button
          mode="text"
          onPress={() => router.push('/(auth)/register')}
          disabled={isLoading}
          style={styles.linkButton}
        >
          Don't have an account? Sign up
        </Button>
      </Surface>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    padding: 20,
    backgroundColor: '#000',
  },
  surface: {
    padding: 20,
    borderRadius: 12,
    backgroundColor: '#1c1c1e',
  },
  title: {
    textAlign: 'center',
    marginBottom: 8,
    color: '#fff',
  },
  subtitle: {
    textAlign: 'center',
    marginBottom: 24,
    color: '#8e8e93',
  },
  input: {
    marginBottom: 16,
  },
  button: {
    marginTop: 8,
  },
  linkButton: {
    marginTop: 8,
  },
});
