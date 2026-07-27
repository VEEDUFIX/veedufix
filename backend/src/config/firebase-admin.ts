export async function sendPushNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, unknown>
): Promise<{ successCount: number; failureCount: number }> {
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  // The workspace does not currently expose a Firebase service-account setup.
  // Keep this as a safe no-op fallback so notification delivery never blocks the main flow.
  void title;
  void body;
  void data;

  return { successCount: 0, failureCount: tokens.length };
}
