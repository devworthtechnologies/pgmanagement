import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { theme } from '../theme/theme';
import { useStore } from '../store/useStore';
import { IndianRupee, Users, Bed, TrendingUp } from 'lucide-react-native';

export default function DashboardScreen({ navigation }) {
  const { pgDetails, getStats } = useStore();
  const stats = getStats();

  const StatCard = ({ title, value, icon: Icon, color }) => (
    <View style={styles.card}>
      <View style={[styles.iconContainer, { backgroundColor: color + '15' }]}>
        <Icon color={color} size={22} strokeWidth={2.5} />
      </View>
      <View style={styles.cardContent}>
        <Text style={styles.cardValue}>{value}</Text>
        <Text style={styles.cardTitle}>{title}</Text>
      </View>
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <Text style={styles.greeting}>Hello, {pgDetails.ownerName}</Text>
          <Text style={styles.pgName}>{pgDetails.pgName}</Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Overview</Text>
          <View style={styles.grid}>
            <StatCard 
              title="Pending Rent" 
              value={`₹${stats.pendingRent}`} 
              icon={IndianRupee} 
              color={theme.colors.error} 
            />
            <StatCard 
              title="Total Income" 
              value={`₹${stats.totalIncome}`} 
              icon={TrendingUp} 
              color={theme.colors.success} 
            />
            <StatCard 
              title="Occupancy" 
              value={`${stats.occupancyRate}%`} 
              icon={Users} 
              color={theme.colors.blue} 
            />
            <StatCard 
              title="Total Rooms" 
              value={stats.totalRooms} 
              icon={Bed} 
              color={theme.colors.warning} 
            />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          <View style={styles.actionGrid}>
            <TouchableOpacity 
              style={styles.actionButton}
              onPress={() => navigation.navigate('AddGuest')}
              activeOpacity={0.8}
            >
              <Text style={styles.actionText}>Add Guest</Text>
            </TouchableOpacity>
            <TouchableOpacity 
              style={styles.actionButtonSecondary}
              onPress={() => navigation.navigate('RecordPayment')}
              activeOpacity={0.8}
            >
              <Text style={styles.actionTextSecondary}>Record Payment</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={{height: 40}} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { 
    flex: 1, 
    backgroundColor: theme.colors.background 
  },
  container: { 
    flex: 1, 
    paddingHorizontal: theme.spacing.lg 
  },
  header: { 
    marginTop: theme.spacing.xl, 
    marginBottom: theme.spacing.lg 
  },
  greeting: { 
    ...theme.typography.bodySecondary, 
    marginBottom: theme.spacing.xs,
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontSize: 12,
  },
  pgName: { 
    ...theme.typography.h1 
  },
  section: { 
    marginBottom: theme.spacing.xl 
  },
  sectionTitle: { 
    ...theme.typography.h3, 
    marginBottom: theme.spacing.md 
  },
  grid: { 
    flexDirection: 'row', 
    flexWrap: 'wrap', 
    justifyContent: 'space-between',
    gap: theme.spacing.md,
  },
  card: { 
    width: '47%', 
    backgroundColor: theme.colors.surface, 
    padding: theme.spacing.md, 
    borderRadius: theme.borderRadius.lg, 
    marginBottom: 4,
    ...theme.shadows.sm,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.03)',
  },
  iconContainer: { 
    width: 44, 
    height: 44, 
    borderRadius: theme.borderRadius.full, 
    alignItems: 'center', 
    justifyContent: 'center', 
    marginBottom: theme.spacing.md 
  },
  cardValue: { 
    ...theme.typography.h2, 
    marginBottom: 2 
  },
  cardTitle: { 
    ...theme.typography.caption 
  },
  actionGrid: { 
    flexDirection: 'row', 
    gap: theme.spacing.md 
  },
  actionButton: { 
    flex: 1, 
    backgroundColor: theme.colors.primary, 
    paddingVertical: 18, 
    borderRadius: theme.borderRadius.full, 
    alignItems: 'center',
    justifyContent: 'center',
    ...theme.shadows.md,
  },
  actionText: { 
    color: '#FFFFFF', 
    ...theme.typography.body, 
    fontFamily: 'PlusJakartaSans_600SemiBold',
    fontSize: 16,
  },
  actionButtonSecondary: { 
    flex: 1, 
    backgroundColor: theme.colors.surface, 
    paddingVertical: 18, 
    borderRadius: theme.borderRadius.full, 
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: theme.colors.border,
  },
  actionTextSecondary: { 
    color: theme.colors.primary, 
    ...theme.typography.body, 
    fontFamily: 'PlusJakartaSans_600SemiBold',
    fontSize: 16,
  },
});
