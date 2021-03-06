using mallib

class Main
{
  static MalVal READ(Str s)
  {
    return Reader.read_str(s)
  }

  static MalVal eval_ast(MalVal ast, MalEnv env)
  {
    switch (ast.typeof)
    {
      case MalSymbol#:
        return env.get(ast)
      case MalList#:
        newElements := (ast as MalList).value.map { EVAL(it, env) }
        return MalList(newElements)
      case MalVector#:
        newElements := (ast as MalVector).value.map { EVAL(it, env) }
        return MalVector(newElements)
      case MalHashMap#:
        newElements := (ast as MalHashMap).value.map |MalVal v -> MalVal| { return EVAL(v, env) }
        return MalHashMap.fromMap(newElements)
      default:
        return ast
    }
  }

  static MalVal EVAL(MalVal ast, MalEnv env)
  {
    if (!(ast is MalList)) return eval_ast(ast, env)
    astList := ast as MalList
    if (astList.isEmpty) return ast
    switch ((astList[0] as MalSymbol)?.value)
    {
      case "def!":
        return env.set(astList[1], EVAL(astList[2], env))
      case "let*":
        let_env := MalEnv(env)
        varList := astList[1] as MalSeq
        for (i := 0; i < varList.count; i += 2)
          let_env.set(varList[i], EVAL(varList[i + 1], let_env))
        return EVAL(astList[2], let_env)
      case "do":
        eval_ast(MalList(astList[1..-2]), env)
        return EVAL(astList[-1], env)
      case "if":
        if (EVAL(astList[1], env) is MalFalseyVal)
          return astList.count > 3 ? EVAL(astList[3], env) : MalNil.INSTANCE
        else
          return EVAL(astList[2], env)
      case "fn*":
        return MalFunc { EVAL(astList[2], MalEnv(env, (astList[1] as MalSeq), MalList(it))) }
      default:
        evaled_ast := eval_ast(ast, env) as MalList
        f := evaled_ast[0] as MalFunc
        return f.call(evaled_ast[1..-1])
    }
  }

  static Str PRINT(MalVal exp)
  {
    return exp.toString(true)
  }

  static Str REP(Str s, MalEnv env)
  {
    return PRINT(EVAL(READ(s), env))
  }

  static Void main()
  {
    repl_env := MalEnv()
    // core.fan: defined using Fantom
    Core.ns.each |MalFunc V, Str K| { repl_env.set(MalSymbol(K), V) }

    // core.mal: defined using the language itself
    REP("(def! not (fn* (a) (if a false true)))", repl_env)

    while (true) {
      line := Env.cur.prompt("user> ")
      if (line == null) break
      if (line.isSpace) continue
      try
        echo(REP(line, repl_env))
      catch (Err e)
        echo("Error: $e.msg")
    }
  }
}
