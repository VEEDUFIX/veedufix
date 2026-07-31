import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.isActive,
    required this.createdAt,
    this.description,
    this.minOrderAmount,
    this.maxDiscount,
    this.startsAt,
    this.endsAt,
    this.usageLimit,
    this.perUserLimit = 1,
  });

  final String id;
  final String code;
  final String type;
  final double value;
  final bool isActive;
  final DateTime createdAt;
  final String? description;
  final double? minOrderAmount;
  final double? maxDiscount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? usageLimit;
  final int perUserLimit;

  String get displayValue => type == 'PERCENTAGE'
      ? '${value.toStringAsFixed(0)}% off'
      : '₹${value.toStringAsFixed(0)} off';

  factory AdminCoupon.fromJson(Map<String, dynamic> json) => AdminCoupon(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        type: json['type'] as String? ?? 'FLAT',
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        description: json['description'] as String?,
        minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
        maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
        startsAt: json['startsAt'] != null ? DateTime.tryParse(json['startsAt'] as String) : null,
        endsAt: json['endsAt'] != null ? DateTime.tryParse(json['endsAt'] as String) : null,
        usageLimit: (json['usageLimit'] as num?)?.toInt(),
        perUserLimit: (json['perUserLimit'] as num?)?.toInt() ?? 1,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final adminCouponsProvider = FutureProvider.autoDispose<List<AdminCoupon>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/admin/coupons');
  return (data['coupons'] as List<dynamic>? ?? [])
      .map((c) => AdminCoupon.fromJson(c as Map<String, dynamic>))
      .toList();
});

final couponToggleProvider = StateNotifierProvider<_CouponToggleNotifier, AsyncValue<void>>(
    (ref) => _CouponToggleNotifier(ref));

class _CouponToggleNotifier extends StateNotifier<AsyncValue<void>> {
  _CouponToggleNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> toggle(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(apiClientProvider).patch('/admin/coupons/$id/toggle');
      state = const AsyncValue.data(null);
      _ref.invalidate(adminCouponsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(apiClientProvider).delete('/admin/coupons/$id');
      state = const AsyncValue.data(null);
      _ref.invalidate(adminCouponsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(apiClientProvider).post('/admin/coupons', data: data);
      state = const AsyncValue.data(null);
      _ref.invalidate(adminCouponsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CouponManagerPage extends ConsumerWidget {
  const CouponManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final couponsAsync = ref.watch(adminCouponsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Coupon Manager', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _showCreateSheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: couponsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (coupons) => coupons.isEmpty
            ? const PremiumEmptyState(
                icon: Icons.discount_rounded,
                title: 'No coupons yet',
                subtitle: 'Create your first coupon to offer discounts to customers.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(adminCouponsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  itemCount: coupons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _CouponCard(
                    coupon: coupons[i],
                    onToggle: () => ref.read(couponToggleProvider.notifier).toggle(coupons[i].id),
                    onDelete: () => _confirmDelete(context, ref, coupons[i]),
                  ),
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AdminCoupon coupon) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Coupon?'),
        content: Text('Delete "${coupon.code}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(couponToggleProvider.notifier).delete(coupon.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCouponSheet(ref: ref),
    );
  }
}

// ─── Coupon card ──────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.onToggle, required this.onDelete});
  final AdminCoupon coupon;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isActive = coupon.isActive;
    final accent = isActive ? const Color(0xFF10B981) : cs.outline;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        coupon.code,
                        style: tt.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TapScale(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coupon.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coupon code copied')),
                    );
                  },
                  child: Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: isActive,
                  onChanged: (_) => onToggle(),
                  activeTrackColor: const Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              coupon.displayValue,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (coupon.description != null) ...[
              const SizedBox(height: 4),
              Text(coupon.description!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (coupon.minOrderAmount != null)
                  _Chip(label: 'Min ₹${coupon.minOrderAmount!.toStringAsFixed(0)}'),
                if (coupon.maxDiscount != null)
                  _Chip(label: 'Max ₹${coupon.maxDiscount!.toStringAsFixed(0)} off'),
                if (coupon.usageLimit != null)
                  _Chip(label: '${coupon.usageLimit} uses'),
                if (coupon.endsAt != null)
                  _Chip(label: 'Expires ${DateFormat("d MMM y").format(coupon.endsAt!)}'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TapScale(
                onTap: onDelete,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: cs.error),
                    const SizedBox(width: 4),
                    Text('Delete', style: tt.labelSmall?.copyWith(color: cs.error)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

// ─── Create coupon sheet ──────────────────────────────────────────────────────

class _CreateCouponSheet extends ConsumerStatefulWidget {
  const _CreateCouponSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends ConsumerState<_CreateCouponSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxDiscCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _type = 'PERCENTAGE';

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isLoading = ref.watch(couponToggleProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Create Coupon', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Code',
                    hintText: 'SUMMER20',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _type,
                  decoration: InputDecoration(
                    labelText: 'Discount Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'FLAT', child: Text('Flat Amount (₹)')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'PERCENTAGE'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueCtrl,
                  decoration: InputDecoration(
                    labelText: _type == 'PERCENTAGE' ? 'Discount %' : 'Discount ₹',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) { return 'Required'; }
                    if (double.tryParse(v) == null) { return 'Enter a valid number'; }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderCtrl,
                        decoration: InputDecoration(
                          labelText: 'Min Order ₹',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxDiscCtrl,
                        decoration: InputDecoration(
                          labelText: 'Max Discount ₹',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limitCtrl,
                  decoration: InputDecoration(
                    labelText: 'Total Usage Limit (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Create Coupon', style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    await ref.read(couponToggleProvider.notifier).create({
      'code': _codeCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'type': _type,
      'value': double.parse(_valueCtrl.text),
      if (_minOrderCtrl.text.isNotEmpty) 'minOrderAmount': double.parse(_minOrderCtrl.text),
      if (_maxDiscCtrl.text.isNotEmpty) 'maxDiscount': double.parse(_maxDiscCtrl.text),
      if (_limitCtrl.text.isNotEmpty) 'usageLimit': int.parse(_limitCtrl.text),
    });
    if (!mounted) { return; }
    final error = ref.read(couponToggleProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } else {
      Navigator.of(context).pop();
    }
  }
}
