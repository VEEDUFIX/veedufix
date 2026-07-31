import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

// ─── Entities ─────────────────────────────────────────────────────────────────

class AdminCustomer {
  const AdminCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalBookings,
    required this.totalSpend,
    required this.createdAt,
    required this.isActive,
    this.avatarUrl,
    this.email,
  });

  final String id;
  final String name;
  final String phone;
  final int totalBookings;
  final double totalSpend;
  final DateTime createdAt;
  final bool isActive;
  final String? avatarUrl;
  final String? email;

  factory AdminCustomer.fromJson(Map<String, dynamic> json) => AdminCustomer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Customer',
        phone: json['phone'] as String? ?? '',
        totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
        totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isActive: json['isActive'] as bool? ?? true,
        avatarUrl: json['avatarUrl'] as String?,
        email: json['email'] as String?,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final adminCustomersProvider = FutureProvider.autoDispose
    .family<List<AdminCustomer>, String>((ref, search) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(
    '/admin/customers',
    queryParameters: search.isNotEmpty ? {'search': search} : null,
  );
  return (data['customers'] as List<dynamic>? ?? [])
      .map((c) => AdminCustomer.fromJson(c as Map<String, dynamic>))
      .toList();
});

final adminBanCustomerProvider =
    StateNotifierProvider<_BanNotifier, AsyncValue<void>>((ref) => _BanNotifier(ref));

class _BanNotifier extends StateNotifier<AsyncValue<void>> {
  _BanNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> toggleBan(String customerId, bool ban) async {
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      await api.patch('/admin/customers/$customerId/ban', data: {'banned': ban});
      state = const AsyncValue.data(null);
      _ref.invalidate(adminCustomersProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key, this.initialSearch = ''});

  final String initialSearch;

  @override
  ConsumerState<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends ConsumerState<CustomerManagementPage> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch.isNotEmpty) {
      _searchController.text = widget.initialSearch;
      _search = widget.initialSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final customersAsync = ref.watch(adminCustomersProvider(_search));

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
        title: Text('Customers', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                if (customers.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No customers found',
                    subtitle: 'Try a different search term.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(adminCustomersProvider(_search).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CustomerCard(
                      customer: customers[i],
                      onBanToggle: (ban) => _confirmBan(context, ref, customers[i], ban),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBan(BuildContext context, WidgetRef ref, AdminCustomer customer, bool ban) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ban ? 'Ban Customer?' : 'Unban Customer?'),
        content: Text(
          ban
              ? 'This will prevent ${customer.name} from making new bookings.'
              : 'This will restore ${customer.name}\'s access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(adminBanCustomerProvider.notifier).toggleBan(customer.id, ban);
            },
            style: ban
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(ban ? 'Ban' : 'Unban'),
          ),
        ],
      ),
    );
  }
}

// ─── Customer card ────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onBanToggle});
  final AdminCustomer customer;
  final void Function(bool) onBanToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isActive = customer.isActive;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                MarketplaceNetworkAvatar(
                  imageUrl: customer.avatarUrl,
                  radius: 24,
                  backgroundColor: cs.primaryContainer,
                  fallback: Text(
                    customer.name.substring(0, 1).toUpperCase(),
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Banned',
                              style: tt.labelSmall?.copyWith(
                                color: isActive ? const Color(0xFF10B981) : Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(customer.phone, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatPill(icon: Icons.receipt_rounded, label: '${customer.totalBookings} bookings'),
                const SizedBox(width: 10),
                _StatPill(icon: Icons.currency_rupee_rounded, label: '₹${customer.totalSpend.toStringAsFixed(0)} spent'),
                const SizedBox(width: 10),
                _StatPill(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('MMM y').format(customer.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onBanToggle(!isActive),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? Colors.red : const Color(0xFF10B981),
                  side: BorderSide(
                    color: isActive ? Colors.red.withValues(alpha: 0.4) : const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 16),
                label: Text(isActive ? 'Ban Customer' : 'Restore Access'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
