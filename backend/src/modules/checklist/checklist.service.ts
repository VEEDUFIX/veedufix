export type ChecklistValidationResult = {
  isComplete: boolean;
  missingItems: string[];
};

function normalizeChecklistItem(item: unknown, index: number): { label: string; complete: boolean } {
  if (typeof item === "string") {
    return {
      label: item.trim() || `item-${index + 1}`,
      complete: item.trim().length > 0
    };
  }

  if (item && typeof item === "object") {
    const record = item as Record<string, unknown>;
    const label =
      (typeof record.label === "string" && record.label.trim()) ||
      (typeof record.name === "string" && record.name.trim()) ||
      (typeof record.title === "string" && record.title.trim()) ||
      `item-${index + 1}`;

    const explicitStatus =
      typeof record.completed === "boolean"
        ? record.completed
        : typeof record.checked === "boolean"
          ? record.checked
          : typeof record.done === "boolean"
            ? record.done
            : typeof record.isComplete === "boolean"
              ? record.isComplete
              : true;

    return {
      label,
      complete: explicitStatus
    };
  }

  return {
    label: `item-${index + 1}`,
    complete: item !== null && item !== undefined
  };
}

export function validateChecklistCompletion(
  _serviceId: string,
  submittedChecklist: unknown
): ChecklistValidationResult {
  if (submittedChecklist === null || submittedChecklist === undefined) {
    return { isComplete: true, missingItems: [] };
  }

  const items: Array<{ label: string; complete: boolean }> = Array.isArray(submittedChecklist)
    ? submittedChecklist.map((item, index) => normalizeChecklistItem(item, index))
    : typeof submittedChecklist === "object"
      ? Object.entries(submittedChecklist as Record<string, unknown>).map(([key, value], index) => ({
          label: key || `item-${index + 1}`,
          complete:
            typeof value === "boolean"
              ? value
              : value !== null && value !== undefined && String(value).trim() !== ""
        }))
      : [normalizeChecklistItem(submittedChecklist, 0)];

  const missingItems = items.filter((item) => !item.complete).map((item) => item.label);

  return {
    isComplete: missingItems.length === 0,
    missingItems
  };
}
