///|
fn std_codes(body : String) -> Array[String] raise @liberty.LibertyError {
  @liberty.standard_findings(@liberty.parse_liberty("library(x){" + body + "}"))
  .filter(f => f.severity == @liberty.Error)
  .map(f => f.code)
}

///|
fn std_timing(body : String) -> String {
  "cell(C){pin(A){direction:input;}pin(Y){direction:output;timing(){related_pin:\"A\";" +
  body +
  "}}}"
}

///|
fn std_type() -> String {
  "type(word){base_type:array;data_type:bit;bit_width:4;bit_from:3;bit_to:0;downto:true;}"
}

///|
test "standard rule inventory is explicit and non exhaustive" {
  let report = @liberty.compatibility_json(format_report("cell(C){}"))
  assert_true(report.stringify().contains("rule_inventory_exhaustive"))
  assert_eq(@liberty.standard_rule_ids().length(), 18)
}

///|
test "known standard group parent and argument rules reject misplaced pins" {
  assert_true(std_codes("pin(A){}").contains("StandardGroupParent"))
  assert_true(std_codes("cell(){}").contains("StandardGroupArguments"))
  assert_eq(std_codes("cell(C){pin(A,B){direction:input;}}"), [])
}

///|
test "standard attributes validate boolean enum and quoted string types" {
  assert_true(
    std_codes("cell(C){dont_use:1;}").contains("StandardAttributeType"),
  )
  assert_true(
    std_codes("cell(C){pin(A){direction:sideways;}}").contains(
      "StandardAttributeType",
    ),
  )
  assert_true(std_codes("time_unit:1ns;").contains("StandardAttributeType"))
  assert_eq(std_codes("time_unit:\"1ns\";cell(C){dont_use:false;}"), [])
}

///|
test "standard simple attributes cannot use complex form or repeat" {
  assert_true(std_codes("cell(C){area(2);}").contains("StandardAttributeForm"))
  assert_true(
    std_codes("cell(C){area:1;area:2;}").contains("DuplicateAttribute"),
  )
}

///|
test "standard template requires paired contiguous distinct axes" {
  for
    body in [
      "variable_1:input_net_transition;", "variable_2:input_net_transition;index_2(\"1\");",
      "variable_1:input_net_transition;index_1(\"1\");variable_2:input_net_transition;index_2(\"2\");",
    ] {
    assert_true(
      std_codes("lu_table_template(T){" + body + "}").contains(
        "StandardTemplateAxis",
      ),
    )
  }
}

///|
test "standard template breakpoints are nonnegative increasing" {
  for values in ["-1,2", "2,1", "1,1"] {
    assert_true(
      std_codes(
        "lu_table_template(T){variable_1:input_net_transition;index_1(\"" +
        values +
        "\");}",
      ).contains("StandardTemplateAxis"),
    )
  }
}

///|
test "power and timing template names have separate namespaces" {
  let body = "power_lut_template(T){variable_1:input_transition_time;index_1(\"1\");}"
  assert_true(
    std_codes(body + std_timing("cell_rise(T){values(\"2\");}")).contains(
      "StandardTemplateReference",
    ),
  )
}

///|
test "three dimensional standard table validates format without evaluation" {
  let template = "lu_table_template(T){variable_1:input_net_transition;index_1(\"1,2\");variable_2:total_output_net_capacitance;index_2(\"3,4\");variable_3:related_out_total_output_net_capacitance;index_3(\"5,6\");}"
  assert_eq(
    std_codes(
      template +
      std_timing("cell_rise(T){values(\"1,2\",\"3,4\",\"5,6\",\"7,8\");}"),
    ),
    [],
  )
  assert_true(
    std_codes(
      template + std_timing("cell_rise(T){values(\"1,2,3,4\",\"5,6,7,8\");}"),
    ).contains("TableShape"),
  )
}

///|
test "table overrides must precede values" {
  let template = "lu_table_template(T){variable_1:input_net_transition;index_1(\"1\");}"
  assert_true(
    std_codes(
      template + std_timing("cell_rise(T){values(\"2\");index_1(\"3\");}"),
    ).contains("StandardTableOrder"),
  )
}

///|
test "transition negativity differs from legal negative propagation delay" {
  assert_true(
    std_codes(std_timing("rise_transition(scalar){values(\"-1\");}")).contains(
      "NegativeTransition",
    ),
  )
  assert_eq(std_codes(std_timing("cell_rise(scalar){values(\"-1\");}")), [])
}

///|
test "bus type endpoints width and direction are consistent" {
  assert_eq(std_codes(std_type()), [])
  assert_true(
    std_codes("type(T){bit_width:3;bit_from:3;bit_to:0;}").contains(
      "StandardBusRange",
    ),
  )
  assert_true(
    std_codes("type(T){bit_from:0;bit_to:3;downto:true;}").contains(
      "StandardBusRange",
    ),
  )
}

///|
test "bus type optional defaults are not mistaken for missing attributes" {
  assert_eq(std_codes("type(T){base_type:array;data_type:bit;bit_width:8;}"), [])
}

///|
test "bus requires a declared type as its first statement" {
  assert_true(
    std_codes("cell(C){bus(D){bus_type:MISSING;}}").contains("StandardBusType"),
  )
  assert_true(
    std_codes(std_type() + "cell(C){bus(D){direction:input;bus_type:word;}}").contains(
      "StandardBusType",
    ),
  )
}

///|
test "unquoted bus members ranges and shared direction validate" {
  assert_eq(
    std_codes(
      std_type() +
      "cell(C){bus(D){bus_type:word;direction:input;pin(D[3:0]){direction:input;}}}",
    ),
    [],
  )
  assert_true(
    std_codes(
      std_type() +
      "cell(C){bus(D){bus_type:word;direction:input;pin(D[4]){direction:output;}}}",
    ).contains("StandardBusMember"),
  )
  assert_true(
    std_codes(std_type() + "cell(C){bus(D){bus_type:word;pin(OTHER[1]){}}}").contains(
      "StandardBusMember",
    ),
  )
}

///|
test "state groups require distinct names and positive bank widths" {
  assert_true(
    std_codes("cell(C){ff(Q,Q){}}").contains("StandardStateArguments"),
  )
  for width in ["0", "00", "+0", "-1", "1.5"] {
    assert_true(
      std_codes("cell(C){ff_bank(Q,QN," + width + "){}}").contains(
        "StandardStateArguments",
      ),
    )
  }
  assert_eq(
    std_codes("cell(C){ff_bank(Q,QN,4){next_state:\"0\";clocked_on:\"1\";}}"),
    [],
  )
}

///|
test "state expressions resolve cell inputs and internal nodes" {
  assert_eq(
    std_codes("cell(C){pin(CK){}ff(Q,QN){clocked_on:(CK);next_state:\"0\";}}"),
    [],
  )
  assert_eq(
    std_codes(
      "cell(C){pin(D){direction:input;}pin(CK){direction:input;}ff(Q,QN){clocked_on:\"CK\";next_state:\"D ^ Q\";}}",
    ),
    [],
  )
  assert_true(
    std_codes("cell(C){ff(Q,QN){next_state:\"UNKNOWN\";}}").contains(
      "UnknownSignal",
    ),
  )
}

///|
test "statetable node names counts and column tokens validate" {
  let prefix = "cell(C){pin(A){direction:input;}statetable(\"A\",\"Q\"){table:"
  assert_eq(std_codes(prefix + "\"R : L : H, ~F : H : N\";}}"), [])
  assert_true(
    std_codes(prefix + "\"L H : L : H\";}}").contains("StandardStateTableRows"),
  )
  assert_true(
    std_codes(prefix + "\"X : L : H\";}}").contains("StandardStateTableToken"),
  )
}

///|
test "statetable duplicate undeclared nodes and duplicate tables fail" {
  assert_true(
    std_codes("cell(C){statetable(\"A\",\"A\"){table:\"L:L:H\";}}").contains(
      "StandardStateTableNodes",
    ),
  )
  assert_true(
    std_codes("cell(C){statetable(\"UNDECLARED\",\"Q\"){table:\"L:L:H\";}}").contains(
      "UnknownSignal",
    ),
  )
  assert_true(
    std_codes(
      "cell(C){statetable(\"\",\"Q\"){table:\":L:H\";}statetable(\"\",\"R\"){table:\":L:H\";}}",
    ).contains("StandardStateTableNodes"),
  )
}

///|
test "standard diagnostics include paths and original locations" {
  let root = @liberty.parse_liberty("library(x){\ncell(C){area:invalid;}}")
  let report = @liberty.compatibility_report(root)
  assert_true(
    report.findings.any(f => {
      f.code == "StandardAttributeType" &&
      f.position.line == 2 &&
      f.path.has_suffix("/area")
    }),
  )
}

///|
test "out of rule budget is explicit instead of silent integer truncation" {
  assert_true(
    std_codes("type(T){bit_width:4294967296;}").contains("RuleResourceLimit"),
  )
}

///|
test "2017.06 LVF moment tables validate structure while remaining unevaluated" {
  assert_eq(
    std_codes(
      std_timing("ocv_mean_shift_cell_rise(scalar){values(\"-0.01\");}"),
    ),
    [],
  )
  assert_true(
    std_codes(std_timing("ocv_std_dev_cell_rise(MISSING){values(\"1\");}")).contains(
      "StandardTemplateReference",
    ),
  )
  assert_true(
    std_codes(std_timing("ocv_skewness_cell_rise(scalar){values(\"1,2\");}")).contains(
      "TableShape",
    ),
  )
}

///|
test "non table lookup delay model cannot be silently queried" {
  let library = @liberty.load_library("library(x){delay_model:polynomial;}")
  try
    @liberty.query_timing(library, "C", "Y", "A", "cell_rise", 0.0, 0.0)
  catch {
    @liberty.LibertyError(code, _, _) =>
      assert_eq(code, "UnsupportedDelayModel")
  } noraise {
    _ => fail("polynomial accepted as NLDM")
  }
}

///|
test "public standard checks bound caller constructed syntax before recursion" {
  let root = @liberty.parse_liberty("library(x){}")
  let forged = { ..root, kind: "cell", }
  assert_true(
    @liberty.standard_findings(forged).any(f => f.severity == @liberty.Error),
  )
}

///|
test "vector bank equations are preserved and explicitly unvalidated" {
  let root = @liberty.parse_liberty(
    "library(x){cell(C){ff_bank(Q,QN,4){next_state:\"D[3:0]\";clocked_on:\"1\";}}}",
  )
  let findings = @liberty.standard_findings(root)
  assert_eq(findings.filter(f => f.severity == @liberty.Error), [])
  assert_true(
    findings.any(f => {
      f.code == "UnsupportedVectorExpression" && f.severity == @liberty.Warning
    }),
  )
}

///|
test "flip flop declarations require state and clock equations" {
  assert_true(
    std_codes("cell(C){ff(Q,QN){clocked_on:\"1\";}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_true(
    std_codes("cell(C){ff(Q,QN){next_state:\"0\";}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_eq(
    std_codes("cell(C){ff(Q,QN){next_state:\"0\";clocked_on_also:\"1\";}}"),
    [],
  )
}

///|
test "empty required flip flop equations cannot appear complete" {
  assert_true(
    std_codes("cell(C){ff(Q,QN){next_state:\"\";clocked_on:\"\";}}").contains(
      "StandardStateRequired",
    ),
  )
}

///|
test "cell local type declarations are valid bus definitions" {
  assert_eq(
    std_codes("cell(C){" + std_type() + "bus(D){bus_type:word;pin(D[3:0]){}}}"),
    [],
  )
}

///|
test "cell local type shadows global definition without leaking to siblings" {
  let global = "type(W){bit_width:2;bit_from:0;bit_to:1;}"
  let cell_type = "type(W){bit_width:2;bit_from:4;bit_to:5;}"
  assert_eq(
    std_codes(
      global +
      "cell(A){" +
      cell_type +
      "bus(D){bus_type:W;pin(D[4]){}}}cell(B){bus(D){bus_type:W;pin(D[0]){}}}",
    ),
    [],
  )
}

///|
test "duplicate cell local types and invalid type parents are diagnosed" {
  assert_true(
    std_codes("cell(C){type(T){}type(T){}}").contains("DuplicateType"),
  )
  assert_true(
    std_codes("cell(C){pin(A){type(T){}}}").contains("StandardGroupParent"),
  )
}

///|
test "latch data and enable occur as a pair while SR latches remain valid" {
  assert_true(
    std_codes("cell(C){latch(Q,QN){data_in:\"0\";}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_true(
    std_codes("cell(C){latch(Q,QN){enable_also:\"1\";}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_eq(std_codes("cell(C){latch(Q,QN){data_in:\"0\";enable:\"1\";}}"), [])
  assert_eq(
    std_codes(
      "cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";clear_preset_var1:L;}}",
    ),
    [],
  )
}

///|
test "latch asynchronous controls and combined state flags require one another" {
  assert_true(
    std_codes("cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_true(
    std_codes("cell(C){latch(Q,QN){clear_preset_var2:H;}}").contains(
      "StandardStateRequired",
    ),
  )
  assert_true(
    std_codes("cell(C){latch_bank(Q,QN,2){data_in:\"0\";}}").contains(
      "StandardStateRequired",
    ),
  )
}

///|
test "state value enumerations are checked without treating them as expressions" {
  for value in ["L", "H", "N", "T", "X"] {
    assert_eq(
      std_codes(
        "cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";clear_preset_var1:" +
        value +
        ";}}",
      ),
      [],
    )
  }
  assert_true(
    std_codes(
      "cell(C){latch(Q,QN){clear:\"0\";preset:\"1\";clear_preset_var1:bad;}}",
    ).contains("StandardAttributeType"),
  )
}

///|
test "negative transition is also rejected by domain lint and query" {
  let library = @liberty.load_library(
    "library(x){time_unit:\"1ns\";capacitive_load_unit(1,pf);" +
    std_timing("rise_transition(scalar){values(\"-1\");}") +
    "}",
  )
  assert_true(
    @liberty.lint_library(library).any(f => f.code == "NegativeTransition"),
  )
  try
    @liberty.query_timing(library, "C", "Y", "A", "rise_transition", 0.0, 0.0)
  catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "InvalidLibrary")
  } noraise {
    _ => fail("negative slew returned")
  }
}

///|
test "explicit width endpoint and direction constrain inferred bus members" {
  for
    sample in [
      ("bit_from:3;downto:true;", "D[3:0]", "D[4]"),
      ("bit_from:4;downto:false;", "D[4:7]", "D[8]"),
      ("bit_to:0;downto:true;", "D[3:0]", "D[4]"),
      ("bit_to:7;downto:false;", "D[4:7]", "D[3]"),
    ] {
    let prefix = "type(T){bit_width:4;" +
      sample.0 +
      "}cell(C){bus(D){bus_type:T;pin("
    assert_eq(std_codes(prefix + sample.1 + "){}}}"), [])
    assert_true(
      std_codes(prefix + sample.2 + "){}}}").contains("StandardBusMember"),
    )
  }
}

///|
test "inferred bus endpoints cannot silently become negative" {
  for
    body in [
      "bit_width:4;bit_from:1;downto:true;", "bit_width:4;bit_to:1;downto:false;",
    ] {
    assert_true(std_codes("type(T){" + body + "}").contains("StandardBusRange"))
  }
}

///|
test "cached state scopes retain sibling references and isolate cells" {
  let root = @liberty.parse_liberty(
    "library(x){cell(A){ff(Q,QN){clocked_on:\"1\";next_state:\"0\";}ff(R,RN){clocked_on:\"Q\";next_state:\"R\";}}cell(B){ff(S,SN){clocked_on:\"1\";next_state:\"Q\";}}}",
  )
  let issues = @liberty.standard_findings(root).filter(f => {
    f.code == "UnknownSignal"
  })
  assert_eq(issues.length(), 1)
  assert_true(issues[0].path.contains("cell(B)"))
}

///|
test "nested test cell state scopes do not inherit outer state names" {
  let codes = std_codes(
    "cell(A){ff(Q,QN){clocked_on:\"1\";next_state:\"0\";}test_cell(){ff(T,TN){clocked_on:\"1\";next_state:\"Q\";}}}",
  )
  assert_eq(codes.filter(code => code == "UnknownSignal").length(), 1)
}

///|
test "many state equations resolve against the same complete cell declaration set" {
  let body = StringBuilder()
  body.write_string("cell(C){")
  for i in 0..<512 {
    body.write_string("ff(Q\{i},N\{i}){clocked_on:\"1\";next_state:\"Q511\";}")
  }
  body.write_string("}")
  assert_eq(std_codes(body.to_string()), [])
}

///|
test "negative bus member numbers are rejected even when endpoints remain unspecified" {
  for pin_name in ["D[-1]", "D[-1:0]"] {
    assert_true(
      std_codes(
        "type(T){bit_width:8;}cell(C){bus(D){bus_type:T;pin(" +
        pin_name +
        "){}}}",
      ).contains("StandardBusMember"),
    )
  }
}
