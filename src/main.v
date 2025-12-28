import os
import exception

fn main() {
	mut program := ''

	for i in 1 .. os.args.len {
		if os.args[i] == 'run' && i + 1 < os.args.len {
			program = os.args[i + 1]
			break
		}
    }
    log := compile(program)
    for item in log {
        println(item)
    }
}

fn compile(program string) []string {
    mut log := []string{}
    mut variables := []string{}

    lines := os.read_lines(program) or {
        println('Failed to read $program')
        return log
    }

    mut linecn := 1
    for line in lines {
        linecn += 1
        line_trimmed := line.trim_space()

        if line_trimmed.starts_with('log(') {
            if line_trimmed.contains('"') {
                mut logor := line_trimmed.replace("log(", "")
                logor = logor.replace(")", "")
                logor = logor.replace('"', "")
                log << logor
            } else {
                mut step1 := line_trimmed.replace("log(", "")
                step1 = step1.replace(")", "")
                vartoget := step1.replace('"', "").trim_space()

                mut value := ""
                for item in variables {
                    parts := item.split("&")
                    if parts.len == 2 && parts[0] == vartoget {
                        value = parts[1]
                        break
                    }
                }
                if value != "" {
                    log << value
                }
            }
        }

        if line_trimmed.starts_with('var') {
            words := line_trimmed.split(" ")

            if words.len >= 4 {
                varname := words[1]
                varvalue := words[3..].join(" ").trim_space()
                variables << "$varname&$varvalue"
            } else {
                exception.exception(linecn, line_trimmed, "Malformed variable declaration")
            }
        }
    }

    return log
}
