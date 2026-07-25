import React, { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Building2 } from 'lucide-react-native';

import BackHeader from '../components/BackHeader';
import FormField from '../components/FormField';
import PrimaryButton from '../components/PrimaryButton';
import { useStore } from '../store/useStore';
import { theme } from '../theme/theme';

// Two jobs: the "you have no PG yet" first-run screen, and the "add another PG"
// screen reached from the property picker. The only differences are whether
// there's a way back and where a successful create lands you.
export default function CreatePropertyScreen({ navigation }) {
  const createProperty = useStore((s) => s.createProperty);
  const properties = useStore((s) => s.properties);

  // Frozen at mount on purpose. createProperty() pushes the new PG into the
  // store, so reading properties.length live would flip this mid-save — the
  // first-run screen would sprout a back button on its way out.
  const [isFirstProperty] = useState(() => properties.length === 0);

  const [name, setName] = useState('');
  const [city, setCity] = useState('');
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);

  const handleCreate = async () => {
    const next = {};
    if (!name.trim()) next.name = 'Give your property a name.';
    setErrors(next);
    if (Object.keys(next).length > 0) return;

    setSaving(true);
    const res = await createProperty({ name: name.trim(), city: city.trim() || undefined });
    setSaving(false);
    if (!res.ok) {
      setErrors({ name: res.error });
      return;
    }

    // The navigator no longer swaps screens by itself on 0→1 (initialRouteName
    // only applies on first mount), so say where to go. replace() on the first
    // PG because this screen was the stack root and there's nothing to go back
    // to; navigate() otherwise, which pops the picker modal off too.
    if (isFirstProperty) navigation.replace('Main');
    else navigation.navigate('Main');
    // createProperty() already made the new PG current.
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      {!isFirstProperty && <BackHeader title="Add a PG" />}
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.hero}>
            <View style={styles.iconCircle}>
              <Building2 color={theme.colors.primary} size={32} strokeWidth={2} />
            </View>
            <Text style={styles.title}>{isFirstProperty ? 'Set up your PG' : 'Add another PG'}</Text>
            <Text style={styles.subtitle}>
              {isFirstProperty
                ? 'Give your PG a name to get started. You can add more later.'
                : 'Each PG keeps its own rooms, guests and payments. Switch between them from the header.'}
            </Text>
          </View>

          <FormField
            label="Property name"
            value={name}
            onChangeText={(v) => {
              setName(v);
              if (errors.name) setErrors((e) => ({ ...e, name: null }));
            }}
            placeholder="e.g. Sunrise PG"
            error={errors.name}
            autoCapitalize="words"
            testID="create-property-name"
          />
          <FormField
            label="City (optional)"
            value={city}
            onChangeText={setCity}
            placeholder="e.g. Bengaluru"
            autoCapitalize="words"
            testID="create-property-city"
          />

          <PrimaryButton
            title={saving ? 'Creating…' : 'Create property'}
            onPress={handleCreate}
            disabled={saving}
            testID="create-property-submit"
          />
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: theme.colors.background },
  flex: { flex: 1 },
  content: { flexGrow: 1, justifyContent: 'center', padding: theme.spacing.lg },
  hero: { alignItems: 'center', marginBottom: theme.spacing.xl },
  iconCircle: {
    width: 72,
    height: 72,
    borderRadius: theme.borderRadius.full,
    backgroundColor: theme.colors.surface,
    borderWidth: 1,
    borderColor: theme.colors.border,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: theme.spacing.lg,
    ...theme.shadows.sm,
  },
  title: { ...theme.typography.h1, textAlign: 'center', marginBottom: theme.spacing.sm },
  subtitle: {
    ...theme.typography.bodySecondary,
    textAlign: 'center',
    lineHeight: 22,
    paddingHorizontal: theme.spacing.md,
  },
});
