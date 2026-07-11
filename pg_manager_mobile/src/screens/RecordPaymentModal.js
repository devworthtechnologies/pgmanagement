import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { X } from 'lucide-react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function RecordPaymentModal({ navigation }) {
  const { addPayment, guests } = useStore();
  
  const [guestId, setGuestId] = useState('');
  const [amount, setAmount] = useState('');
  const [method, setMethod] = useState('');

  const handleSave = () => {
    if (!guestId || !amount || !method) {
      Alert.alert('Error', 'Please fill all fields');
      return;
    }

    addPayment({ guestId: Number(guestId), amount: Number(amount), method });
    navigation.goBack();
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Record Payment</Text>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.closeBtn}>
          <X color={theme.colors.text} size={24} />
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.container}>
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Guest ID</Text>
          <TextInput style={styles.input} value={guestId} onChangeText={setGuestId} keyboardType="numeric" placeholder="e.g. 1" placeholderTextColor={theme.colors.textTertiary} />
          <Text style={styles.hint}>Active IDs: {guests.map(g => g.id).join(', ')}</Text>
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Amount (₹)</Text>
          <TextInput style={styles.input} value={amount} onChangeText={setAmount} keyboardType="numeric" placeholder="e.g. 8500" placeholderTextColor={theme.colors.textTertiary} />
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Payment Method</Text>
          <TextInput style={styles.input} value={method} onChangeText={setMethod} placeholder="e.g. UPI, Cash" placeholderTextColor={theme.colors.textTertiary} />
        </View>
        
        <TouchableOpacity style={styles.saveButton} onPress={handleSave} activeOpacity={0.8}>
          <Text style={styles.saveButtonText}>Save Payment</Text>
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
  hint: { ...theme.typography.caption, marginTop: 4, color: theme.colors.textTertiary },
  input: { backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.md, padding: 16, ...theme.typography.body, borderWidth: 1, borderColor: theme.colors.border },
  saveButton: { backgroundColor: theme.colors.primary, padding: 18, borderRadius: theme.borderRadius.full, alignItems: 'center', marginTop: theme.spacing.md, ...theme.shadows.md },
  saveButtonText: { color: theme.colors.background, ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', fontSize: 16 }
});
