/**
 * Normalises Uzbek phone numbers to E.164 (+998XXXXXXXXX). Accepts "+998 90 123 45 67",
 * "998901234567", "90 123-45-67". Returns null for anything else.
 * (Other countries can be enabled later by extending ALLOWED_PREFIXES.)
 */
const UZ_OPERATOR_CODES = /^(20|33|50|55|61|62|65|66|67|69|70|71|72|73|74|75|76|77|78|79|88|90|91|93|94|95|97|98|99)$/;

export function normalizePhone(input: string | undefined | null): string | null {
  if (!input) return null;
  const digits = input.replace(/[\s\-()+.]/g, '');
  if (!/^\d+$/.test(digits)) return null;
  let national: string;
  if (digits.length === 12 && digits.startsWith('998')) national = digits.slice(3);
  else if (digits.length === 9) national = digits;
  else return null;
  if (!UZ_OPERATOR_CODES.test(national.slice(0, 2))) return null;
  return `+998${national}`;
}

/** +998901234567 → +998 90 *** ** 67 (for logs / UI where full number is not needed). */
export function maskPhone(phone: string): string {
  if (phone.length < 7) return '***';
  return `${phone.slice(0, 6)}***${phone.slice(-2)}`;
}
