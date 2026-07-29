import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/network/api_client.dart';

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
  });
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {
        'role': role,
        'parts': [{'text': text}],
      };
}

class AiAssistantState {
  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  AiAssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiAssistantController extends StateNotifier<AiAssistantState> {
  AiAssistantController(this._apiClient)
      : super(const AiAssistantState(messages: [
          ChatMessage(role: 'model', text: 'Hi! How can I help you today?')
        ]));

  final ApiClient _apiClient;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', text: text.trim());
    final historyForApi = state.messages.map((m) => m.toJson()).toList();

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final response = await _apiClient.post('/ai/chat', data: {
        'message': userMsg.text,
        'history': historyForApi,
      });

      final botMsg = ChatMessage(role: 'model', text: response['reply'] as String? ?? 'Sorry, no response.');
      state = state.copyWith(
        messages: [...state.messages, botMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final aiAssistantControllerProvider =
    StateNotifierProvider.autoDispose<AiAssistantController, AiAssistantState>((ref) {
  return AiAssistantController(ref.watch(apiClientProvider));
});
