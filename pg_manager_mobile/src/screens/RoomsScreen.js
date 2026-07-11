import React from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Alert } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { Plus, Trash2, Users } from 'lucide-react-native';

export default function RoomsScreen({ navigation }) {
  const { rooms, deleteRoom } = useStore();

  const confirmDelete = (id, roomNumber) => {
    Alert.alert(
      "Remove Room",
      `Are you sure you want to remove Room ${roomNumber}?`,
      [
        { text: "Cancel", style: "cancel" },
        { text: "Remove", style: "destructive", onPress: () => deleteRoom(id) }
      ]
    );
  };

  const renderRoom = ({ item }) => (
    <View style={styles.roomCard}>
      <View style={styles.roomHeader}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
          <Text style={styles.roomNumber}>Room {item.roomNumber}</Text>
          <View style={[
            styles.badge, 
            { backgroundColor: item.status === 'Full' ? theme.colors.background : theme.colors.success + '15' }
          ]}>
            <Text style={[
              styles.badgeText,
              { color: item.status === 'Full' ? theme.colors.textSecondary : theme.colors.success }
            ]}>{item.status}</Text>
          </View>
        </View>
        <TouchableOpacity style={styles.iconButtonError} onPress={() => confirmDelete(item.id, item.roomNumber)}>
          <Trash2 color={theme.colors.error} size={18} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>
      
      <View style={styles.roomFooter}>
        <View style={styles.roomDetails}>
          <Text style={styles.detailText}>{item.type}</Text>
        </View>
        <View style={styles.occupancyContainer}>
          <Users color={theme.colors.textSecondary} size={16} />
          <Text style={styles.occupancyText}>{item.occupied}/{item.capacity}</Text>
        </View>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.header}>
        <Text style={styles.title}>Rooms</Text>
        <TouchableOpacity style={styles.addButton} onPress={() => navigation.navigate('AddRoom')} activeOpacity={0.8}>
          <Plus color={theme.colors.background} size={24} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>

      <FlatList
        data={rooms}
        keyExtractor={item => item.id.toString()}
        renderItem={renderRoom}
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
  roomCard: { padding: theme.spacing.lg, backgroundColor: theme.colors.surface, borderRadius: theme.borderRadius.lg, marginBottom: theme.spacing.md, ...theme.shadows.sm, borderWidth: 1, borderColor: 'rgba(0,0,0,0.03)' },
  roomHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: theme.spacing.md },
  roomNumber: { ...theme.typography.h2 },
  badge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: theme.borderRadius.full },
  badgeText: { ...theme.typography.caption, fontFamily: 'PlusJakartaSans_700Bold', fontSize: 11, textTransform: 'uppercase' },
  roomFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: theme.spacing.sm, borderTopWidth: 1, borderTopColor: theme.colors.border },
  roomDetails: { flexDirection: 'row', alignItems: 'center' },
  detailText: { ...theme.typography.bodySecondary, fontFamily: 'PlusJakartaSans_600SemiBold' },
  occupancyContainer: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: theme.colors.background, paddingHorizontal: 12, paddingVertical: 6, borderRadius: theme.borderRadius.full },
  occupancyText: { ...theme.typography.caption, fontFamily: 'PlusJakartaSans_700Bold' },
  iconButtonError: { width: 36, height: 36, borderRadius: theme.borderRadius.full, backgroundColor: theme.colors.error + '10', alignItems: 'center', justifyContent: 'center' },
});
