using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace FinancialCases
{
    public static class Scenarios
    {
        public static int ApplyWithCompareExchange(int start, int change)
        {
            var value = start;
            Parallel.For(0, 2, _ =>
            {
                while (true)
                {
                    var seen = Volatile.Read(ref value);
                    if (seen < change || Interlocked.CompareExchange(ref value, seen - change, seen) == seen)
                    {
                        return;
                    }
                }
            });
            return value;
        }

        public static int ApplyAfterBarrier(int start, int change)
        {
            var value = start;
            using (var gate = new Barrier(2))
            {
                Parallel.Invoke(
                    () =>
                    {
                        var seen = value;
                        gate.SignalAndWait();
                        value = seen - change;
                    },
                    () =>
                    {
                        var seen = value;
                        gate.SignalAndWait();
                        value = seen - change;
                    });
            }
            return value;
        }

        public static double SumAtBoundary(double[] inputs)
        {
            var total = 0d;
            foreach (var input in inputs)
            {
                total = Math.Round(total + input, 2, MidpointRounding.AwayFromZero);
            }
            return total;
        }

        public static double SumAtEnd(double[] inputs)
        {
            var total = 0d;
            foreach (var input in inputs)
            {
                total += input;
            }
            return total;
        }

        public static int ProcessEveryDelivery(string[] ids)
        {
            var effects = 0;
            foreach (var id in ids)
            {
                effects++;
            }
            return effects;
        }

        public static int ProcessUniqueDeliveries(string[] ids)
        {
            var seen = new HashSet<string>();
            var effects = 0;
            foreach (var id in ids)
            {
                if (seen.Add(id))
                {
                    effects++;
                }
            }
            return effects;
        }

        public static decimal SelectAllRows(Record[] rows)
        {
            var total = 0m;
            foreach (var row in rows)
            {
                total += row.Amount;
            }
            return total;
        }

        public static decimal SelectCurrentRows(Record[] rows)
        {
            var total = 0m;
            foreach (var row in rows)
            {
                if (row.Current)
                {
                    total += row.Amount;
                }
            }
            return total;
        }
    }

    public sealed class Record
    {
        public readonly string Key;
        public readonly bool Current;
        public readonly decimal Amount;

        public Record(string key, bool current, decimal amount)
        {
            Key = key;
            Current = current;
            Amount = amount;
        }
    }
}
