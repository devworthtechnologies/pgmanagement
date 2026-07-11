import React from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { format } from 'date-fns';
import { ArrowDownLeft, Plus } from 'lucide-react-native';

export default function PaymentsScreen({ navigation }) {
  const { payments, guests } = useStore();

  const getGuestName = (id) => {
    const guest = guests.find(g => g.id === id);
    return guest ? guest.fullName : `Guest #${id}`;
  };

  const renderPayment = ({ item }) => (
    <View style={styles.paymentCard}>
      <View style={styles.paymentIcon}>
        <ArrowDownLeft color={theme.colors.success} size={22} strokeWidth={2.5} />
      </View>
      <View style={styles.paymentDetails}>
        <Text style={styles.guestName}>{getGuestName(item.guestId)}</Text>
        <Text style={styles.date}>{format(new Date(item.date), 'MMM dd, yyyy')} • {item.method}</Text>
      </View>
      <View style={styles.amountContainer}>
        <Text style={styles.amount}>+₹{item.amount}</Text>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Payments</Text>
        <TouchableOpacity style={styles.addButton} onPress={() => navigation.navigate('RecordPayment')} activeOpacity={0.8}>
          <Plus color={theme.colors.background} size={24} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>

      <FlatList
        data={payments}
        keyExtractor={item => item.id.toString()}
        renderItem={renderPayment}
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: theme.colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: theme.spacing.lg, marginTop: theme.spacing.xl, marginBottom: theme.spacing.lg },
  title: { ...theme.typography.h1 },
  addButton: { backgroundColor: theme.colors.primary, width: 48, height: 48, borderRadius: theme.borderRadius.full, alignItems: 'center', justifyContent: 'center', ...theme.shadows.sm },
  listContainer: { paddingHorizontal: theme.spacing.lg, paddingBottom: theme.spacing.xl },
  paymentCard: { flexDirection: 'row', alignItems: 'center', padding: theme.spacing.md, backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.lg, marginBottom: theme.spacing.sm, ...theme.shadows.sm, borderWidth: 1, borderColor: 'rgba(0,0,0,0.03)' },
  paymentIcon: { width: 44, height: 44, borderRadius: theme.borderRadius.full, backgroundColor: theme.colors.success + '15', alignItems: 'center', justifyContent: 'center', marginRight: theme.spacing.md },
  paymentDetails: { flex: 1 },
  guestName: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', marginBottom: 2 },
  date: { ...theme.typography.caption },
  amountContainer: { alignItems: 'flex-end' },
  amount: { ...theme.typography.h3, color: theme.colors.success, fontFamily: 'PlusJakartaSans_700Bold' },
});
