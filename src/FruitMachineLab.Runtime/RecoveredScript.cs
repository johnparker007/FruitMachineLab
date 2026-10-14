using System.Globalization;
using System.Text.RegularExpressions;

namespace FruitMachineLab.Runtime;

public record Instruction(ushort Site, ushort Token, string Operation, ushort? Value, ushort? Branch);

public sealed class RecoveredScript
{
    public IReadOnlyList<Instruction> Instructions { get; }
    public RecoveredScript(string file)
    {
        var items = new List<Instruction>();
        foreach (var line in File.ReadLines(file))
        {
            var match = Regex.Match(line, @"^\s*\*?\s*([0-9A-F]{4})\s+([0-9A-F]{4})\s+(\w+)(.*)$");
            if (!match.Success) continue;
            ushort? Field(string name)
            {
                var f = Regex.Match(match.Groups[4].Value, name + @"=0x([0-9A-Fa-f]{4})");
                return f.Success ? ushort.Parse(f.Groups[1].Value, NumberStyles.HexNumber) : null;
            }
            items.Add(new(Parse(match.Groups[1].Value), Parse(match.Groups[2].Value), match.Groups[3].Value,
                Field("inline_value") ?? Field("value"), Field("branch")));
        }
        Instructions = items;
    }
    private static ushort Parse(string value) => ushort.Parse(value, NumberStyles.HexNumber);
}

// Executes the recovered memory/arithmetic subset. Unknown helpers never become no-ops.
public sealed class ScriptExecutor(Machine machine)
{
    public Func<ushort, bool>? InputCondition { get; init; }
    public Action<Instruction, Machine>? BeforeInstruction { get; init; }
    public void Run(RecoveredScript script, int budget = 1000)
        => Execute(script.Instructions, true, budget);
    public void RunRange(RecoveredScript script, ushort first, ushort last)
    {
        var items=script.Instructions.Where(i=>i.Site>=first && i.Site<=last).ToArray();
        if(items.Length==0 || items[0].Site!=first || items[^1].Site!=last)
            throw new InvalidDataException("Requested script range boundaries are absent");
        Execute(items,false,1000);
    }
    private void Execute(IReadOnlyList<Instruction> items, bool requireReturn, int budget)
    {
        var pc = 0;
        while (pc < items.Count)
        {
            if (--budget < 0) throw new InvalidOperationException("VM instruction budget exhausted");
            var i = items[pc++];
            BeforeInstruction?.Invoke(i,machine);
            ushort Value() => i.Value ?? throw new InvalidDataException($"Missing operand at {i.Site:X4}");
            void Binary(Func<ushort, ushort, ushort> op) { var b = machine.Pop(); var a = machine.Pop(); machine.Data.Push(op(a,b)); }
            switch (i.Operation)
            {
                case "vm_push_inline_byte_literal":
                case "vm_push_word_body_byte":
                case "vm_push_word_body_word": machine.Data.Push(Value()); break;
                case "vm_push_local_frame_address": machine.Data.Push(Cell.Add(machine.LocalFrame, Value())); break;
                case "vm_push_zero": machine.Data.Push(0); break;
                case "vm_store_byte": { var address = machine.Pop(); machine.Memory[address] = (byte)machine.Pop(); break; }
                case "vm_store_word": { var address = machine.Pop(); machine.WriteWord(address, machine.Pop()); break; }
                case "vm_clear_byte_memory": machine.Memory[machine.Pop()] = 0; break;
                case "vm_fetch_unsigned_byte": machine.Data.Push(machine.Memory[machine.Pop()]); break;
                case "vm_duplicate_cell": { var v = machine.Pop(); machine.Data.Push(v); machine.Data.Push(v); break; }
                case "vm_drop_cell": machine.Pop(); break;
                case "vm_add_words": Binary(Cell.Add); break;
                case "vm_subtract_top_from_second": Binary(Cell.Subtract); break;
                case "vm_min_signed": Binary(Cell.Min); break;
                case "vm_compare_equal": Binary((a,b) => Cell.Flag(a == b)); break;
                case "vm_test_input_condition": machine.Data.Push(Cell.Flag((InputCondition ?? throw new NotSupportedException("Input condition provider required"))(Value()))); break;
                case "vm_branch_forward8_if_zero":
                case "vm_branch_backward8_if_zero":
                    if (machine.Pop() == 0)
                    {
                        pc = items.ToList().FindIndex(x => x.Site == i.Branch);
                        if (pc < 0) throw new InvalidDataException("Branch target absent from listing");
                    }
                    break;
                case "vm_return_to_caller_stream": return;
                default: throw new NotSupportedException($"Untranslated helper {i.Operation} at {i.Site:X4}, token {i.Token:X4}");
            }
        }
        if(requireReturn) throw new InvalidDataException("Script fell through without return");
    }
}
