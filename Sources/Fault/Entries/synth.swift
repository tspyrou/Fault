import Foundation
import CommandLineKit
import Defile

func synth(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    cli.addOptions(help)

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output netlist. (Default: Netlists/ + input + .netlist.v)")
    cli.addOptions(filePath)

    let liberty = StringOption(shortFlag: "l", longFlag: "liberty", helpMessage: "Liberty file. (Required.)")
    cli.addOptions(liberty)

    let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Top module. (Required.)")
    cli.addOptions(topModule)
    
    do {
        try cli.parse()
    } catch {
        Stderr.print(error)
        Stderr.print("Invoke fault synth --help for more info.")
        return EX_USAGE
    }

    if help.value {
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count < 1 {
        Stderr.print("At least one Verilog file is required.")
        Stderr.print("Invoke fault synth --help for more info.")
        return EX_USAGE
    }      

    let fileManager = FileManager()
    let files = args

    for file in files {
        if !fileManager.fileExists(atPath: file) {
            Stderr.print("File '\(file)' not found.")
            return EX_NOINPUT
        }
    }

    guard let module = topModule.value else {
        Stderr.print("Option --top is required.")
        Stderr.print("Invoke fault synth --help for more info.")
        return EX_USAGE
    }

    guard let libertyFile = liberty.value else {
        Stderr.print("Option --liberty is required.")
        Stderr.print("Invoke fault synth --help for more info.")
        return EX_USAGE
    }

    if !fileManager.fileExists(atPath: libertyFile) {
        Stderr.print("Liberty file '\(libertyFile)' not found.")
        return EX_NOINPUT
    }
    
    if !libertyFile.hasSuffix(".lib") {
        Stderr.print(
            "Warning: Liberty file provided does not end with .lib."
        )
    }

    let output = filePath.value ?? "Netlists/\(module).netlist.v"

    let script = Synthesis.script(for: module, in: args, cutting: false, liberty: libertyFile, output: output)

    let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
    let result = "echo '\(script)' | '\(yosysExecutable)'".sh()

    if result != EX_OK {
        Stderr.print("A yosys error has occurred.");
        return Int32(result)
    }

    return EX_OK
}
