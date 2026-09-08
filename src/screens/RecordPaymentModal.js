import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { UserPlus } from 'lucide-react-native';

import Chip from '../components/Chip';
import EmptyState from '../components/EmptyState';
import FormField from '../components/FormField';
import ModalShell from '../components/ModalShell';
import PrimaryButton from '../components/PrimaryButton';
import { confirm } from '../lib/confirm';
import { formatINR, initialsOf } from '../lib/format';
import { describeAmountAnomaly } from '../lib/paymentSanity';
import { monthKeyOf, monthKeyToDate, monthLabel, prevMonthKey } from '../lib/rent';
import { uuidv4 } from '../lib/uuid';
import { ApiError, guestsApi, paymentsApi, statsApi } from '../lib/api';
import { useStore } from '../store/useStore';
import { theme } from '../theme/theme';

// Display label -> backend PaymentMethod enum value.
const METHODS = [
  { label: 'UPI', value: 'upi' },
  { label: 'Cash', value: 'cash' },
  { label: 'Bank transfer', value: 'bank_transfer' },
  { label: 'Card', value: 'card' },
];

export default function RecordPaymentModal({ navigation, route }) {
  const currentPropertyId = useStore((s) => s.currentPropertyId);

  // Correction mode: the payment being replaced is passed through so we can
  // prefill from it without needing a GET /payments/{id} endpoint. The old row
  // gets voided server-side as part of the /correct call.
  const correctsPaymentId = route.params?.correctsPaymentId ?? null;
  const correctsPayment = route.params?.correctsPayment ?? null;
  const isCorrection = !!correctsPaymentId;

  const preselectedGuestId = correctsPayment?.guest_id ?? route.params?.guestId;

  const currentMonth = monthKeyOf();
  const lastMonth = prevMonthKey(currentMonth);
  // The month the original payment was for, if it isn't one of the two chips —
  // you're correcting THAT month, so it has to be selectable.
  const originalMonth = correctsPayment ? String(correctsPayment.for_month).slice(0, 7) : null;
  const extraMonth =
    originalMonth && originalMonth !== currentMonth && originalMonth !== lastMonth ? originalMonth : null;

  const [activeGuests, setActiveGuests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);

  const [forMonth, setForMonth] = useState(originalMonth ?? currentMonth);
  const [dueByGuestId, setDueByGuestId] = useState({});
  const [dueLoading, setDueLoading] = useState(false);

  const [selectedGuestId, setSelectedGuestId] = useState(preselectedGuestId ?? null);
  const [amount, setAmount] = useState(
    correctsPayment ? String(Number(correctsPayment.amount)) : ''
  );
  const [method, setMethod] = useState(correctsPayment?.method ?? 'upi');
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const guests = await guestsApi.list(currentPropertyId, { active: true });
        if (cancelled) return;
        setActiveGuests([...guests].sort((a, b) => a.full_name.localeCompare(b.full_name)));
      } catch (err) {
        if (!cancelled) setLoadError(err instanceof ApiError ? err.message : 'Could not load guests.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [currentPropertyId]);

  const loadDueForMonth = useCallback(
    async (month) => {
      setDueLoading(true);
      try {
        const stats = await statsApi.dashboard(currentPropertyId, month);
        const map = {};
        for (const entry of stats.due_guests) map[entry.guest_id] = entry.balance;
        setDueByGuestId(map);
      } catch {
        setDueByGuestId({});
      } finally {
        setDueLoading(false);
      }
    },
    [currentPropertyId]
  );

  useEffect(() => {
    loadDueForMonth(forMonth);
  }, [forMonth, loadDueForMonth]);

  // Prefill the amount once we know the selected guest's due balance for
  // the currently chosen month (skipped if the user already typed a value).
  // Not in correction mode — there the amount is prefilled from the original.
  useEffect(() => {
    if (isCorrection || !selectedGuestId || dueLoading) return;
    const due = dueByGuestId[selectedGuestId];
    if (due > 0) setAmount((prev) => (prev === '' ? String(due) : prev));
  }, [isCorrection, selectedGuestId, dueByGuestId, dueLoading]);

  const selectedGuest = activeGuests.find((g) => g.id === selectedGuestId) || null;

  const clearError = (key) => setErrors((e) => (e[key] ? { ...e, [key]: null } : e));

  const selectGuest = (guest) => {
    setSelectedGuestId(guest.id);
    // Correcting: the amount came from the original payment, don't overwrite it.
    if (!isCorrection) {
      const due = dueByGuestId[guest.id];
      setAmount(due > 0 ? String(due) : '');
    }
    clearError('guest');
  };

  const selectMonth = (month) => {
    setForMonth(month);
    if (!isCorrection) setAmount('');
  };

  const submit = async (value) => {
    setSaving(true);
    setFormError(null);
    try {
      const payload = {
        guest_id: selectedGuest.id,
        amount: value,
        method,
        for_month: monthKeyToDate(forMonth),
        // Fresh key every submit, including corrections — the replacement is a
        // new ledger row, not a retry of the one being voided.
        idempotency_key: uuidv4(),
      };
      if (isCorrection) {
        await paymentsApi.correct(currentPropertyId, correctsPaymentId, {
          ...payload,
          reason: `Corrected from ${formatINR(correctsPayment?.amount ?? 0)}`,
        });
      } else {
        await paymentsApi.create(currentPropertyId, payload);
      }
      navigation.goBack();
    } catch (err) {
      setFormError(err instanceof ApiError ? err.message : 'Could not save payment.');
    } finally {
      setSaving(false);
    }
  };

  const handleSave = async () => {
    const next = {};
    if (!selectedGuest) next.guest = 'Select a guest.';
    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0) next.amount = 'Enter a positive amount.';
    setErrors(next);
    if (Object.values(next).some(Boolean)) return;

    // Fat-finger guard. Confirms rather than blocks — advances, deposits, part
    // payments and settling several months at once are all legitimate and all
    // land outside the band.
    const anomaly = describeAmountAnomaly(value, selectedGuest.monthly_rent, selectedGuest.full_name);
    if (anomaly) {
      confirm({
        title: 'Does that amount look right?',
        message: anomaly,
        confirmLabel: 'Record anyway',
        onConfirm: () => submit(value),
      });
      return;
    }

    await submit(value);
  };

  if (loading) {
    return (
      <ModalShell title={isCorrection ? 'Correct payment' : 'Record payment'}>
        <ActivityIndicator color={theme.colors.primary} />
      </ModalShell>
    );
  }

  if (loadError) {
    return <ModalShell title={isCorrection ? 'Correct payment' : 'Record payment'} error={loadError} />;
  }

  if (activeGuests.length === 0) {
    return (
      <ModalShell title={isCorrection ? 'Correct payment' : 'Record payment'}>
        <EmptyState
          icon={UserPlus}
          title="No active guests"
          message="Add a guest first — then record their rent payments here."
          actionLabel="Add guest"
          onAction={() => navigation.replace('GuestForm')}
        />
      </ModalShell>
    );
  }

  const methodLabel = METHODS.find((m) => m.value === method)?.label ?? method;

  return (
    <ModalShell
      title="Record payment"
      error={formError}
      footer={
        <>
          {selectedGuest && Number(amount) > 0 && (
            <Text style={styles.summary}>
              {formatINR(amount)} from {selectedGuest.full_name} · rent for {monthLabel(forMonth)} · {methodLabel}
            </Text>
          )}
          <PrimaryButton
            title={saving ? 'Saving…' : isCorrection ? 'Void old & save correction' : 'Save payment'}
            onPress={handleSave}
            disabled={saving}
            testID="payment-save"
          />
        </>
      }
    >
      {isCorrection && (
        <View style={styles.correctionNotice} testID="correction-notice">
          <Text style={styles.correctionText}>
            Correcting a payment of {formatINR(correctsPayment?.amount ?? 0)}. The original stays in
            the ledger marked as voided — it isn&apos;t edited or deleted.
          </Text>
        </View>
      )}

      <View style={styles.group}>
        <Text style={styles.label}>Guest</Text>
        {activeGuests.map((guest) => {
          const balance = dueByGuestId[guest.id] ?? 0;
          const selected = guest.id === selectedGuestId;
          return (
            <TouchableOpacity
              key={guest.id}
              style={[styles.guestRow, selected && styles.guestRowSelected]}
              onPress={() => selectGuest(guest)}
              activeOpacity={0.7}
              accessibilityRole="radio"
              accessibilityState={{ selected }}
              testID={`payment-guest-${guest.id}`}
            >
              <View style={[styles.radio, selected && styles.radioSelected]}>
                {selected && <View style={styles.radioDot} />}
              </View>
              <View style={styles.guestAvatar}>
                <Text style={styles.guestAvatarText}>{initialsOf(guest.full_name)}</Text>
              </View>
              <View style={styles.guestInfo}>
                <Text style={styles.guestName} numberOfLines={1}>
                  {guest.full_name}
                </Text>
              </View>
              {dueLoading ? (
                <ActivityIndicator size="small" color={theme.colors.textTertiary} />
              ) : balance > 0 ? (
                <Text style={styles.guestDue}>{formatINR(balance)} due</Text>
              ) : (
                <Text style={styles.guestPaid}>Paid</Text>
              )}
            </TouchableOpacity>
          );
        })}
        {!!errors.guest && <Text style={styles.chipError}>{errors.guest}</Text>}
      </View>

      <View style={styles.group}>
        <Text style={styles.label}>Rent for</Text>
        <View style={styles.chips}>
          <Chip
            label={monthLabel(currentMonth)}
            selected={forMonth === currentMonth}
            onPress={() => selectMonth(currentMonth)}
            testID="month-chip-current"
          />
          <Chip
            label={monthLabel(lastMonth)}
            selected={forMonth === lastMonth}
            onPress={() => selectMonth(lastMonth)}
            testID="month-chip-last"
          />
          {!!extraMonth && (
            <Chip
              label={monthLabel(extraMonth)}
              selected={forMonth === extraMonth}
              onPress={() => selectMonth(extraMonth)}
              testID="month-chip-original"
            />
          )}
        </View>
      </View>

      <FormField
        label="Amount (₹)"
        value={amount}
        onChangeText={(v) => { setAmount(v); clearError('amount'); }}
        keyboardType="numeric"
        placeholder="e.g. 8500"
        error={errors.amount}
        testID="payment-amount-input"
      />

      <View style={styles.group}>
        <Text style={styles.label}>Payment method</Text>
        <View style={styles.chips}>
          {METHODS.map((m) => (
            <Chip
              key={m.value}
              label={m.label}
              selected={method === m.value}
              onPress={() => setMethod(m.value)}
              testID={`method-chip-${m.value}`}
            />
          ))}
        </View>
      </View>
    </ModalShell>
  );
}

const styles = StyleSheet.create({
  group: { marginBottom: theme.spacing.lg },
  label: {
    ...theme.typography.body,
    fontFamily: 'PlusJakartaSans_600SemiBold',
    marginBottom: 8,
  },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: theme.spacing.sm },
  chipError: { ...theme.typography.caption, color: theme.colors.error, marginTop: 6 },
  guestRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: theme.spacing.sm,
    backgroundColor: theme.colors.surface,
    borderWidth: 1,
    borderColor: theme.colors.border,
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    marginBottom: theme.spacing.sm,
  },
  guestRowSelected: { borderColor: theme.colors.primary, borderWidth: 1.5 },
  radio: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: theme.colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioSelected: { borderColor: theme.colors.primary },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: theme.colors.primary },
  guestAvatar: {
    width: 36,
    height: 36,
    borderRadius: theme.borderRadius.full,
    backgroundColor: theme.colors.background,
    alignItems: 'center',
    justifyContent: 'center',
  },
  guestAvatarText: { ...theme.typography.caption, fontFamily: 'PlusJakartaSans_700Bold' },
  guestInfo: { flex: 1 },
  guestName: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold' },
  guestDue: { ...theme.typography.caption, color: theme.colors.error, fontFamily: 'PlusJakartaSans_700Bold' },
  guestPaid: { ...theme.typography.caption, color: theme.colors.success, fontFamily: 'PlusJakartaSans_700Bold' },
  summary: {
    ...theme.typography.caption,
    textAlign: 'center',
    marginBottom: theme.spacing.md,
  },
  correctionNotice: {
    backgroundColor: theme.colors.warning + '15',
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    marginBottom: theme.spacing.lg,
  },
  correctionText: { ...theme.typography.caption, lineHeight: 18 },
});
