import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/wallet_entities.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

export '../../domain/entities/wallet_entities.dart';

final walletProvider = FutureProvider.autoDispose<WalletDetails>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/wallet/');
  return WalletDetails.fromJson(response as Map<String, dynamic>);
});
