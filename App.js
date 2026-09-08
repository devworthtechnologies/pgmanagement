import React, { useCallback, useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { Bed, CreditCard, Home, Users } from 'lucide-react-native';
import {
  PlusJakartaSans_400Regular,
  PlusJakartaSans_500Medium,
  PlusJakartaSans_600SemiBold,
  PlusJakartaSans_700Bold,
  useFonts,
} from '@expo-google-fonts/plus-jakarta-sans';
import { Platform, StyleSheet, View, useWindowDimensions } from 'react-native';

import ConfirmDialog from './src/components/ConfirmDialog';
import ErrorBoundary from './src/components/ErrorBoundary';
import CreatePropertyScreen from './src/screens/CreatePropertyScreen';
import DashboardScreen from './src/screens/DashboardScreen';
import GuestDetailScreen from './src/screens/GuestDetailScreen';
import GuestFormModal from './src/screens/GuestFormModal';
import GuestsScreen from './src/screens/GuestsScreen';
import LoginScreen from './src/screens/LoginScreen';
import PaymentsScreen from './src/screens/PaymentsScreen';
import PropertyPickerModal from './src/screens/PropertyPickerModal';
import RecordPaymentModal from './src/screens/RecordPaymentModal';
import RegisterScreen from './src/screens/RegisterScreen';
import RoomFormModal from './src/screens/RoomFormModal';
import RoomsScreen from './src/screens/RoomsScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import { useStore } from './src/store/useStore';
import { theme } from './src/theme/theme';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

// Keep the splash screen visible until fonts and persisted state are ready.
SplashScreen.preventAutoHideAsync().catch(() => {});

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: theme.colors.textTertiary,
        tabBarStyle: {
          position: 'absolute',
          bottom: Platform.OS === 'web' ? 24 : 32,
          left: 16,
          right: 16,
          backgroundColor: '#FFFFFF',
          borderRadius: 32,
          borderTopWidth: 0,
          elevation: 8,
          shadowColor: '#000',
          shadowOffset: { width: 0, height: 10 },
          shadowOpacity: 0.12,
          shadowRadius: 24,
          height: 72,
          paddingBottom: 10,
          paddingTop: 10,
        },
        headerShown: false,
        tabBarLabelStyle: {
          fontFamily: 'PlusJakartaSans_600SemiBold',
          fontSize: 10,
          marginTop: 2,
        },
      }}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{ tabBarIcon: ({ color }) => <Home color={color} size={22} /> }}
      />
      <Tab.Screen
        name="Guests"
        component={GuestsScreen}
        options={{ tabBarIcon: ({ color }) => <Users color={color} size={22} /> }}
      />
      <Tab.Screen
        name="Rooms"
        component={RoomsScreen}
        options={{ tabBarIcon: ({ color }) => <Bed color={color} size={22} /> }}
      />
      <Tab.Screen
        name="Payments"
        component={PaymentsScreen}
        options={{ tabBarIcon: ({ color }) => <CreditCard color={color} size={22} /> }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  const [fontsLoaded, fontError] = useFonts({
    PlusJakartaSans_400Regular,
    PlusJakartaSans_500Medium,
    PlusJakartaSans_600SemiBold,
    PlusJakartaSans_700Bold,
  });
  const authChecked = useStore((s) => s.authChecked);
  const user = useStore((s) => s.user);
  const properties = useStore((s) => s.properties);
  const bootstrap = useStore((s) => s.bootstrap);

  const { width } = useWindowDimensions();
  const isDesktopWeb = Platform.OS === 'web' && width >= 768;

  useEffect(() => {
    bootstrap();
  }, [bootstrap]);

  // If fonts fail to load we still start — text falls back to system fonts.
  const ready = (fontsLoaded || !!fontError) && authChecked;

  const onLayoutRootView = useCallback(() => {
    if (ready) SplashScreen.hideAsync().catch(() => {});
  }, [ready]);

  if (!ready) return null;

  const appContent = (
    <SafeAreaProvider onLayout={onLayoutRootView}>
      <StatusBar style="dark" />
      <NavigationContainer>
        {/* CreateProperty stays registered for the whole authenticated session
            so a second PG can be added at any time — it used to be the ONLY
            screen when you had none, which is why there was no route to it
            afterwards.

            `initialRouteName` below is NOT reactive. Read it as "where this
            navigator starts", not "where the app should be right now": React
            Navigation reads it once, when the navigator mounts, and changing it
            later does nothing at all. That is what the `key` is for — flipping
            it unmounts the old navigator and mounts a fresh one, which is the
            only moment the expression is meaningful. Without the key, logging
            in kept the navigator built during the logged-out phase and landed
            every new signup on Main instead of CreateProperty.

            The key deliberately tracks `user` ONLY, not properties.length.
            Each transition then has exactly one mechanism and they don't race:
              login/logout → key flips → remount → initialRouteName re-read
              0 → 1 PG     → key steady → CreatePropertyScreen replace('Main')
              1 → 2 PGs    → key steady → CreatePropertyScreen navigate('Main')
            Adding an 'onboarding' phase to the key would flip it on 0→1, in the
            same commit as that replace('Main') — dispatching navigation into a
            navigator React is tearing down.

            This relies on useStore setting `user` and `properties` in the SAME
            set() call (it does — bootstrap/login/logout/setOnSessionExpired all
            do). Split them and a fresh signup reads a stale empty-vs-populated
            properties array at the instant the key flips, and lands on the
            wrong screen again. */}
        <Stack.Navigator
          key={user ? 'app' : 'guest'}
          screenOptions={{ headerShown: false }}
          initialRouteName={!user ? 'Login' : properties.length === 0 ? 'CreateProperty' : 'Main'}
        >
          {!user ? (
            <>
              <Stack.Screen name="Login" component={LoginScreen} />
              <Stack.Screen name="Register" component={RegisterScreen} />
            </>
          ) : (
            <>
              <Stack.Screen name="Main" component={MainTabs} />
              <Stack.Screen name="CreateProperty" component={CreatePropertyScreen} />
              <Stack.Screen name="GuestDetail" component={GuestDetailScreen} />
              <Stack.Screen name="Settings" component={SettingsScreen} />
              <Stack.Group screenOptions={{ presentation: 'modal' }}>
                <Stack.Screen name="GuestForm" component={GuestFormModal} />
                <Stack.Screen name="RoomForm" component={RoomFormModal} />
                <Stack.Screen name="RecordPayment" component={RecordPaymentModal} />
                <Stack.Screen name="PropertyPicker" component={PropertyPickerModal} />
              </Stack.Group>
            </>
          )}
        </Stack.Navigator>
      </NavigationContainer>
      <ConfirmDialog />
    </SafeAreaProvider>
  );

  return (
    <ErrorBoundary>
      {isDesktopWeb ? (
        <View style={styles.webRoot}>
          <View style={styles.webAppContainer}>{appContent}</View>
        </View>
      ) : (
        appContent
      )}
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  webRoot: {
    flex: 1,
    backgroundColor: theme.colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  webAppContainer: {
    height: '100%',
    maxHeight: 932,
    aspectRatio: 390 / 844,
    backgroundColor: theme.colors.background,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.15,
    shadowRadius: 32,
    elevation: 5,
    overflow: 'hidden',
    borderRadius: Platform.OS === 'web' ? 24 : 0,
  },
});
