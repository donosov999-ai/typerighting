import type { Bank, Exercise } from './content';

/** Transform a copy; never alter the source lesson or its punctuation. */
export function practiceLines(lines: readonly string[], plain: boolean): string[] {
  if (!plain) return [...lines];
  return lines.map(line => line.replace(/[\p{P}\p{S}]/gu, '').replace(/\s+/g, ' ').trim()).filter(Boolean);
}
export function practiceProgressKey(bank: Bank, plain: boolean): string {
  return `tr_progress_${bank}${plain && bank !== 'digits' ? '_plain' : ''}`;
}
export function numericExercises(): Exercise[] {
  const lines = [
    '12345 67890 09876 54321 13579 24680',
    '10293 84756 56473 82910 11223 44556 77889 900',
    '01234 56789 02468 13579 98765 43210',
    '101 202 303 404 505 606 707 808 909',
    '10 20 30 40 50 60 70 80 90 100',
    '987 654 321 012 345 678 901 234 567 890',
  ];
  return lines.map((line, i) => ({id: `digits-${i + 1}`, bank: 'digits', title: String(i + 1), lines: [line]}));
}
