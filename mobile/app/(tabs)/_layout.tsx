import { Tabs } from 'expo-router';
import { Platform, StyleSheet, View } from 'react-native';
import { BlurView } from 'expo-blur';
import { Film, Users, List, User } from 'lucide-react-native';

function TabBarBackground() {
  return (
    <View style={styles.tabBarBackgroundContainer}>
      <BlurView
        intensity={80}
        tint="dark"
        style={StyleSheet.absoluteFill}
      />
    </View>
  );
}

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#DBA506',
        tabBarInactiveTintColor: '#8e8e93',
        tabBarStyle: {
          position: 'absolute',
          bottom: Platform.OS === 'ios' ? 24 : 16,
          left: 16,
          right: 16,
          height: 64,
          borderRadius: 20,
          backgroundColor: 'rgba(28, 28, 30, 0.75)',
          borderTopWidth: 0,
          borderWidth: 0.5,
          borderColor: 'rgba(255, 255, 255, 0.1)',
          elevation: 0,
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 8 },
          shadowOpacity: 0.4,
          shadowRadius: 16,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarBackground: () => <TabBarBackground />,
        headerStyle: {
          backgroundColor: 'rgba(28, 28, 30, 0.75)',
          elevation: 0,
          shadowOpacity: 0,
          borderBottomWidth: 0.5,
          borderBottomColor: 'rgba(255, 255, 255, 0.1)',
        },
        headerTintColor: '#fff',
        headerShadowVisible: false,
        headerTransparent: true,
        headerBlurEffect: 'dark',
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Movies',
          tabBarIcon: ({ color, size }) => <Film color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="people"
        options={{
          title: 'People',
          tabBarIcon: ({ color, size }) => <Users color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="lists"
        options={{
          title: 'Lists',
          tabBarIcon: ({ color, size }) => <List color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="account"
        options={{
          title: 'Account',
          tabBarIcon: ({ color, size }) => <User color={color} size={size} />,
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBarBackgroundContainer: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 20,
    overflow: 'hidden',
  },
});
