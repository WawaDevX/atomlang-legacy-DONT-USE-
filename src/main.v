import os
import exception
import time
import rand

fn main() {
	mut program := ''
	for i in 1 .. os.args.len {
		if os.args[i] == 'run' && i + 1 < os.args.len {
			program = os.args[i + 1]
			break
		}
	}
	run_program(program)
}

fn run_program(program string) {
	mut variables := []string{}
	lines := os.read_lines(program) or {
		println('Failed to read ${program}')
		return
	}
	
	mut linecn := 0
	mut skip_until_ifend := false
	
	for line in lines {
		linecn += 1
		line_trimmed := line.trim_space()
		
		// Skip empty lines and comments
		if line_trimmed == '' || line_trimmed.starts_with('//') {
			continue
		}
		
		// Handle if.end
		if line_trimmed == 'if.end' {
			skip_until_ifend = false
			continue
		}
		
		// Skip lines inside failed if conditions
		if skip_until_ifend {
			continue
		}
		
		// Handle if conditions
		if line_trimmed.starts_with('if ') {
			condition := line_trimmed[3..].trim_space()
			if !evaluate_condition(condition, variables) {
				skip_until_ifend = true
			}
			continue
		}
		
		// Handle wait
		if line_trimmed.starts_with('wait(') {
			mut wait_str := line_trimmed.replace('wait(', '')
			wait_str = wait_str.replace(')', '').trim_space()
			seconds := wait_str.int()
			time.sleep(seconds * time.second)
			continue
		}
		
		// Handle variable declarations
		if line_trimmed.starts_with('var ') {
			words := line_trimmed.split(' ')
			if words.len >= 4 && words[2] == '=' {
				varname := words[1]
				varvalue := words[3..].join(' ').trim_space()
				
				// Handle input()
				if varvalue == 'input()' {
					user_input := os.input('')
					variables << '${varname}&${user_input}'
				}
				// Handle num.random()
				else if varvalue.starts_with('num.random(') {
					random_val := evaluate_random(varvalue)
					variables << '${varname}&${random_val}'
				}
				// Handle operations
				else if varvalue.starts_with('op[') {
					op_result := evaluate_operation(varvalue, variables)
					variables << '${varname}&${op_result}'
				}
				// Regular value
				else {
					variables << '${varname}&${varvalue}'
				}
			} else {
				exception.exception(linecn, line_trimmed, 'Malformed variable declaration')
			}
			continue
		}
		
		// Handle print (and legacy log)
		if line_trimmed.starts_with('print(') || line_trimmed.starts_with('log(') {
			mut output := line_trimmed.replace('print(', '').replace('log(', '')
			output = output.replace(')', '').trim_space()
			
			// String literal with quotes
			if output.contains('"') {
				output = output.replace('"', '')
				println(output)
			}
			// Operation
			else if output.starts_with('op[') {
				println(evaluate_operation(output, variables))
			}
			// Random number
			else if output.starts_with('num.random(') {
				println(evaluate_random(output))
			}
			// Input
			else if output == 'input()' {
				user_input := os.input('')
				println(user_input)
			}
			// Variable
			else {
				vartoget := output.trim_space()
				mut value := ''
				for item in variables {
					parts := item.split('&')
					if parts.len == 2 && parts[0] == vartoget {
						value = parts[1]
						break
					}
				}
				if value != '' {
					println(value)
				} else {
					exception.exception(linecn, line_trimmed, 'Variable "${vartoget}" not found')
				}
			}
			continue
		}
	}
}

fn evaluate_condition(condition string, variables []string) bool {
	mut cond := condition.trim_space()
	
	// Replace variables with their values
	for item in variables {
		parts := item.split('&')
		if parts.len == 2 {
			varname := parts[0]
			varvalue := parts[1]
			cond = cond.replace(varname, varvalue)
		}
	}
	
	// Handle operations in conditions
	if cond.contains('op[') {
		start := cond.index('op[') or { -1 }
		if start >= 0 {
			end := cond.index_after(']', start)
			if end > start {
				op_expr := cond[start..end + 1]
				result := evaluate_operation(op_expr, variables)
				cond = cond.replace(op_expr, result)
			}
		}
	}
	
	// Check for NOT equal operator ?=
	if cond.contains(' ?= ') {
		parts := cond.split(' ?= ')
		if parts.len == 2 {
			left := parts[0].trim_space()
			right := parts[1].trim_space()
			
			// Handle input() in conditions
			if right == 'input()' {
				user_input := os.input('')
				return left != user_input
			}
			
			return left != right
		}
	}
	
	// Check for equal operator ==
	if cond.contains(' == ') {
		parts := cond.split(' == ')
		if parts.len == 2 {
			left := parts[0].trim_space()
			right := parts[1].trim_space()
			
			// Handle input() in conditions
			if right == 'input()' {
				user_input := os.input('')
				return left == user_input
			}
			
			return left == right
		}
	}
	
	return false
}

fn evaluate_operation(op_string string, variables []string) string {
	// Extract content from op[]
	mut expr := op_string.replace('op[', '').replace(']', '').trim_space()
	
	// Replace variables with their values
	for item in variables {
		parts := item.split('&')
		if parts.len == 2 {
			varname := parts[0]
			varvalue := parts[1]
			expr = expr.replace(varname, varvalue)
		}
	}
	
	// Handle addition
	if expr.contains(' + ') {
		parts := expr.split(' + ')
		if parts.len == 2 {
			a := parts[0].trim_space().f64()
			b := parts[1].trim_space().f64()
			result := a + b
			if result == result.i64() {
				return result.i64().str()
			}
			return result.str()
		}
	}
	
	// Handle subtraction
	if expr.contains(' - ') && !expr.starts_with('num.random') {
		parts := expr.split(' - ')
		if parts.len == 2 {
			a := parts[0].trim_space().f64()
			b := parts[1].trim_space().f64()
			result := a - b
			if result == result.i64() {
				return result.i64().str()
			}
			return result.str()
		}
	}
	
	// Handle multiplication
	if expr.contains(' * ') {
		parts := expr.split(' * ')
		if parts.len == 2 {
			a := parts[0].trim_space().f64()
			b := parts[1].trim_space().f64()
			result := a * b
			if result == result.i64() {
				return result.i64().str()
			}
			return result.str()
		}
	}
	
	// Handle division
	if expr.contains(' / ') {
		parts := expr.split(' / ')
		if parts.len == 2 {
			a := parts[0].trim_space().f64()
			b := parts[1].trim_space().f64()
			if b != 0 {
				result := a / b
				if result == result.i64() {
					return result.i64().str()
				}
				return result.str()
			}
		}
	}
	
	return '0'
}

fn evaluate_random(random_string string) string {
	// Extract range from num.random(min - max)
	mut range_str := random_string.replace('num.random(', '')
	range_str = range_str.replace(')', '').trim_space()
	
	parts := range_str.split(' - ')
	if parts.len == 2 {
		min := parts[0].trim_space().int()
		max := parts[1].trim_space().int()
		
		if min <= max {
			random_num := rand.int_in_range(min, max + 1) or { min }
			return random_num.str()
		}
	}
	
	return '0'
}
