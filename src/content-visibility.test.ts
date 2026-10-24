import { describe, it, expect, vi, afterEach } from 'vitest';
import { BANKS, exercisesOfBank, loadExercises, type Bank, type Exercise } from './content';

const hidden: Bank[] = ['abandon', 'engRus', 'letterByLetter'];
const fixtures: Exercise[] = [...hidden, 'classic' as Bank].map(bank => ({id: bank, bank, title: bank, lines: ['example']}));
afterEach(() => vi.unstubAllGlobals());
describe('disabled course material', () => {
  it.each(hidden)('blocks %s even when an old caller supplies the original data', bank => {
    expect(BANKS).not.toContain(bank);
    expect(exercisesOfBank(fixtures, bank)).toEqual([]);
  });
  it('does not load disabled course material into the training pool', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({json: async () => fixtures}));
    const loaded = await loadExercises();
    expect(loaded.map(e => e.bank)).toEqual(['classic']);
    expect(exercisesOfBank(loaded, 'classic')).toHaveLength(1);
  });
});
