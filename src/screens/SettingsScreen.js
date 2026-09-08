import React, { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronRight, LogOut } from 'lucide-react-native';

import BackHeader from '../components/BackHeader';
import FormField from '../components/FormField';
import PrimaryButton from '../components/PrimaryButton';
import { confirm, notify } from '../lib/confirm';
import { useStore } from '../store/useStore';
import { theme } from '../theme/theme';

const APP_VERSION = require('../../package.json').version;

export default function SettingsScreen({ navigation }) {
  const user = useStore((s) => s.user);
  const properties = useStore((s) => s.properties);
  const currentPropertyId = useStore((s) => s.currentPropertyId);
  const updateCurrentProperty = useStore((s) => s.updateCurrentProperty);
  const logout = useStore((s) => s.logout);

  const property = properties.find((p) => p.id === currentPropertyId);
  const [name, setName] = useState(property?.name ?? '');
  const [nameFor, setNameFor] = useState(currentPropertyId);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  // Switching PGs now happens in a modal on top of this screen, so this field
  // has to re-point itself at the new property when we come back. Without it,
  // "Save changes" would rename the PG you just switched TO using the name of
  // the one you switched FROM.
  if (nameFor !== currentPropertyId) {
    setNameFor(currentPropertyId);
    setName(property?.name ?? '');
  }

  const dirty = name.trim() !== (property?.name ?? '');

  const handleSave = async () => {
    setSaving(true);
    const res = await updateCurrentProperty({ name: name.trim() });
    setSaving(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setError(null);
    notify('Saved', 'Property details updated.');
  };

  const handleLogout = () => {
    confirm({
      title: 'Log out?',
      message: "You'll need to log in again to access your properties.",
      confirmLabel: 'Log out',
      destructive: true,
      onConfirm: () => logout(),
    });
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <BackHeader title="Settings" />
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <Text style={styles.sectionTitle}>Account</Text>
          <View style={styles.accountCard}>
            <Text style={styles.accountName}>{user?.full_name}</Text>
            <Text style={styles.accountEmail}>{user?.email}</Text>
          </View>

          <Text style={styles.sectionTitle}>Property</Text>
          <FormField
            label="Property name"
            value={name}
            onChangeText={setName}
            placeholder="e.g. Sunrise PG"
            autoCapitalize="words"
            error={error}
            testID="settings-property-name"
          />
          <PrimaryButton
            title={saving ? 'Saving…' : 'Save changes'}
            onPress={handleSave}
            disabled={!dirty || saving}
            testID="settings-save"
          />

          {/* One switcher, in PropertyPickerModal — this is a door to it, not a
              second copy of it. Always shown, even with a single PG, because
              it's also the way to add another. */}
          <Text style={styles.sectionTitle}>Your PGs</Text>
          <View style={styles.propertyList}>
            <TouchableOpacity
              style={styles.propertyRow}
              onPress={() => navigation.navigate('PropertyPicker')}
              activeOpacity={0.7}
              accessibilityRole="button"
              accessibilityLabel="Switch or add a PG"
              testID="settings-open-property-picker"
            >
              <Text style={styles.propertyName}>
                {properties.length === 1 ? 'Switch or add a PG' : `Switch between ${properties.length} PGs`}
              </Text>
              <ChevronRight color={theme.colors.textTertiary} size={18} strokeWidth={2.2} />
            </TouchableOpacity>
          </View>

          <TouchableOpacity style={styles.logoutButton} onPress={handleLogout} activeOpacity={0.8} testID="settings-logout">
            <LogOut color={theme.colors.error} size={18} strokeWidth={2.2} />
            <Text style={styles.logoutText}>Log out</Text>
          </TouchableOpacity>

          <Text style={styles.version}>PG Manager v{APP_VERSION}</Text>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: theme.colors.background },
  flex: { flex: 1 },
  content: { padding: theme.spacing.lg },
  sectionTitle: { ...theme.typography.h3, marginBottom: theme.spacing.md, marginTop: theme.spacing.lg },
  accountCard: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.lg,
    borderWidth: 1,
    borderColor: theme.colors.border,
    padding: theme.spacing.md,
  },
  accountName: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', marginBottom: 2 },
  accountEmail: { ...theme.typography.caption },
  propertyList: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.lg,
    borderWidth: 1,
    borderColor: theme.colors.border,
    overflow: 'hidden',
  },
  propertyRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: theme.spacing.md,
    paddingVertical: 14,
  },
  propertyName: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold' },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: theme.spacing.sm,
    backgroundColor: theme.colors.error + '10',
    borderRadius: theme.borderRadius.full,
    paddingVertical: 14,
    marginTop: theme.spacing.xl,
  },
  logoutText: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', color: theme.colors.error },
  version: {
    ...theme.typography.small,
    textAlign: 'center',
    marginTop: theme.spacing.xxl,
  },
});
