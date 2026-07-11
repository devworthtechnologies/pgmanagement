import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { X } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function AddRoomModal({ navigation }) {
  const { addRoom, rooms } = useStore();
  
  const [roomNumber, setRoomNumber] = useState('');
  const [type, setType] = useState('');
  const [capacity, setCapacity] = useState('');

  const handleSave = () => {
    if (!roomNumber || !type || !capacity) {
      Alert.alert('Error', 'Please fill all fields');
      return;
    }
    
    const exists = rooms.find(r => r.roomNumber === roomNumber);
    if (exists) {
      Alert.alert('Error', 'Room number already exists');
      return;
    }

    addRoom({ roomNumber, type, capacity: Number(capacity) });
    navigation.goBack();
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Add Room</Text>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.closeBtn}>
          <X color={theme.colors.text} size={24} />
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Room Number</Text>
          <TextInput style={styles.input} value={roomNumber} onChangeText={setRoomNumber} placeholder="e.g. 105" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Room Type</Text>
          <TextInput style={styles.input} value={type} onChangeText={setType} placeholder="e.g. 2 Sharing" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Capacity</Text>
          <TextInput style={styles.input} value={capacity} onChangeText={setCapacity} keyboardType="numeric" placeholder="e.g. 2" placeholderTextColor={theme.colors.textTertiary} />
        </View>
        
        <TouchableOpacity style={styles.saveButton} onPress={handleSave} activeOpacity={0.8}>
          <Text style={styles.saveButtonText}>Save Room</Text>
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
