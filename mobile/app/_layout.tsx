import { useEffect, useState } from 'react';
import { Stack, useRouter, useSegments } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { PaperProvider, MD3DarkTheme } from 'react-native-paper';
import { useAuthStore } from '../src/stores/authStore';
import { useSyncStore } from '../src/stores/syncStore';
import { initDatabase } from '../src/services/database/init';

export {
  // Catch any errors thrown by the Layout component.
  ErrorBoundary,
} from 'expo-router';

// Prevent the splash screen from auto-hiding before asset loading is complete.
SplashScreen.preventAutoHideAsync();

const darkTheme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    primary: '#0a84ff',
    background: '#000000',
    surface: '#1c1c1e',
    error: '#ff3b30',
  },
};

export default function RootLayout() {
  const [appReady, setAppReady] = useState(false);
  const router = useRouter();
  const segments = useSegments();

  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const verifyAuth = useAuthStore((state) => state.verifyAuth);
  const checkBiometric = useAuthStore((state) => state.checkBiometric);
  const authenticateBiometric = useAuthStore((state) => state.authenticateBiometric);
  const initSync = useSyncStore((state) => state.initSync);

  // Initialize app
  useEffect(() => {
    async function initializeApp() {
      try {
        // Initialize database
        await initDatabase();

        // Check if biometric is enabled
        const biometricEnabled = await checkBiometric();

        if (biometricEnabled) {
          // Authenticate with biometric
          const authenticated = await authenticateBiometric();

          if (!authenticated) {
            // Biometric failed, user needs to login
            setAppReady(true);
            return;
          }
        }

        // Verify auth token
        const authenticated = await verifyAuth();

        // Initialize sync if authenticated
        if (authenticated) {
          await initSync();
        }
      } catch (error) {
        console.error('App initialization error:', error);
      } finally {
        setAppReady(true);
        await SplashScreen.hideAsync();
      }
    }

    initializeApp();
  }, []);

  // Handle navigation based on auth state
  useEffect(() => {
    if (!appReady) return;

    const inAuthGroup = segments[0] === '(auth)';

    if (!isAuthenticated && !inAuthGroup) {
      // Redirect to login
      router.replace('/(auth)/login');
    } else if (isAuthenticated && inAuthGroup) {
      // Redirect to app
      router.replace('/(tabs)');
    }
  }, [isAuthenticated, segments, appReady]);

  if (!appReady) {
    return null;
  }

  return (
    <PaperProvider theme={darkTheme}>
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: '#000' },
        }}
      >
        <Stack.Screen name="(auth)" />
        <Stack.Screen name="(tabs)" />
      </Stack>
    </PaperProvider>
  );
}
