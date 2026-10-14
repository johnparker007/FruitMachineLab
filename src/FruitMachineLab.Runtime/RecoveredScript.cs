using System.Globalization;
using System.Text.RegularExpressions;

namespace FruitMachineLab.Runtime;

public record Instruction(ushort Site, ushort Token, string Operation, ushort? Value, ushort? Branch,
    ushort? Body = null, ushort? PushAddress = null, ushort? Native = null,string? InlineStream=null);

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
                Field("inline_value") ?? Field("value"), Field("branch"),Field("body"),Field("push_address"),Field("native"),
                Regex.Match(match.Groups[4].Value,@"inline_stream=\[(.*)\]") is {Success:true} stream ? stream.Groups[1].Value : null));
        }
        Instructions = items;
    }
    private static ushort Parse(string value) => ushort.Parse(value, NumberStyles.HexNumber);
}

// Executes the recovered memory/arithmetic subset. Unknown helpers never become no-ops.
public sealed class ScriptExecutor(Machine machine)
{
    public Func<ushort, bool>? InputCondition { get; init; }
    public Func<ushort,ushort>? InputConditionCell { get; init; }
    public Action<Instruction, Machine>? BeforeInstruction { get; init; }
    public Action<Instruction,Machine>? OperationBoundary { get; init; }
    public Func<ushort, RecoveredScript>? ResolveScript { get; init; }
    public Func<ushort,Instruction>? ResolveWord { get; init; }
    public Func<ushort>? LoopIndex { get; init; }
    // Explicit handlers for recovered words or declared verification boundaries.
    // An unhandled word never becomes an implicit no-op.
    public Func<Instruction, Machine, bool>? WordHandler { get; init; }
    private int remaining;
    public void Run(RecoveredScript script, int budget = 1000)
    {
        remaining=budget;
        Execute(script.Instructions, true);
    }
    public void RunRange(RecoveredScript script, ushort first, ushort last)
    {
        var items=script.Instructions.Where(i=>i.Site>=first && i.Site<=last).ToArray();
        if(items.Length==0 || items[0].Site!=first || items[^1].Site!=last)
            throw new InvalidDataException("Requested script range boundaries are absent");
        remaining=1000;
        var following=script.Instructions.SkipWhile(i=>i.Site!=last).Skip(1).FirstOrDefault()?.Site;
        Execute(items,false,following);
    }
    private void Execute(IReadOnlyList<Instruction> items, bool requireReturn,ushort? boundaryContinuation=null)
    {
        var pc = 0;
        while (pc < items.Count)
        {
            if (--remaining < 0) throw new InvalidOperationException("VM instruction budget exhausted");
            var i = items[pc++];
            BeforeInstruction?.Invoke(i,machine);
            OperationBoundary?.Invoke(i,machine);
            ushort Value() => i.Value ?? throw new InvalidDataException($"Missing operand at {i.Site:X4}");
            void Binary(Func<ushort, ushort, ushort> op) { var b = machine.Pop(); var a = machine.Pop(); machine.Data.Push(op(a,b)); }
            VmControlStack Control()=>machine.Control ?? throw new NotSupportedException("Physical VM control-stack context required");
            ushort Continuation()=>pc<items.Count ? items[pc].Site : boundaryContinuation ?? throw new InvalidDataException("Call/loop continuation missing from script range");
            void Jump(ushort site) {
                pc=items.ToList().FindIndex(x=>x.Site==site);
                if(pc<0)throw new InvalidDataException("Control-stack target absent from script");
            }
            switch (i.Operation)
            {
                case "vm_push_inline_byte_literal":
                case "vm_push_inline_word_literal":
                case "vm_push_word_body_byte":
                case "vm_push_word_body_word": machine.Data.Push(Value()); break;
                case "vm_push_local_frame_address": machine.Data.Push(Cell.Add(machine.LocalFrame, Value())); break;
                case "vm_push_zero": machine.Data.Push(0); break;
                case "vm_push_two": machine.Data.Push(2); break;
                case "vm_push_one": machine.Data.Push(1); break;
                case "vm_push_true_minus_one": machine.Data.Push(ushort.MaxValue); break;
                case "vm_push_loop_index": machine.Data.Push(machine.Control?.LoopIndex ?? (LoopIndex ?? throw new NotSupportedException("Loop context required"))()); break;
                case "vm_allocate_local_frame": Control().AllocateLocalFrame(machine.Pop());break;
                case "vm_enter_loop_frame": { var start=machine.Pop();var limit=machine.Pop();Control().EnterLoop(start,limit,Continuation());break; }
                case "vm_loop_increment_one": if(Control().IncrementLoop() is { } target)Jump(target);break;
                case "vm_store_byte": { var address = machine.Pop(); machine.Memory[address] = (byte)machine.Pop(); break; }
                case "vm_store_word": { var address = machine.Pop(); machine.WriteWord(address, machine.Pop()); break; }
                case "vm_add_to_word_memory": { var address=machine.Pop();machine.WriteWord(address,Cell.Add(machine.ReadWord(address),machine.Pop()));break; }
                case "vm_clear_byte_memory": machine.Memory[machine.Pop()] = 0; break;
                case "vm_clear_word_memory_bits": {var mask=machine.Pop();var address=machine.Pop();machine.WriteWord(address,(ushort)(machine.ReadWord(address)&~mask));break;}
                case "vm_fetch_unsigned_byte": machine.Data.Push(machine.Memory[machine.Pop()]); break;
                case "vm_fetch_word": machine.Data.Push(machine.ReadWord(machine.Pop())); break;
                case "vm_fetch_byte_and_following_word": {
                    var address=machine.Pop();machine.Data.Push(machine.ReadWord(Cell.Add(address,1)));machine.Data.Push(machine.Memory[address]);break;
                }
                case "vm_fetch_two_words": {
                    var address=machine.Pop(); machine.Data.Push(machine.ReadWord(Cell.Add(address,2))); machine.Data.Push(machine.ReadWord(address)); break;
                }
                case "vm_duplicate_cell": { var v = machine.Pop(); machine.Data.Push(v); machine.Data.Push(v); break; }
                case "vm_drop_cell": machine.Pop(); break;
                case "vm_drop_two_cells": machine.Pop();machine.Pop();break;
                case "vm_swap_two_cells": { var b=machine.Pop(); var a=machine.Pop(); machine.Data.Push(b); machine.Data.Push(a); break; }
                case "vm_move_cell_to_return_stack": Control().Push(machine.Pop());break;
                case "vm_copy_return_stack_cell": machine.Data.Push(machine.ReadWord(Control().Pointer));break;
                case "vm_move_cell_from_return_stack": machine.Data.Push(Control().Pop());break;
                case "vm_add_second_cell_to_top": {var top=machine.Pop();machine.Data.Push(Cell.Add(top,machine.Data.Peek()));break;}
                case "vm_shift_left_one": machine.Data.Push(unchecked((ushort)(machine.Pop()<<1)));break;
                case "vm_execute_token_from_stack": {
                    var token=machine.Pop();
                    var word=(ResolveWord ?? throw new NotSupportedException("Dynamic word resolver required"))(token);
                    if(word.Body is not { } entry || ResolveScript is null)throw new NotSupportedException($"Untranslated EXECUTE word {token:X4}");
                    ushort? next=machine.Control is not null ? Continuation() : null;
                    if(next is { } at)Control().EnterCall(at);
                    if(word.PushAddress is { } address)machine.Data.Push(address);
                    Execute(ResolveScript(entry).Instructions,true);
                    if(next is { } expected && Control().ResumeCursor!=expected)throw new NotSupportedException("Nonlocal dynamic VM continuation");
                    break;
                }
                case "vm_copy_second_cell": { var b=machine.Pop(); var a=machine.Pop(); machine.Data.Push(a); machine.Data.Push(b); machine.Data.Push(a); break; }
                case "vm_rotate_three_cells": {
                    var c=machine.Pop(); var b=machine.Pop(); var a=machine.Pop(); machine.Data.Push(b); machine.Data.Push(c); machine.Data.Push(a); break;
                }
                case "vm_multiply_to_double_cell": {
                    var b=machine.Pop(); var a=machine.Pop(); uint product=(uint)a*b;
                    machine.Data.Push((ushort)product); machine.Data.Push((ushort)(product>>16)); break;
                }
                case "vm_divide_double_cells_keep_quotient": {
                    var divisor=machine.Pop(); var high=machine.Pop(); var low=machine.Pop();
                    var result=Mpu4Arithmetic.DivideDouble(low,high,divisor);
                    machine.Data.Push(result.Remainder); machine.Data.Push(result.Quotient); break;
                }
                case "vm_add_words": Binary(Cell.Add); break;
                case "vm_add_double_cells": {
                    var bHigh=machine.Pop();var bLow=machine.Pop();var aHigh=machine.Pop();var aLow=machine.Pop();
                    uint sum=unchecked((((uint)aHigh<<16)|aLow)+(((uint)bHigh<<16)|bLow));
                    machine.Data.Push((ushort)sum);machine.Data.Push((ushort)(sum>>16));break;
                }
                case "call_vm_signed_double_divide_drop_remainder": {
                    var dHigh=machine.Pop();var dLow=machine.Pop();var nHigh=machine.Pop();var nLow=machine.Pop();
                    uint quotient=Mpu4Arithmetic.SignedDoubleQuotient(((uint)nHigh<<16)|nLow,((uint)dHigh<<16)|dLow);
                    machine.Data.Push((ushort)quotient);machine.Data.Push((ushort)(quotient>>16));break;
                }
                case "vm_increment_word": machine.Data.Push(Cell.Add(machine.Pop(),1));break;
                case "vm_decrement_word": machine.Data.Push(Cell.Subtract(machine.Pop(),1));break;
                case "vm_negate_cell": machine.Data.Push(Cell.Subtract(0,machine.Pop()));break;
                case "vm_test_zero": machine.Data.Push(Cell.Flag(machine.Pop()==0));break;
                case "vm_arithmetic_shift_right_one": machine.Data.Push(unchecked((ushort)((short)machine.Pop()>>1)));break;
                case "vm_subtract_top_from_second": Binary(Cell.Subtract); break;
                case "vm_min_signed": Binary(Cell.Min); break;
                case "vm_max_signed": Binary((a,b)=>(short)a>(short)b ? a : b);break;
                case "vm_compare_equal": Binary((a,b) => Cell.Flag(a == b)); break;
                case "vm_compare_top_lt_second_signed": Binary((a,b)=>Cell.Flag((short)b<(short)a)); break;
                case "vm_compare_top_gt_second_unsigned": Binary((a,b)=>Cell.Flag(b>a)); break;
                case "vm_compare_top_lt_second_unsigned": Binary((a,b)=>Cell.Flag(b<a));break;
                case "vm_test_greater_than_zero": machine.Data.Push(Cell.Flag((short)machine.Pop()>0)); break;
                case "vm_bitwise_and": Binary((a,b)=>(ushort)(a&b)); break;
                case "vm_bitwise_or": Binary((a,b)=>(ushort)(a|b)); break;
                case "vm_bitwise_xor": Binary((a,b)=>(ushort)(a^b)); break;
                case "vm_bitwise_not": machine.Data.Push((ushort)~machine.Pop()); break;
                case "vm_test_word_memory_mask": {
                    var mask=machine.Pop(); var address=machine.Pop(); machine.Data.Push(Cell.Flag((machine.ReadWord(address)&mask)!=0)); break;
                }
                case "call_advance_random_seed": Mpu4Random.AdvanceSeed(machine); break;
                case "call_nvram_refresh_complement_checksum_if_game": Mpu4Nvram.Refresh(machine);break;
                case "vm_test_input_condition": machine.Data.Push(InputConditionCell is { } provider ? provider(Value()) :
                    Cell.Flag((InputCondition ?? throw new NotSupportedException("Input condition provider required"))(Value()))); break;
                case "vm_branch_forward8_if_zero":
                case "vm_branch_backward8_if_zero":
                    if (machine.Pop() == 0)
                    {
                        pc = items.ToList().FindIndex(x => x.Site == i.Branch);
                        if (pc < 0) throw new InvalidDataException("Branch target absent from listing");
                    }
                    break;
                case "vm_branch_unsigned_forward8":
                case "vm_branch_backward8": Jump(i.Branch ?? throw new InvalidDataException("Missing branch target"));break;
                case "vm_return_to_caller_stream": machine.Control?.Return();return;
                case "vm_return_if_nonzero": if(machine.Pop()!=0) { machine.Control?.Return();return; }break;
                default:
                    if(WordHandler?.Invoke(i,machine)==true) break;
                    if(i.Body is { } body && ResolveScript is not null)
                    {
                        ushort? next=machine.Control is not null ? Continuation() : null;
                        if(next is { } cursor)machine.Control!.EnterCall(cursor);
                        if(i.PushAddress is { } address) machine.Data.Push(address);
                        Execute(ResolveScript(body).Instructions,true);
                        if(next is { } expected && machine.Control!.ResumeCursor!=expected)
                            throw new NotSupportedException("Nonlocal VM continuation requires separate recovery");
                    }
                    else throw new NotSupportedException($"Untranslated helper {i.Operation} at {i.Site:X4}, token {i.Token:X4}");
                    break;
            }
        }
        if(requireReturn) throw new InvalidDataException("Script fell through without return");
    }
}
