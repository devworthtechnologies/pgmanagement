import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Modal,
  Pressable,
  SectionList,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useFocusEffect } from '@react-navigation/native';
import { format } from 'date-fns';
import { ArrowDownLeft, Ban, Pencil, Plus, Wallet } from 'lucide-react-native';
import Animated, { FadeInDown, Layout } from 'react-native-reanimated';

import Chip from '../components/Chip';
import EmptyState from '../components/EmptyState';
import FormField from '../components/FormField';
import ScreenHeader from '../components/ScreenHeader';
import { notify } from '../lib/confirm';
import { formatINR } from '../lib/format';
import { monthLabel } from '../lib/rent';
import { ApiError, guestsApi, paymentsApi } from '../lib/api';
import { useStore } from '../store/useStore';
import { theme } from '../theme/theme';

// Stable identities so the memo below doesn't recompute on every render while a
// property switch is in flight.
const EMPTY = [];
const EMPTY_MAP = {};

export default function PaymentsScreen({ navigation }) {
  const currentPropertyId = useStore((s) => s.currentPropertyId);
  const properties = useStore((s) => s.properties);
  const user = useStore((s) => s.user);

  // Void and correct are manager-only server-side; this just hides controls that
  // would 403 anyway. my_role comes from PropertyResponse.
  const myRole = properties.find((p) => p.id === currentPropertyId)?.my_role;
  const canAmend = myRole === 'owner' || myRole === 'manager';

  const [loaded, setLoaded] = useState({ propertyId: null, payments: EMPTY, guestNameById: EMPTY_MAP });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showVoided, setShowVoided] = useState(false);
  const [actionPayment, setActionPayment] = useState(null);
  const [voidReason, setVoidReason] = useState('');
  const [voiding, setVoiding] = useState(false);

  // Live mirror of the selection, readable from inside an in-flight request.
  // A ref rather than a param threaded through load() so that EVERY call path
  // is covered — focus, Retry, and the post-delete reload — with no way to
  // call load() unguarded.
  const selectedRef = useRef(currentPropertyId);
  useEffect(() => {
    selectedRef.current = currentPropertyId;
  }, [currentPropertyId]);

  const load = useCallback(async () => {
    // Captured at request time — the selection can change while we're away.
    const propertyId = currentPropertyId;
    if (!propertyId) {
      // No PG selected: resolve the spinner rather than turning forever.
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const [paymentList, guestList] = await Promise.all([
        // Always fetch voided rows and filter for display below. One request
        // serves both the toggle and the "corrected from ₹X" lookup, which needs
        // the voided original in hand. Voided rows are never summed — see the
        // section totals.
        paymentsApi.list(propertyId, { include_voided: true }),
        guestsApi.list(propertyId),
      ]);
      const nameMap = {};
      for (const g of guestList) nameMap[g.id] = g.full_name;
      // A newer selection took over while this was in flight. Discard it —
      // writing it would clobber the newer PG's ledger, and `loading` now
      // belongs to that newer request, so don't touch it either.
      if (selectedRef.current !== propertyId) return;
      setLoaded({ propertyId, payments: paymentList, guestNameById: nameMap });
    } catch (err) {
      if (selectedRef.current !== propertyId) return;
      setError(err instanceof ApiError ? err.message : 'Could not load payments.');
    } finally {
      if (selectedRef.current === propertyId) setLoading(false);
    }
  }, [currentPropertyId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load])
  );

  // Rows are only rendered when they came from the PG currently selected. On a
  // switch, currentPropertyId changes before the new fetch lands, and without
  // this the previous PG's ledger stays on screen until it does.
  const awaitingProperty = loaded.propertyId !== currentPropertyId;
  const payments = awaitingProperty ? EMPTY : loaded.payments;
  const guestNameById = awaitingProperty ? EMPTY_MAP : loaded.guestNameById;

  // Amount of the row a correction replaced, for the "corrected from ₹X" label.
  const amountByPaymentId = useMemo(() => {
    const map = new Map();
    for (const p of payments) map.set(p.id, p.amount);
    return map;
  }, [payments]);

  const visiblePayments = useMemo(
    () => (showVoided ? payments : payments.filter((p) => !p.deleted_at)),
    [payments, showVoided]
  );

  const sections = useMemo(() => {
    const byMonth = new Map();
    for (const p of visiblePayments) {
      const monthKey = String(p.for_month).slice(0, 7);
      if (!byMonth.has(monthKey)) byMonth.set(monthKey, []);
      byMonth.get(monthKey).push(p);
    }
    return [...byMonth.entries()]
      .sort((a, b) => b[0].localeCompare(a[0]))
      .map(([monthKey, items]) => ({
        monthKey,
        title: monthLabel(monthKey),
        // Voided rows are excluded from the total even while displayed — the
        // header figure has to agree with the dashboard, which never counts them.
        total: items.reduce((sum, p) => (p.deleted_at ? sum : sum + Number(p.amount || 0)), 0),
        data: [...items].sort((x, y) => new Date(y.paid_at) - new Date(x.paid_at)),
      }));
  }, [visiblePayments]);

  const voidedCount = useMemo(() => payments.filter((p) => p.deleted_at).length, [payments]);

  const closeActions = () => {
    setActionPayment(null);
    setVoidReason('');
  };

  const openActions = (payment) => {
    // Voided rows are history — nothing left to do to them.
    if (!canAmend || payment.deleted_at) return;
    setVoidReason('');
    setActionPayment(payment);
  };

  const handleVoid = async () => {
    const payment = actionPayment;
    setVoiding(true);
    try {
      await paymentsApi.void(currentPropertyId, payment.id, voidReason.trim() || null);
      closeActions();
      await load();
    } catch (err) {
      closeActions();
      notify('Could not void', err instanceof ApiError ? err.message : 'Please try again.');
    } finally {
      setVoiding(false);
    }
  };

  const handleCorrect = () => {
    const payment = actionPayment;
    closeActions();
    // The modal prefills from this and calls /correct, which voids the original
    // and writes the replacement in one transaction.
    navigation.navigate('RecordPayment', {
      correctsPaymentId: payment.id,
      correctsPayment: payment,
    });
  };

  const renderPayment = ({ item, index }) => {
    const voided = !!item.deleted_at;
    const guestName = guestNameById[item.guest_id] || 'Unknown guest';
    const correctedFrom = item.corrects_payment_id
      ? amountByPaymentId.get(item.corrects_payment_id)
      : null;
    const voidedByYou = !!user && item.voided_by === user.id;

    return (
      <Animated.View
        entering={FadeInDown.delay(index * 50).springify()}
        layout={Layout.springify()}
      >
        <TouchableOpacity
          style={[styles.paymentCard, voided && styles.paymentCardVoided]}
          onPress={() => openActions(item)}
          activeOpacity={canAmend && !voided ? 0.7 : 1}
          disabled={!canAmend || voided}
          accessibilityRole={canAmend && !voided ? 'button' : 'text'}
          accessibilityLabel={
            voided
              ? `Voided payment of ${formatINR(item.amount)} from ${guestName}`
              : `Payment of ${formatINR(item.amount)} from ${guestName}. Tap to correct or void.`
          }
          testID={`payment-row-${item.id}`}
        >
          <View style={[styles.paymentIcon, voided && styles.paymentIconVoided]}>
            {voided ? (
              <Ban color={theme.colors.textTertiary} size={20} strokeWidth={2.2} />
            ) : (
              <ArrowDownLeft color={theme.colors.success} size={22} strokeWidth={2.5} />
            )}
          </View>
          <View style={styles.paymentDetails}>
            <Text style={[styles.guestName, voided && styles.voidedText]} numberOfLines={1}>
              {guestName}
            </Text>
            <Text style={[styles.date, voided && styles.voidedText]}>
              {format(new Date(item.paid_at), 'd MMM')} · {item.method}
            </Text>
            {voided && (
              <Text style={styles.voidMeta}>
                Voided by {voidedByYou ? 'you' : 'a manager'}
                {item.void_reason ? ` · ${item.void_reason}` : ''}
              </Text>
            )}
            {correctedFrom != null && (
              <Text style={styles.correctedMeta} testID={`corrected-from-${item.id}`}>
                Corrected from {formatINR(correctedFrom)}
              </Text>
            )}
          </View>
          <Text style={[styles.amount, voided && styles.amountVoided]}>
            {voided ? '' : '+'}
            {formatINR(item.amount)}
          </Text>
        </TouchableOpacity>
      </Animated.View>
    );
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScreenHeader
        title="Payments"
        right={
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => navigation.navigate('RecordPayment')}
            activeOpacity={0.8}
            accessibilityRole="button"
            accessibilityLabel="Record payment"
            testID="add-payment"
          >
            <Plus color="#FFFFFF" size={24} strokeWidth={2.5} />
          </TouchableOpacity>
        }
      />

      {voidedCount > 0 && (
        <View style={styles.filters}>
          <Chip
            label={showVoided ? `Hiding nothing · ${voidedCount} voided` : `Show ${voidedCount} voided`}
            selected={showVoided}
            onPress={() => setShowVoided((v) => !v)}
            testID="toggle-show-voided"
          />
        </View>
      )}

      {(loading || awaitingProperty) && payments.length === 0 ? (
        <ActivityIndicator style={styles.loading} color={theme.colors.primary} />
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id}
          renderItem={renderPayment}
          renderSectionHeader={({ section }) => (
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>{section.title}</Text>
              <Text style={styles.sectionTotal}>{formatINR(section.total)}</Text>
            </View>
          )}
          contentContainerStyle={styles.listContainer}
          ListEmptyComponent={
            error ? (
              <EmptyState icon={Wallet} title="Couldn't load payments" message={error} actionLabel="Retry" onAction={load} />
            ) : (
              <EmptyState
                icon={Wallet}
                title="No payments yet"
                message="Record rent as it comes in — pending amounts update automatically."
                actionLabel="Record payment"
                onAction={() => navigation.navigate('RecordPayment')}
              />
            )
          }
          stickySectionHeadersEnabled={false}
          showsVerticalScrollIndicator={false}
        />
      )}

      {/* Correcting money is void-and-re-enter, so the two actions are offered
          together and neither one edits the original row. */}
      <Modal transparent animationType="fade" visible={!!actionPayment} onRequestClose={closeActions}>
        <Pressable style={styles.sheetBackdrop} onPress={closeActions}>
          <Pressable style={styles.sheet} onPress={() => {}}>
            {!!actionPayment && (
              <>
                <Text style={styles.sheetTitle}>
                  {formatINR(actionPayment.amount)} · {guestNameById[actionPayment.guest_id] || 'guest'}
                </Text>
                <Text style={styles.sheetSubtitle}>
                  Rent for {monthLabel(String(actionPayment.for_month).slice(0, 7))}. Payments are
                  never edited — the wrong row is voided and stays in the ledger.
                </Text>

                <TouchableOpacity
                  style={styles.sheetAction}
                  onPress={handleCorrect}
                  activeOpacity={0.7}
                  accessibilityRole="button"
                  testID="action-correct-payment"
                >
                  <Pencil color={theme.colors.text} size={18} strokeWidth={2.2} />
                  <Text style={styles.sheetActionText}>Correct amount</Text>
                </TouchableOpacity>

                <FormField
                  label="Reason for voiding (optional)"
                  value={voidReason}
                  onChangeText={setVoidReason}
                  placeholder="e.g. recorded twice"
                  testID="void-reason-input"
                />

                <TouchableOpacity
                  style={[styles.sheetAction, styles.sheetActionDestructive]}
                  onPress={handleVoid}
                  activeOpacity={0.7}
                  disabled={voiding}
                  accessibilityRole="button"
                  testID="action-void-payment"
                >
                  <Ban color={theme.colors.error} size={18} strokeWidth={2.2} />
                  <Text style={[styles.sheetActionText, styles.sheetActionTextDestructive]}>
                    {voiding ? 'Voiding…' : 'Void payment'}
                  </Text>
                </TouchableOpacity>
              </>
            )}
          </Pressable>
        </Pressable>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: theme.colors.background },
  loading: { marginTop: theme.spacing.xxl },
  addButton: {
    backgroundColor: theme.colors.primary,
    width: 48,
    height: 48,
    borderRadius: theme.borderRadius.full,
    alignItems: 'center',
    justifyContent: 'center',
    ...theme.shadows.sm,
  },
  listContainer: { paddingHorizontal: theme.spacing.lg, paddingBottom: 120, flexGrow: 1 },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: theme.spacing.md,
    marginBottom: theme.spacing.sm,
  },
  sectionTitle: { ...theme.typography.h3 },
  sectionTotal: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_700Bold', color: theme.colors.success },
  paymentCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: theme.spacing.md,
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.lg,
    marginBottom: theme.spacing.sm,
    ...theme.shadows.sm,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.03)',
  },
  paymentIcon: {
    width: 44,
    height: 44,
    borderRadius: theme.borderRadius.full,
    backgroundColor: theme.colors.success + '15',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: theme.spacing.md,
  },
  paymentDetails: { flex: 1, marginRight: theme.spacing.sm },
  guestName: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold', marginBottom: 2 },
  date: { ...theme.typography.caption },
  amount: {
    ...theme.typography.body,
    fontFamily: 'PlusJakartaSans_700Bold',
    color: theme.colors.success,
    marginRight: theme.spacing.sm,
  },
  filters: {
    flexDirection: 'row',
    gap: theme.spacing.sm,
    paddingHorizontal: theme.spacing.lg,
    marginBottom: theme.spacing.sm,
  },

  // Voided rows stay visible — muted and struck through, never hidden from an
  // owner looking at their own ledger.
  paymentCardVoided: { backgroundColor: theme.colors.background, opacity: 0.85 },
  paymentIconVoided: { backgroundColor: theme.colors.border },
  voidedText: { textDecorationLine: 'line-through', color: theme.colors.textTertiary },
  amountVoided: {
    color: theme.colors.textTertiary,
    textDecorationLine: 'line-through',
    fontFamily: 'PlusJakartaSans_600SemiBold',
  },
  voidMeta: { ...theme.typography.small, color: theme.colors.error, marginTop: 2 },
  correctedMeta: { ...theme.typography.small, color: theme.colors.textTertiary, marginTop: 2 },

  sheetBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(17,17,17,0.45)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: theme.colors.surface,
    borderTopLeftRadius: theme.borderRadius.lg,
    borderTopRightRadius: theme.borderRadius.lg,
    padding: theme.spacing.lg,
    paddingBottom: theme.spacing.xxl,
  },
  sheetTitle: { ...theme.typography.h3, marginBottom: 4 },
  sheetSubtitle: {
    ...theme.typography.caption,
    lineHeight: 18,
    marginBottom: theme.spacing.lg,
  },
  sheetAction: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: theme.spacing.sm,
    backgroundColor: theme.colors.background,
    borderRadius: theme.borderRadius.md,
    paddingVertical: 14,
    paddingHorizontal: theme.spacing.md,
    marginBottom: theme.spacing.lg,
  },
  sheetActionDestructive: { backgroundColor: theme.colors.error + '10', marginBottom: 0 },
  sheetActionText: { ...theme.typography.body, fontFamily: 'PlusJakartaSans_600SemiBold' },
  sheetActionTextDestructive: { color: theme.colors.error },
});
