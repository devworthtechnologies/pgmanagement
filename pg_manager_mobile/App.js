import React, { useEffect, useCallback } from 'react';
import { View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Home, Users, Bed, CreditCard } from 'lucide-react-native';
import { useFonts, PlusJakartaSans_400Regular, PlusJakartaSans_500Medium, PlusJakartaSans_600SemiBold, PlusJakartaSans_700Bold } from '@expo-google-fonts/plus-jakarta-sans';
import * as SplashScreen from 'expo-splash-screen';

import DashboardScreen from './src/screens/DashboardScreen';
import GuestsScreen from './src/screens/GuestsScreen';
import RoomsScreen from './src/screens/RoomsScreen';
import PaymentsScreen from './src/screens/PaymentsScreen';

import AddGuestModal from './src/screens/AddGuestModal';
import AddRoomModal from './src/screens/AddRoomModal';
import RecordPaymentModal from './src/screens/RecordPaymentModal';

import { theme } from './src/theme/theme';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'react-native';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

// Keep the splash screen visible while we fetch resources
SplashScreen.preventAutoHideAsync();

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: theme.colors.textTertiary,
        tabBarStyle: {
          backgroundColor: theme.colors.surface,
          borderTopColor: theme.colors.border,
          borderTopWidth: 1,
          elevation: 0,
          height: 64,
          paddingBottom: 10,
          paddingTop: 10,
        },
        headerShown: false,
        tabBarLabelStyle: {
          fontFamily: 'PlusJakartaSans_600SemiBold',
          fontSize: 11,
          marginTop: 4,
        }
      }}
    >
      <Tab.Screen 
        name="Dashboard" 
        component={DashboardScreen} 
        options={{ tabBarIcon: ({ color, size }) => <Home color={color} size={22} /> }}
      />
      <Tab.Screen 
        name="Guests" 
        component={GuestsScreen} 
        options={{ tabBarIcon: ({ color, size }) => <Users color={color} size={22} /> }}
      />
      <Tab.Screen 
        name="Rooms" 
        component={RoomsScreen} 
        options={{ tabBarIcon: ({ color, size }) => <Bed color={color} size={22} /> }}
      />
      <Tab.Screen 
        name="Payments" 
        component={PaymentsScreen} 
        options={{ tabBarIcon: ({ color, size }) => <CreditCard color={color} size={22} /> }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  let [fontsLoaded] = useFonts({
    PlusJakartaSans_400Regular,
    PlusJakartaSans_500Medium,
    PlusJakartaSans_600SemiBold,
    PlusJakartaSans_700Bold,
  });

  const onLayoutRootView = useCallback(async () => {
    if (fontsLoaded) {
      await SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return null;
  }

  return (
    <SafeAreaProvider onLayout={onLayoutRootView}>
      <StatusBar barStyle="dark-content" backgroundColor="#FAFAFA" />
      <NavigationContainer>
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          <Stack.Screen name="Main" component={MainTabs} />
          <Stack.Group screenOptions={{ presentation: 'modal' }}>
            <Stack.Screen name="AddGuest" component={AddGuestModal} />
            <Stack.Screen name="AddRoom" component={AddRoomModal} />
            <Stack.Screen name="RecordPayment" component={RecordPaymentModal} />
          </Stack.Group>
        </Stack.Navigator>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
