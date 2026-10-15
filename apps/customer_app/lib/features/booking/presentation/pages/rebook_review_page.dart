import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../checkout/presentation/pages/checkout_page.dart';
import '../../../profile/data/saved_addresses_api.dart';
import '../data/rebook_options.dart';

class RebookReviewPage extends ConsumerStatefulWidget {
  const RebookReviewPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<RebookReviewPage> createState() => _RebookReviewPageState();
}

class _RebookReviewPageState extends ConsumerState<RebookReviewPage> {
  bool _loading = true;
  bool _loadingCatalog = false;
  String? _error;
  String? _selectedAddressId;
  bool _addressMatched = false;
  bool _previouslyQuoted = false;
  String? _blockedReason;
  List<SavedAddressItem> _addresses = const [];
  List<_RebookLine> _lines = [];
  int _catalogReloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _catalogReloadGeneration++;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final payload = await api.get(
        '/bookings/${widget.bookingId}/rebook-options',
      );
      final raw = payload['rebook'];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException(
          'The booking preferences could not be loaded.',
        );
      }
      final options = RebookOptions.fromJson(raw);
      final lines = options.items.map((item) {
        return _RebookLine(
          serviceId: item.serviceId,
          serviceName: item.serviceName,
          serviceSlug: item.serviceSlug,
          quantity: item.quantity,
          previousVariantId: item.variantId,
          previousAddonIds: item.addonIds.toSet(),
          serviceCurrentlyBookable: item.serviceCurrentlyBookable,
        );
      }).toList();
      final addresses = await SavedAddressesApi(api.dio).listAddresses();
      final preferredAddressId = options.preferredAddressId;
      final addressId =
          addresses.any((address) => address.id == preferredAddressId)
          ? preferredAddressId
          : addresses.where((address) => address.isDefault).firstOrNull?.id ??
                addresses.firstOrNull?.id;
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _addresses = addresses;
        _selectedAddressId = addressId;
        _addressMatched = options.addressMatched;
        _previouslyQuoted = options.previouslyQuoted;
        _blockedReason = options.canRebook
            ? null
            : options.reason ?? 'This booking cannot be booked again.';
        _loading = false;
      });
      await _reloadCatalogForAddress();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingCatalog = false;
        _error =
            'Could not load the previous booking. Check your connection and retry.';
      });
    }
  }

  Future<void> _reloadCatalogForAddress() async {
    final generation = ++_catalogReloadGeneration;
    if (!mounted) return;
    final refreshedLines = _lines
        .map((line) => line.forCatalogReload())
        .toList();
    final address = _addresses
        .where((item) => item.id == _selectedAddressId)
        .firstOrNull;
    if (address == null || refreshedLines.isEmpty) {
      setState(() {
        _lines = refreshedLines;
        _loadingCatalog = false;
      });
      return;
    }
    setState(() => _loadingCatalog = true);
    final repository = ref.read(catalogRepositoryProvider);
    for (final line in refreshedLines) {
      if (!mounted || generation != _catalogReloadGeneration) return;
      if (line.serviceSlug == null || line.serviceSlug!.isEmpty) {
        line.unavailableMessage =
            'This service is no longer listed in the catalog.';
        line.service = null;
        continue;
      }
      try {
        final service = await repository.getServiceDetails(
          line.serviceSlug!,
          pincode: address.pincode,
        );
        if (!mounted || generation != _catalogReloadGeneration) return;
        if (service.id != line.serviceId ||
            !service.isActive ||
            !service.bookingEnabled) {
          line.service = null;
          line.unavailableMessage =
              'This service is no longer available for booking at this address.';
          continue;
        }
        line.service = service;
        line.unavailableMessage = null;
        final preferredVariantId = line.hasCatalogSelection
            ? line.variantId
            : line.previousVariantId;
        final preferredAddonIds = line.hasCatalogSelection
            ? line.addonIds
            : line.previousAddonIds;
        final variantExists =
            preferredVariantId == null ||
            service.variants.any((variant) => variant.id == preferredVariantId);
        line.variantId = variantExists ? preferredVariantId : null;
        line.addonIds = preferredAddonIds
            .where(
              (id) => service.addons.any(
                (addon) => addon.id == id && addon.isActive,
              ),
            )
            .toSet();
        line.hasCatalogSelection = true;
        line.selectionChanged =
            line.selectionChanged ||
            !variantExists ||
            line.addonIds.length != preferredAddonIds.length ||
            (service.variants.isNotEmpty && line.variantId == null);
      } catch (_) {
        if (!mounted || generation != _catalogReloadGeneration) return;
        line.service = null;
        line.unavailableMessage =
            'This service is not available in ${address.city} ${address.pincode}.';
      }
    }
    if (mounted && generation == _catalogReloadGeneration) {
      setState(() {
        _lines = refreshedLines;
        _loadingCatalog = false;
      });
    }
  }

  SavedAddressItem? get _selectedAddress => _addresses
      .where((address) => address.id == _selectedAddressId)
      .firstOrNull;

  bool get _canContinue =>
      _blockedReason == null &&
      !_loadingCatalog &&
      _lines.isNotEmpty &&
      _selectedAddress != null &&
      _lines.every(
        (line) =>
            line.service != null &&
            (line.service!.variants.isEmpty ||
                line.service!.variants.any(
                  (variant) => variant.id == line.variantId,
                )),
      );

  void _continueToCheckout() {
    final address = _selectedAddress;
    if (!_canContinue || address == null) return;
    final items = _lines
        .map((line) {
          final service = line.service!;
          final variant = service.variants
              .where((item) => item.id == line.variantId)
              .firstOrNull;
          final addonTotal = service.addons
              .where((addon) => line.addonIds.contains(addon.id))
              .fold<double>(0, (sum, addon) => sum + addon.price);
          return CheckoutItem(
            serviceId: service.id,
            serviceName: service.name,
            price: (variant?.price ?? service.startingPrice) + addonTotal,
            quantity: line.quantity,
            variantId: line.variantId,
            addonIds: line.addonIds.toList(growable: false),
            configurationLabel: _lineConfigurationLabel(line),
          );
        })
        .toList(growable: false);
    context.push(
      '/checkout',
      extra: <String, dynamic>{
        'cityId':
            ref.read(authControllerProvider).valueOrNull?.user.cityId ?? '',
        'items': items,
        'preferredAddressId': address.id,
        'rebookSourceBookingId': widget.bookingId,
      },
    );
  }

  String _lineConfigurationLabel(_RebookLine line) {
    final service = line.service;
    if (service == null) return '';
    final variant = service.variants
        .where((item) => item.id == line.variantId)
        .firstOrNull;
    return [
      if (variant != null) variant.name,
      ...service.addons
          .where((item) => line.addonIds.contains(item.id))
          .map((item) => item.name),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final address = _selectedAddress;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Review your booking'),
        backgroundColor: colors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _blockedReason != null
          ? _BlockedState(reason: _blockedReason!)
          : _addresses.isEmpty
          ? _NoAddressState(
              onAddAddress: () async {
                await context.push('/addresses');
                if (mounted) await _load();
              },
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (!_addressMatched)
                        const _Notice(
                          icon: Icons.location_searching_rounded,
                          text:
                              'Your previous address is no longer saved. Choose a current address and we’ll check service availability again.',
                        ),
                      if (_previouslyQuoted) ...[
                        const SizedBox(height: 10),
                        const _Notice(
                          icon: Icons.request_quote_outlined,
                          text:
                              'Your previous job used a custom quote. Its price and approval won’t carry over. Any new quote must be requested and approved for this booking.',
                        ),
                      ],
                      Text(
                        'Service address',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(address?.id),
                        initialValue: address?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _addresses
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  '${item.label} · ${item.city} ${item.pincode}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _loadingCatalog
                            ? null
                            : (id) async {
                                setState(() => _selectedAddressId = id);
                                await _reloadCatalogForAddress();
                              },
                      ),
                      if (address != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          address.displayAddress,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Previous choices',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      for (var index = 0; index < _lines.length; index++) ...[
                        _buildLine(context, _lines[index], index),
                        const SizedBox(height: 10),
                      ],
                      if (_loadingCatalog)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const _Notice(
                        icon: Icons.verified_user_outlined,
                        text:
                            'Current catalog prices and availability are shown. Taxes, offers, final fees, and the payable total are recalculated in checkout. No previous payment or coupon is reused.',
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: VeeduFixButton(
                      label: _loadingCatalog
                          ? 'Checking availability…'
                          : 'Review price & continue',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: _loadingCatalog,
                      onPressed: _canContinue ? _continueToCheckout : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLine(BuildContext context, _RebookLine line, int index) {
    final colors = Theme.of(context).colorScheme;
    final service = line.service;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_repair_service_outlined, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.serviceName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (_lines.length > 1 && service == null)
                IconButton(
                  tooltip: 'Remove unavailable service',
                  onPressed: _loadingCatalog
                      ? null
                      : () => setState(() => _lines.remove(line)),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
            ],
          ),
          if (service == null) ...[
            const SizedBox(height: 6),
            Text(
              line.unavailableMessage ?? 'This service is unavailable.',
              style: TextStyle(color: colors.error),
            ),
            TextButton.icon(
              onPressed: () => context.push(
                '/search?q=${Uri.encodeComponent(line.serviceName)}',
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Find a similar service'),
            ),
          ] else ...[
            if (line.selectionChanged) ...[
              const SizedBox(height: 8),
              const _Notice(
                icon: Icons.info_outline_rounded,
                text:
                    'Some previous options changed or are no longer available. Review your selections below.',
              ),
            ],
            const SizedBox(height: 12),
            if (service.variants.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue:
                    service.variants.any(
                      (variant) => variant.id == line.variantId,
                    )
                    ? line.variantId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Service option',
                  border: OutlineInputBorder(),
                ),
                items: service.variants
                    .map(
                      (variant) => DropdownMenuItem(
                        value: variant.id,
                        child: Text(
                          '${variant.name} · ₹${variant.price.toStringAsFixed(0)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingCatalog
                    ? null
                    : (id) => setState(() => line.variantId = id),
              ),
            if (service.addons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Add-ons',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final addon in service.addons.where((item) => item.isActive))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: line.addonIds.contains(addon.id),
                  onChanged: _loadingCatalog
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            line.addonIds.add(addon.id);
                          } else {
                            line.addonIds.remove(addon.id);
                          }
                        }),
                  title: Text(addon.name),
                  subtitle: Text('₹${addon.price.toStringAsFixed(0)}'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Quantity', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  onPressed: !_loadingCatalog && line.quantity > 1
                      ? () => setState(() => line.quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${line.quantity}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  onPressed: !_loadingCatalog && line.quantity < 20
                      ? () => setState(() => line.quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Current starting total · ₹${_lineTotal(line).toStringAsFixed(0)}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _lineTotal(_RebookLine line) {
    final service = line.service!;
    final variant = service.variants
        .where((item) => item.id == line.variantId)
        .firstOrNull;
    final addons = service.addons
        .where((item) => line.addonIds.contains(item.id))
        .fold<double>(0, (sum, item) => sum + item.price);
    return ((variant?.price ?? service.startingPrice) + addons) * line.quantity;
  }
}

class _RebookLine {
  _RebookLine({
    required this.serviceId,
    required this.serviceName,
    required this.serviceSlug,
    required this.quantity,
    required this.previousVariantId,
    required this.previousAddonIds,
    required this.serviceCurrentlyBookable,
  });

  final String serviceId;
  final String serviceName;
  final String? serviceSlug;
  int quantity;
  final String? previousVariantId;
  final Set<String> previousAddonIds;
  final bool serviceCurrentlyBookable;
  CatalogService? service;
  String? variantId;
  Set<String> addonIds = <String>{};
  bool selectionChanged = false;
  bool hasCatalogSelection = false;
  String? unavailableMessage;

  _RebookLine forCatalogReload() =>
      _RebookLine(
          serviceId: serviceId,
          serviceName: serviceName,
          serviceSlug: serviceSlug,
          quantity: quantity,
          previousVariantId: previousVariantId,
          previousAddonIds: previousAddonIds,
          serviceCurrentlyBookable: serviceCurrentlyBookable,
        )
        ..variantId = variantId
        ..addonIds = Set<String>.from(addonIds)
        ..selectionChanged = selectionChanged
        ..hasCatalogSelection = hasCatalogSelection;
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          VeeduFixSecondaryButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _BlockedState extends StatelessWidget {
  const _BlockedState({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded, size: 36),
          const SizedBox(height: 12),
          Text(reason, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          VeeduFixSecondaryButton(
            label: 'Back to booking',
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    ),
  );
}

class _NoAddressState extends StatelessWidget {
  const _NoAddressState({required this.onAddAddress});
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add a service address before rebooking.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          VeeduFixButton(
            label: 'Add address',
            icon: Icons.add_location_alt_outlined,
            onPressed: onAddAddress,
          ),
        ],
      ),
    ),
  );
}
