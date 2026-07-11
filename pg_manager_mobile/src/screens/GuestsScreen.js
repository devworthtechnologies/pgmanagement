import React from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { Plus, Phone, AlertCircle, Trash2 } from 'lucide-react-native';

export default function GuestsScreen({ navigation }) {
  const { guests, deleteGuest } = useStore();

  const confirmDelete = (id, name) => {
    Alert.alert(
      "Remove Guest",
      `Are you sure you want to remove ${name}?`,
      [
        { text: "Cancel", style: "cancel" },
        { text: "Remove", style: "destructive", onPress: () => deleteGuest(id) }
      ]
    );
  };

  const renderGuest = ({ item }) => (
    <View style={styles.guestCard}>
      <View style={styles.guestInfo}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{item.fullName.charAt(0)}</Text>
        </View>
        <View style={styles.details}>
          <Text style={styles.name}>{item.fullName}</Text>
          <Text style={styles.roomInfo}>Room {item.roomNumber}</Text>
        </View>
      </View>
      <View style={styles.actions}>
        {item.status === 'Inactive' && (
          <View style={styles.inactiveBadge}>
            <Text style={styles.inactiveText}>Inactive</Text>
          </View>
        )}
        <TouchableOpacity style={styles.iconButton}>
          <Phone color={theme.colors.primary} size={18} strokeWidth={2.5} />
        </TouchableOpacity>
        <TouchableOpacity style={styles.iconButtonError} onPress={() => confirmDelete(item.id, item.fullName)}>
          <Trash2 color={theme.colors.error} size={18} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Guests</Text>
        <TouchableOpacity style={styles.addButton} onPress={() => navigation.navigate('AddGuest')} activeOpacity={0.8}>
          <Plus color={theme.colors.background} size={24} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>

      <FlatList
        data={guests}
        keyExtractor={item => item.id.toString()}
        renderItem={renderGuest}
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
  guestCard: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', padding: theme.spacing.md, backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.lg, marginBottom: theme.spacing.sm, ...theme.shadows.sm, borderWidth: 1, borderColor: 'rgba(0,0,0,0.03)' },
  guestInfo: { flexDirection: 'row', alignItems: 'center' },
  avatar: { width: 48, height: 48, borderRadius: theme.borderRadius.full, backgroundColor: theme.colors.background, alignItems: 'center', justifyContent: 'center', marginRight: theme.spacing.md },
  avatarText: { ...theme.typography.h2, color: theme.colors.primary },
  details: { justifyContent: 'center' },
  name: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', marginBottom: 2 },
  roomInfo: { ...theme.typography.caption },
  actions: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  inactiveBadge: { backgroundColor: theme.colors.error + '15', paddingHorizontal: 8, paddingVertical: 4, borderRadius: theme.borderRadius.full },
  inactiveText: { color: theme.colors.error, fontSize: 10, fontFamily: 'PlusJakartaSans_700Bold', textTransform: 'uppercase' },
  iconButton: { width: 36, height: 36, borderRadius: theme.borderRadius.full, backgroundColor: theme.colors.background, alignItems: 'center', justifyContent: 'center' },
  iconButtonError: { width: 36, height: 36, borderRadius: theme.borderRadius.full, backgroundColor: theme.colors.error + '10', alignItems: 'center', justifyContent: 'center' },
});
