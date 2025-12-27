module exception

pub fn exception(linecn int, line string, errormessage string) {
    println(line)
    mut errorsym := ""
    for _ in line {
        errorsym += "^"
    }
    println(errorsym)
    println("runtime error: $errormessage at line $linecn")
}
