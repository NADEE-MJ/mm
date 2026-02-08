import React, { useEffect, useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { ActivityIndicator, Button, Switch } from 'react-native-paper';
import { router } from 'expo-router';
import { formatDistance } from 'date-fns';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuthStore } from '../../src/stores/authStore';
import { useSyncStore } from '../../src/stores/syncStore';
import { useMoviesStore } from '../../src/stores/moviesStore';
import { usePeopleStore } from '../../src/stores/peopleStore';
import GroupedList from '../../src/components/ui/GroupedList';
import GroupedListItem from '../../src/components/ui/GroupedListItem';
import { COLORS } from '../../src/utils/constants';

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <View style={styles.statCard}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

export default function AccountScreen() {
  const insets = useSafeAreaInsets();
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);
  const checkBiometric = useAuthStore((state) => state.checkBiometric);
  const enableBiometric = useAuthStore((state) => state.enableBiometric);

  const isSyncing = useSyncStore((state) => state.isSyncing);
  const lastSync = useSyncStore((state) => state.lastSync);
  const pendingCount = useSyncStore((state) => state.pendingCount);
  const triggerSync = useSyncStore((state) => state.triggerSync);
  const updateSyncStatus = useSyncStore((state) => state.updateSyncStatus);

  const movies = useMoviesStore((state) => state.movies);
  const loadMovies = useMoviesStore((state) => state.loadMovies);

  const people = usePeopleStore((state) => state.people);
  const loadPeople = usePeopleStore((state) => state.loadPeople);

  const [biometricEnabled, setBiometricEnabled] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    loadBiometricStatus();
    updateSyncStatus();
    loadMovies();
    loadPeople();
  }, [updateSyncStatus, loadMovies, loadPeople]);

  const loadBiometricStatus = async () => {
    const enabled = await checkBiometric();
    setBiometricEnabled(enabled);
  };

  const stats = useMemo(() => {
    const totalMovies = movies.length;
    const toWatch = movies.filter((movie) => movie.status.status === 'toWatch').length;
    const watched = movies.filter((movie) => movie.status.status === 'watched').length;
    const deleted = movies.filter((movie) => movie.status.status === 'deleted').length;

    const ratedMovies = movies.filter((movie) => movie.watch_history?.my_rating);
    const avgRating = ratedMovies.length
      ? ratedMovies.reduce((sum, movie) => sum + (movie.watch_history?.my_rating || 0), 0) / ratedMovies.length
      : 0;

    return {
      totalMovies,
      toWatch,
      watched,
      deleted,
      avgRating,
      totalRecommenders: people.length,
    };
  }, [movies, people]);

  const handleBiometricToggle = async () => {
    try {
      const newValue = !biometricEnabled;
      await enableBiometric(newValue);
      setBiometricEnabled(newValue);
    } catch (_error) {
      Alert.alert('Error', 'Failed to update biometric setting');
    }
  };

  const handleManualSync = async () => {
    await triggerSync();
    Alert.alert('Sync Complete', 'All changes have been synced');
  };

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout? All local data will be cleared.', [
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
    ]);
  };

  const getSyncDescription = () => {
    if (isSyncing) {
      return 'Syncing...';
    }

    if (pendingCount > 0) {
      return `${pendingCount} change${pendingCount > 1 ? 's' : ''} pending`;
    }

    if (lastSync > 0) {
      return `Last synced ${formatDistance(lastSync, Date.now(), { addSuffix: true })}`;
    }

    return 'Not synced yet';
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + 8, paddingBottom: 120 + insets.bottom }]}
    >
      <Text style={styles.largeTitle}>Account</Text>

      <Text style={styles.userLabel}>{user?.username || 'User'}</Text>
      {user?.email ? <Text style={styles.emailLabel}>{user.email}</Text> : null}

      <Text style={styles.sectionTitle}>Stats</Text>
      <View style={styles.statsGrid}>
        <StatCard label="Total Movies" value={stats.totalMovies} />
        <StatCard label="To Watch" value={stats.toWatch} />
        <StatCard label="Watched" value={stats.watched} />
        <StatCard label="Deleted" value={stats.deleted} />
        <StatCard label="Avg Rating" value={stats.avgRating ? stats.avgRating.toFixed(1) : '-'} />
        <StatCard label="Total Recommenders" value={stats.totalRecommenders} />
      </View>

      <Text style={styles.sectionTitle}>Settings</Text>
      <GroupedList>
        <GroupedListItem
          title="Biometric Unlock"
          subtitle="Use Face ID or fingerprint"
          showChevron={false}
          showDivider
          onPress={handleBiometricToggle}
          right={<Switch value={biometricEnabled} onValueChange={handleBiometricToggle} />}
        />
        <GroupedListItem
          title="Sync Status"
          subtitle={getSyncDescription()}
          showChevron={false}
          right={
            <Pressable
              style={({ pressed }) => [styles.syncButton, pressed && styles.pressed]}
              onPress={handleManualSync}
              disabled={isSyncing}
            >
              {isSyncing ? <ActivityIndicator size={14} /> : <Text style={styles.syncButtonText}>Sync Now</Text>}
            </Pressable>
          }
        />
      </GroupedList>

      <Text style={styles.sectionTitle}>Danger</Text>
      <Button
        mode="outlined"
        textColor={COLORS.error}
        style={styles.logoutButton}
        onPress={handleLogout}
        loading={isLoading}
        disabled={isLoading}
      >
        Logout
      </Button>
    </ScrollView>
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
  },
  userLabel: {
    color: COLORS.text,
    marginTop: 8,
    fontSize: 18,
    fontWeight: '600',
  },
  emailLabel: {
    color: COLORS.textSecondary,
    fontSize: 13,
    marginTop: 2,
  },
  sectionTitle: {
    color: COLORS.textSecondary,
    fontSize: 13,
    fontWeight: '700',
    marginTop: 18,
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -5,
  },
  statCard: {
    width: '50%',
    paddingHorizontal: 5,
    marginBottom: 10,
  },
  statValue: {
    backgroundColor: COLORS.surfaceGroup,
    borderRadius: 12,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    color: COLORS.text,
    fontSize: 24,
    fontWeight: '700',
    paddingTop: 14,
    paddingHorizontal: 12,
    paddingBottom: 30,
  },
  statLabel: {
    color: COLORS.textSecondary,
    fontSize: 12,
    marginTop: -24,
    marginLeft: 12,
  },
  syncButton: {
    backgroundColor: '#2c2c2e',
    borderRadius: 14,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  syncButtonText: {
    color: COLORS.text,
    fontSize: 12,
    fontWeight: '600',
  },
  logoutButton: {
    borderColor: COLORS.error,
    marginTop: 2,
  },
  pressed: {
    opacity: 0.75,
  },
});
