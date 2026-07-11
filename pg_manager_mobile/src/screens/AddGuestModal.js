import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { X } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function AddGuestModal({ navigation }) {
  const { addGuest, rooms } = useStore();
  
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [roomNumber, setRoomNumber] = useState('');
  const [monthlyRent, setMonthlyRent] = useState('');

  const handleSave = () => {
    if (!fullName || !phone || !roomNumber || !monthlyRent) {
      Alert.alert('Error', 'Please fill all fields');
      return;
    }
    
    const room = rooms.find(r => r.roomNumber === roomNumber);
    if (!room) {
      Alert.alert('Error', 'Room does not exist');
      return;
    }
    if (room.occupied >= room.capacity) {
      Alert.alert('Error', 'Room is full');
      return;
    }

    addGuest({ fullName, phone, roomNumber, monthlyRent: Number(monthlyRent), dueDate: 5 });
    navigation.goBack();
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Add Guest</Text>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.closeBtn}>
          <X color={theme.colors.text} size={24} />
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Full Name</Text>
          <TextInput style={styles.input} value={fullName} onChangeText={setFullName} placeholder="e.g. John Doe" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Phone Number</Text>
          <TextInput style={styles.input} value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="e.g. +91 9876543210" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Room Number</Text>
          <TextInput style={styles.input} value={roomNumber} onChangeText={setRoomNumber} placeholder="e.g. 101" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Monthly Rent (₹)</Text>
          <TextInput style={styles.input} value={monthlyRent} onChangeText={setMonthlyRent} keyboardType="numeric" placeholder="e.g. 8500" placeholderTextColor={theme.colors.textTertiary} />
        </View>
        
        <TouchableOpacity style={styles.saveButton} onPress={handleSave} activeOpacity={0.8}>
          <Text style={styles.saveButtonText}>Save Guest</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: theme.colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: theme.spacing.lg, borderBottomWidth: 1, borderBottomColor: theme.colors.border },
  title: { ...theme.typography.h2 },
  closeBtn: { padding: theme.spacing.xs, backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.full, ...theme.shadows.sm },
  container: { padding: theme.spacing.lg },
  inputGroup: { marginBottom: theme.spacing.lg },
  label: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', marginBottom: 8 },
  input: { backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.md, padding: 16, ...theme.typography.body, borderWidth: 1, borderColor: theme.colors.border },
  saveButton: { backgroundColor: theme.colors.primary, padding: 18, borderRadius: theme.borderRadius.full, alignItems: 'center', marginTop: theme.spacing.md, ...theme.shadows.md },
  saveButtonText: { color: theme.colors.background, ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', fontSize: 16 }
});
