import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { Check, Plus } from 'lucide-react-native';

import ModalShell from '../components/ModalShell';
import { useStore } from '../store/useStore';
import { theme } from '../theme/theme';

// The one place PG switching happens. Settings and the dashboard header both
// open this rather than each growing their own switcher.
export default function PropertyPickerModal({ navigation }) {
  const properties = useStore((s) => s.properties);
  const currentPropertyId = useStore((s) => s.currentPropertyId);
  const selectProperty = useStore((s) => s.selectProperty);

  const pick = (id) => {
    selectProperty(id);
    navigation.goBack();
  };

  return (
    <ModalShell title="Your PGs">
      <View style={styles.list}>
        {properties.map((p, index) => {
          const isCurrent = p.id === currentPropertyId;
          return (
            <TouchableOpacity
              key={p.id}
              style={styles.row}
              onPress={() => pick(p.id)}
              activeOpacity={0.7}
              accessibilityRole="button"
              accessibilityState={{ selected: isCurrent }}
              accessibilityLabel={`Switch to ${p.name}`}
              testID={`property-picker-row-${index}`}
            >
              <Text style={styles.name} numberOfLines={1}>
                {p.name}
              </Text>
              {isCurrent && <Check color={theme.colors.primary} size={18} strokeWidth={2.5} />}
            </TouchableOpacity>
          );
        })}

        {/* Plain navigate, not replace: CreateProperty pushes on top of this
            modal, and its post-create navigate('Main') pops both off at once.
            Backing out of it lands here again, which is what you'd expect. */}
        <TouchableOpacity
          style={[styles.row, styles.lastRow]}
          onPress={() => navigation.navigate('CreateProperty')}
          activeOpacity={0.7}
          accessibilityRole="button"
          accessibilityLabel="Add another PG"
          testID="property-picker-add"
        >
          <Text style={[styles.name, styles.addName]}>Add another PG</Text>
          <Plus color={theme.colors.primary} size={18} strokeWidth={2.5} />
        </TouchableOpacity>
      </View>
    </ModalShell>
  );
}

const styles = StyleSheet.create({
  list: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.lg,
    borderWidth: 1,
    borderColor: theme.colors.border,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: theme.spacing.md,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.border,
  },
  lastRow: { borderBottomWidth: 0 },
  name: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', flex: 1, marginRight: theme.spacing.sm },
  addName: { color: theme.colors.primary },
});
