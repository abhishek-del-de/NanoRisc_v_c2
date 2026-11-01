# PowerShell script to compile and run all Verilog testbenches using Icarus Verilog
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Compiling and Simulating All NanoRISC-V-C2 Modules" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$modules = @(
    @{ Name = "program_counter";    Files = "verilog\program_counter.v verilog\program_counter_tb.v" },
    @{ Name = "instruction_memory"; Files = "verilog\instruction_memory.v verilog\instruction_memory_tb.v" },
    @{ Name = "register_file";      Files = "verilog\register_file.v verilog\register_file_tb.v" },
    @{ Name = "alu";                Files = "verilog\alu.v verilog\alu_tb.v" },
    @{ Name = "control_unit";       Files = "verilog\control_unit.v verilog\control_unit_tb.v" },
    @{ Name = "data_memory";        Files = "verilog\data_memory.v verilog\data_memory_tb.v" },
    @{ Name = "pipeline_reg";       Files = "verilog\pipeline_reg.v verilog\pipeline_reg_tb.v" },
    @{ Name = "nanoriscv_c2_top";   Files = "verilog\program_counter.v verilog\instruction_memory.v verilog\register_file.v verilog\alu.v verilog\control_unit.v verilog\data_memory.v verilog\pipeline_reg.v verilog\nanoriscv_c2_top.v verilog\nanoriscv_c2_top_tb.v" }
)

foreach ($mod in $modules) {
    Write-Host "`n--> Simulating: $($mod.Name) ..." -ForegroundColor Yellow
    $vvp_out = "$($mod.Name).vvp"
    $cmd_compile = "iverilog -o $vvp_out $($mod.Files)"
    Invoke-Expression $cmd_compile
    if ($LASTEXITCODE -eq 0) {
        Invoke-Expression "vvp $vvp_out"
        Write-Host "    Waveform generated: $($mod.Name).vcd" -ForegroundColor Green
    } else {
        Write-Host "    Compilation failed for $($mod.Name)!" -ForegroundColor Red
    }
}

Write-Host "`nAll simulations completed!" -ForegroundColor Cyan

